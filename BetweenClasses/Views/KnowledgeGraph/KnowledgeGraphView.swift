import SwiftUI
import SwiftData
import SceneKit

struct KnowledgeGraphView: View {
    @Query private var subjects: [Subject]
    @State private var selectedNode: GraphNode?
    @State private var sceneRef = GraphSceneRef()
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if subjects.isEmpty {
                emptyState
            } else {
                SCNViewWrapper(subjects: subjects, sceneRef: sceneRef, onTap: { node in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedNode = node
                    }
                })
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn(duration: 0.6), value: appeared)
            }

            // Tooltip overlay
            if let node = selectedNode {
                VStack {
                    Spacer()
                    nodeTooltip(node)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Title
            VStack {
                HStack {
                    Text("Knowledge Graph")
                        .bcCaption()
                        .foregroundStyle(.textSecond)
                        .textCase(.uppercase)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    Spacer()
                    if selectedNode != nil {
                        Button("Clear") {
                            withAnimation { selectedNode = nil }
                        }
                        .bcCaption()
                        .foregroundStyle(.textSecond)
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true }
        }
        .onTapGesture {
            if selectedNode != nil { withAnimation { selectedNode = nil } }
        }
    }

    private func nodeTooltip(_ node: GraphNode) -> some View {
        GlassCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            HStack(spacing: 12) {
                Circle()
                    .fill(node.type == .subject ? Color.white : Color.white.opacity(0.4))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.label)
                        .bcBody()
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    if node.type == .subject {
                        Text("\(node.noteCount) note\(node.noteCount == 1 ? "" : "s")")
                            .bcCaption()
                            .foregroundStyle(.textSecond)
                    } else {
                        Text("Topic note")
                            .bcCaption()
                            .foregroundStyle(.textSecond)
                    }
                }
                Spacer()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 48))
                .foregroundStyle(.textTertiary)
            Text("No data yet")
                .bcHeadline()
                .foregroundStyle(.textPrimary)
            Text("Add notes and subjects to see your knowledge graph.")
                .bcBody()
                .foregroundStyle(.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Scene reference wrapper (to share the scene object)

@Observable
final class GraphSceneRef {
    var scene: GraphScene?
}

// MARK: - SCNView wrapper

struct SCNViewWrapper: UIViewRepresentable {
    let subjects: [Subject]
    let sceneRef: GraphSceneRef
    let onTap: (GraphNode) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling2X

        let scene = GraphScene()
        let data = GraphDataBuilder.build(from: subjects)
        scene.build(from: data)
        view.scene = scene
        sceneRef.scene = scene

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 1.5, 6)
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        // Gestures
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)

        context.coordinator.scnView = view
        context.coordinator.cameraNode = cameraNode
        context.coordinator.scene = scene

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let data = GraphDataBuilder.build(from: subjects)
        sceneRef.scene?.build(from: data)
    }

    final class Coordinator: NSObject {
        let onTap: (GraphNode) -> Void
        weak var scnView: SCNView?
        var cameraNode: SCNNode?
        var scene: GraphScene?

        private var lastPan: CGPoint = .zero
        private var baseDistance: Float = 6

        init(onTap: @escaping (GraphNode) -> Void) { self.onTap = onTap }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = scnView, let camera = cameraNode else { return }
            let delta = gesture.translation(in: view)
            let sensitivity: Float = 0.005
            let yAngle = Float(delta.x) * sensitivity
            let xAngle = Float(delta.y) * sensitivity

            let yRot = SCNMatrix4MakeRotation(yAngle, 0, 1, 0)
            let xRot = SCNMatrix4MakeRotation(xAngle, 1, 0, 0)
            let combined = SCNMatrix4Mult(xRot, yRot)
            camera.transform = SCNMatrix4Mult(camera.transform, combined)
            gesture.setTranslation(.zero, in: view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let camera = cameraNode else { return }
            if gesture.state == .began { baseDistance = camera.position.z }
            let newZ = baseDistance / Float(gesture.scale)
            camera.position.z = min(max(newZ, 2), 15)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, let scene else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: nil)
            guard let hit = hits.first,
                  let name = hit.node.name,
                  let id = UUID(uuidString: name),
                  let node = scene.node(at: id) else { return }
            onTap(node)
        }
    }
}

#Preview {
    KnowledgeGraphView()
        .preferredColorScheme(.dark)
}
