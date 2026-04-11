import Foundation
import SceneKit

struct GraphNode {
    let id: UUID
    let label: String
    let type: NodeType
    let noteCount: Int
    var position: SCNVector3
    /// Subject line color — drives node tint in SceneKit.
    let tintHex: String

    enum NodeType {
        case subject
        case topic
    }
}

struct GraphEdge {
    let fromID: UUID
    let toID: UUID
}

struct GraphData {
    var nodes: [GraphNode]
    var edges: [GraphEdge]

    func neighborIDs(of id: UUID) -> Set<UUID> {
        var s: Set<UUID> = [id]
        for e in edges {
            if e.fromID == id { s.insert(e.toID) }
            if e.toID == id { s.insert(e.fromID) }
        }
        return s
    }
}

enum GraphDataBuilder {
    /// Stable signature so SwiftUI only rebuilds the SceneKit graph when model data changes.
    static func dataSignature(from subjects: [Subject]) -> String {
        subjects            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { sub in
                let noteIDs = sub.notes.map(\.id.uuidString).sorted().joined(separator: ",")
                return "\(sub.id.uuidString)[\(noteIDs)]"
            }
            .joined(separator: "|")
    }

    static func build(from subjects: [Subject]) -> GraphData {
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        let subjectShellRadius: Float = 3.2
        let topicShellRadius: Float = 1.15
        let n = max(subjects.count, 1)
        let golden = Float.pi * (1 + sqrt(5))

        for (i, subject) in subjects.enumerated() {
            let k = Float(i) + 0.5
            let yUnit = 1 - 2 * k / Float(n)
            let rCircle = sqrt(max(0, 1 - yUnit * yUnit))
            let theta = golden * k
            let sx = subjectShellRadius * rCircle * cos(theta)
            let sy = subjectShellRadius * yUnit * 0.75
            let sz = subjectShellRadius * rCircle * sin(theta)

            let subjectNode = GraphNode(
                id: subject.id,
                label: subject.name,
                type: .subject,
                noteCount: subject.notes.count,
                position: SCNVector3(sx, sy, sz),
                tintHex: subject.colorHex
            )
            nodes.append(subjectNode)

            let sortedNotes = subject.notes.sorted { $0.createdAt < $1.createdAt }
            let m = sortedNotes.count

            for (j, note) in sortedNotes.enumerated() {
                let t = m <= 1 ? 0.5 : Float(j) / Float(m - 1)
                let phi = Float.pi * (0.15 + t * 0.85)
                let thetaN = golden * Float(j + 3)
                let ox = topicShellRadius * sin(phi) * cos(thetaN)
                let oy = topicShellRadius * 0.9 * cos(phi) * 0.55
                let oz = topicShellRadius * sin(phi) * sin(thetaN)

                let topicNode = GraphNode(
                    id: note.id,
                    label: titlePreview(note.extractedText),
                    type: .topic,
                    noteCount: 0,
                    position: SCNVector3(sx + ox, sy + oy, sz + oz),
                    tintHex: subject.colorHex
                )
                nodes.append(topicNode)
                edges.append(GraphEdge(fromID: subject.id, toID: note.id))
            }

            if sortedNotes.count >= 2 {
                for idx in 0..<(sortedNotes.count - 1) {
                    edges.append(GraphEdge(fromID: sortedNotes[idx].id, toID: sortedNotes[idx + 1].id))
                }
            }
        }

        return GraphData(nodes: nodes, edges: edges)
    }

    private static func titlePreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty note" }
        if trimmed.count <= 28 { return trimmed }
        return String(trimmed.prefix(28)) + "…"
    }
}
