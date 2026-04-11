import SwiftUI
import SwiftData
import SceneKit
import UIKit

struct KnowledgeGraphView: View {
    @Query private var subjects: [Subject]
    @State private var selectedNode: GraphNode?
    @State private var localGraphFocus = false
    @State private var sceneRef = GraphSceneRef()
    @State private var appeared = false
    @State private var graphNoteSheet: GraphNoteSheetPayload?

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if subjects.isEmpty {
                emptyState
            } else {
                SCNViewWrapper(
                    selectedNode: $selectedNode,
                    localGraphFocus: $localGraphFocus,
                    subjects: subjects,
                    sceneRef: sceneRef,
                    onTap: { node in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(BCMotion.panelSpring) {
                            selectedNode = node
                        }
                    }
                )
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .animation(BCMotion.gentleEase, value: appeared)
            }

            if let node = selectedNode {
                VStack {
                    Spacer()
                    nodeTooltip(node)
                        .padding(.horizontal, BCSpacing.gutter)
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(BCMotion.panelSpring, value: selectedNode?.id)
            }
        }
        .safeAreaInset(edge: .top, spacing: BCSpacing.md) {
            BCChromeBar(title: "Knowledge graph") {
                HStack(spacing: 14) {
                    Button {
                        sceneRef.triggerCameraReset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.textSecond)
                    .accessibilityLabel("Reset camera")

                    Button {
                        localGraphFocus.toggle()
                    } label: {
                        Image(systemName: localGraphFocus ? "scope" : "globe")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(localGraphFocus ? Color.textPrimary : Color.textSecond)
                    .accessibilityLabel(localGraphFocus ? "Show full graph" : "Local graph focus")

                    if selectedNode != nil {
                        Button("Clear") {
                            withAnimation(BCMotion.panelSpring) { selectedNode = nil }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.textSecond)
                        .accessibilityLabel("Clear selection")
                    }
                }
            }
            .padding(.horizontal, BCSpacing.gutter)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true }
        }
        .sheet(item: $graphNoteSheet) { payload in
            NoteDetailSheet(note: payload.note, subjectName: payload.subjectName)
        }
    }

    private struct GraphNoteSheetPayload: Identifiable {
        let id: UUID
        let note: Note
        let subjectName: String
    }

    private func subjectName(for subjectID: UUID) -> String {
        subjects.first { $0.id == subjectID }?.name ?? "Note"
    }

    private func resolveNote(id: UUID) -> Note? {
        subjects.flatMap(\.notes).first { $0.id == id }
    }

    private func nodeTooltip(_ node: GraphNode) -> some View {
        GlassCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: node.tintHex))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.label)
                            .bcBody()
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(2)
                        if node.type == .subject {
                            Text("\(node.noteCount) note\(node.noteCount == 1 ? "" : "s")")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                        } else {
                            Text("Linked to class graph")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                        }
                    }
                    Spacer()
                }

                if node.type == .topic, let n = resolveNote(id: node.id) {
                    Button {
                        graphNoteSheet = GraphNoteSheetPayload(
                            id: n.id,
                            note: n,
                            subjectName: subjectName(for: n.subjectID)
                        )
                    } label: {
                        Text("Open note")
                            .font(.bcCaption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.white.opacity(0.2))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color.textTertiary)
            Text("No data yet")
                .bcHeadline()
                .foregroundStyle(Color.textPrimary)
            Text("Add notes and subjects to see your knowledge graph.")
                .bcBody()
                .foregroundStyle(Color.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Scene reference

@Observable
final class GraphSceneRef {
    var scene: GraphScene?
    var cameraResetTrigger: Int = 0

    func triggerCameraReset() {
        cameraResetTrigger += 1
    }
}

// MARK: - SCNView

struct SCNViewWrapper: UIViewRepresentable {
    @Binding var selectedNode: GraphNode?
    @Binding var localGraphFocus: Bool

    let subjects: [Subject]
    let sceneRef: GraphSceneRef
    let onTap: (GraphNode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            selectedBinding: $selectedNode
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)
        view.antialiasingMode = .multisampling4X

        let scene = GraphScene()
        let data = GraphDataBuilder.build(from: subjects)
        scene.build(from: data)
        scene.background.contents = UIColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)
        view.scene = scene
        sceneRef.scene = scene

        let cameraNode = SCNNode()
        let cam = SCNCamera()
        cam.fieldOfView = 58
        cam.zNear = 0.05
        cam.zFar = 40
        if #available(iOS 18.0, *) {
            cam.wantsHDR = true
            cam.bloomIntensity = 0.35
            cam.bloomThreshold = 0.55
            cam.bloomBlurRadius = 8
        }
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.require(toFail: doubleTap)

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(doubleTap)

        context.coordinator.scnView = view
        context.coordinator.cameraNode = cameraNode
        context.coordinator.scene = scene
        context.coordinator.bindingSelectedNode = $selectedNode
        context.coordinator.lastDataSignature = GraphDataBuilder.dataSignature(from: subjects)
        context.coordinator.resetOrbitToDefaults(animated: false)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.bindingSelectedNode = $selectedNode
        context.coordinator.scene = sceneRef.scene

        let data = GraphDataBuilder.build(from: subjects)
        let sig = GraphDataBuilder.dataSignature(from: subjects)
        var graphRebuilt = false
        if context.coordinator.lastDataSignature != sig {
            context.coordinator.lastDataSignature = sig
            context.coordinator.lastFocusSelectionID = nil
            sceneRef.scene?.build(from: data)
            graphRebuilt = true
        }

        let dim = localGraphFocus && selectedNode != nil
        let active: Set<UUID> = {
            guard let sel = selectedNode, localGraphFocus else {
                return Set(data.nodes.map(\.id))
            }
            return data.neighborIDs(of: sel.id)
        }()
        sceneRef.scene?.applyFocus(activeNodeIDs: active, dimNonNeighbors: dim)

        context.coordinator.syncFocus(
            selected: selectedNode,
            graphRebuilt: graphRebuilt
        )

        if context.coordinator.lastCameraResetTrigger != sceneRef.cameraResetTrigger {
            context.coordinator.lastCameraResetTrigger = sceneRef.cameraResetTrigger
            context.coordinator.resetOrbitPreservingSelection(animated: true)
        }
    }

    final class Coordinator: NSObject {
        let onTap: (GraphNode) -> Void
        var bindingSelectedNode: Binding<GraphNode?>?

        weak var scnView: SCNView?
        var cameraNode: SCNNode?
        var scene: GraphScene?

        var lastDataSignature: String = ""
        var lastFocusSelectionID: UUID?
        var lastCameraResetTrigger: Int = -1

        var orbitYaw: Float = 0.55
        var orbitPitch: Float = 0.38
        var orbitRadius: Float = 7.8
        var focusCenter = SCNVector3(0, 0, 0)

        private var pinchBaseRadius: Float = 7.8

        init(onTap: @escaping (GraphNode) -> Void, selectedBinding: Binding<GraphNode?>) {
            self.onTap = onTap
            self.bindingSelectedNode = selectedBinding
        }

        func resetOrbitToDefaults(animated: Bool) {
            orbitYaw = 0.55
            orbitPitch = 0.38
            orbitRadius = 7.8
            focusCenter = SCNVector3(0, 0, 0)
            applyCamera(animated: animated)
        }

        func resetOrbitPreservingSelection(animated: Bool) {
            orbitYaw = 0.55
            orbitPitch = 0.38
            orbitRadius = 7.8
            if let id = bindingSelectedNode?.wrappedValue?.id,
               let p = scene?.worldPosition(of: id) {
                focusCenter = p
            } else {
                focusCenter = SCNVector3(0, 0, 0)
            }
            applyCamera(animated: animated)
        }

        func syncFocus(selected: GraphNode?, graphRebuilt: Bool) {
            guard let scene else { return }
            let id = selected?.id
            if graphRebuilt { lastFocusSelectionID = nil }
            if !graphRebuilt, id == lastFocusSelectionID { return }
            lastFocusSelectionID = id

            let target: SCNVector3
            if let id, let p = scene.worldPosition(of: id) {
                target = p
            } else {
                target = SCNVector3(0, 0, 0)
            }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.36
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            focusCenter = target
            updateCameraNode()
            SCNTransaction.commit()
        }

        private func applyCamera(animated: Bool) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.4 : 0
            updateCameraNode()
            SCNTransaction.commit()
        }

        private func updateCameraNode() {
            guard let cameraNode else { return }
            let cp = cos(orbitPitch)
            let sp = sin(orbitPitch)
            let cy = cos(orbitYaw)
            let sy = sin(orbitYaw)
            let x = focusCenter.x + orbitRadius * sy * cp
            let y = focusCenter.y + orbitRadius * sp
            let z = focusCenter.z + orbitRadius * cy * cp
            cameraNode.position = SCNVector3(x, y, z)
            cameraNode.look(at: focusCenter, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = scnView else { return }
            let t = gesture.translation(in: view)
            let dYaw = Float(t.x) * 0.009
            let dPitch = Float(t.y) * 0.009
            orbitYaw -= dYaw
            orbitPitch += dPitch
            orbitPitch = min(max(orbitPitch, -1.22), 1.22)
            gesture.setTranslation(.zero, in: view)
            updateCameraNode()
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                pinchBaseRadius = orbitRadius
            }
            let next = pinchBaseRadius / Float(gesture.scale)
            orbitRadius = min(max(next, 2.8), 19)
            updateCameraNode()
        }

        @objc func handleDoubleTap() {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            bindingSelectedNode?.wrappedValue = nil
            resetOrbitToDefaults(animated: true)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, let scene else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest,
                SCNHitTestOption.ignoreHiddenNodes: true,
            ])
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
