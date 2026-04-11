import SwiftUI
import SwiftData
import SceneKit
import UIKit

/// SceneKit's default `SCNView` can join the keyboard/focus system on iOS and logs focus cache warnings; the graph is pointer-driven only.
final class NonFocusableSCNView: SCNView {
    override var canBecomeFocused: Bool { false }
}

struct KnowledgeGraphView: View {
    @Environment(AppState.self) private var appState
    @Query private var subjects: [Subject]
    @State private var selectedNode: GraphNode?
    @State private var localGraphFocus = false
    @State private var sceneRef = GraphSceneRef()
    @State private var appeared = false
    @State private var graphNoteSheet: GraphNoteSheetPayload?
    @State private var graphTopicSheet: GraphTopicSheetPayload?

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
        .sheet(item: $graphTopicSheet) { payload in
            GraphTopicSheet(
                payload: payload,
                onOpenNote: { note in
                    graphTopicSheet = nil
                    graphNoteSheet = GraphNoteSheetPayload(
                        id: note.id,
                        note: note,
                        subjectName: payload.subject.name
                    )
                },
                onQuizTopic: {
                    graphTopicSheet = nil
                    appState.startQuiz(for: payload.subject, topicName: payload.topic)
                }
            )
        }
    }

    private struct GraphNoteSheetPayload: Identifiable {
        let id: UUID
        let note: Note
        let subjectName: String
    }

    struct GraphTopicSheetPayload: Identifiable {
        var id: String { "\(subject.id.uuidString)-\(topic)" }
        let subject: Subject
        let topic: String
        let notes: [Note]
    }

    private func subjectName(for subjectID: UUID) -> String {
        subjects.first { $0.id == subjectID }?.name ?? "Note"
    }

    private func resolveSubject(id: UUID) -> Subject? {
        subjects.first { $0.id == id }
    }

    private func resolveNote(id: UUID) -> Note? {
        subjects.flatMap(\.notes).first { $0.id == id }
    }

    private func resolveTopicPayload(subjectID: UUID, topicName: String) -> GraphTopicSheetPayload? {
        guard let subject = resolveSubject(id: subjectID) else { return nil }
        let notes = subject.notesByTopic.first {
            $0.topic.localizedCaseInsensitiveCompare(topicName) == .orderedSame
        }?.notes ?? []
        guard !notes.isEmpty else { return nil }
        return GraphTopicSheetPayload(subject: subject, topic: topicName, notes: notes)
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
                        switch node.type {
                        case .subject:
                            Text("\(node.noteCount) note\(node.noteCount == 1 ? "" : "s") across this class")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                        case .topic:
                            Text("\(node.noteCount) note\(node.noteCount == 1 ? "" : "s") in this topic")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                        case .note:
                            Text(node.noteCount == 0 ? "Tap in to read the note" : "\(node.noteCount) saved question\(node.noteCount == 1 ? "" : "s")")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                        }
                    }
                    Spacer()
                }

                switch node.type {
                case .subject:
                    if let subject = resolveSubject(id: node.subjectID) {
                        Button {
                            appState.startQuiz(for: subject)
                        } label: {
                            Text("Quiz whole subject")
                                .font(.bcCaption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.white.opacity(0.2))
                    }
                case .topic:
                    if let topic = node.topicName, let payload = resolveTopicPayload(subjectID: node.subjectID, topicName: topic) {
                        Button {
                            graphTopicSheet = payload
                        } label: {
                            Text("Open topic notes")
                                .font(.bcCaption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.white.opacity(0.2))
                    }
                case .note:
                    if let n = resolveNote(id: node.id) {
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

private struct GraphTopicSheet: View {
    let payload: KnowledgeGraphView.GraphTopicSheetPayload
    let onOpenNote: (Note) -> Void
    let onQuizTopic: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(payload.subject.name)
                                    .bcCaption()
                                    .foregroundStyle(Color.textSecond)
                                Text(payload.topic)
                                    .bcHeadline()
                                    .foregroundStyle(Color.textPrimary)
                                Text("\(payload.notes.count) note\(payload.notes.count == 1 ? "" : "s") in this cluster")
                                    .bcBody()
                                    .foregroundStyle(Color.textSecond)
                                Button("Quiz Topic") { onQuizTopic() }
                                    .buttonStyle(BCPrimaryButtonStyle())
                            }
                        }

                        ForEach(payload.notes) { note in
                            Button {
                                onOpenNote(note)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : String(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)))
                                        .bcBody()
                                        .foregroundStyle(Color.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(3)
                                    Text(note.questions.isEmpty ? "Open note" : "\(note.questions.count) saved question\(note.questions.count == 1 ? "" : "s")")
                                        .bcCaption()
                                        .foregroundStyle(Color.textTertiary)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Topic")
            .navigationBarTitleDisplayMode(.inline)
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
        let view = NonFocusableSCNView()
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
            // SceneKit expects Obj-C types in this dictionary; Swift enums/bool may bridge as __SwiftValue and crash in -integerValue.
            let hits = view.hitTest(point, options: [
                SCNHitTestOption.searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue),
                SCNHitTestOption.ignoreHiddenNodes: NSNumber(value: true),
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
