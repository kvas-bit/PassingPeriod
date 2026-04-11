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
    let subjectID: UUID
    let topicName: String?

    enum NodeType {
        case subject
        case topic
        case note
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
        subjects
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { subject in
                let orderedTopics = subject.notesByTopic.map { entry in
                    let noteBits = entry.notes.map { note in
                        "\(note.id.uuidString):\(note.topicName):\(note.questions.count):\(titlePreview(note.extractedText))"
                    }.joined(separator: ",")
                    return "\(entry.topic){\(noteBits)}"
                }.joined(separator: ";")
                return "\(subject.id.uuidString):\(subject.name):\(subject.colorHex)[\(orderedTopics)]"
            }
            .joined(separator: "|")
    }

    static func build(from subjects: [Subject]) -> GraphData {
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        let subjectShellRadius: Float = 3.2
        let topicShellRadius: Float = 1.2
        let noteShellRadius: Float = 0.55
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
                tintHex: subject.colorHex,
                subjectID: subject.id,
                topicName: nil
            )
            nodes.append(subjectNode)

            let topics = subject.notesByTopic
            let topicCount = max(topics.count, 1)

            for (topicIndex, entry) in topics.enumerated() {
                let t = topicCount <= 1 ? 0.5 : Float(topicIndex) / Float(max(topicCount - 1, 1))
                let phi = Float.pi * (0.22 + t * 0.6)
                let thetaTopic = golden * Float(topicIndex + 2)
                let tx = topicShellRadius * sin(phi) * cos(thetaTopic)
                let ty = topicShellRadius * 0.95 * cos(phi) * 0.65
                let tz = topicShellRadius * sin(phi) * sin(thetaTopic)
                let topicID = stableTopicID(subjectID: subject.id, topicName: entry.topic)

                let topicNode = GraphNode(
                    id: topicID,
                    label: entry.topic,
                    type: .topic,
                    noteCount: entry.notes.count,
                    position: SCNVector3(sx + tx, sy + ty, sz + tz),
                    tintHex: subject.colorHex,
                    subjectID: subject.id,
                    topicName: entry.topic
                )
                nodes.append(topicNode)
                edges.append(GraphEdge(fromID: subject.id, toID: topicID))

                let noteCount = max(entry.notes.count, 1)
                for (noteIndex, note) in entry.notes.enumerated() {
                    let noteT = noteCount <= 1 ? 0.5 : Float(noteIndex) / Float(max(noteCount - 1, 1))
                    let notePhi = Float.pi * (0.25 + noteT * 0.5)
                    let noteTheta = golden * Float(noteIndex + topicIndex + 5)
                    let nx = noteShellRadius * sin(notePhi) * cos(noteTheta)
                    let ny = noteShellRadius * 0.9 * cos(notePhi) * 0.5
                    let nz = noteShellRadius * sin(notePhi) * sin(noteTheta)

                    let noteNode = GraphNode(
                        id: note.id,
                        label: titlePreview(note.extractedText),
                        type: .note,
                        noteCount: note.questions.count,
                        position: SCNVector3(sx + tx + nx, sy + ty + ny, sz + tz + nz),
                        tintHex: subject.colorHex,
                        subjectID: subject.id,
                        topicName: entry.topic
                    )
                    nodes.append(noteNode)
                    edges.append(GraphEdge(fromID: topicID, toID: note.id))
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

    private static func stableTopicID(subjectID: UUID, topicName: String) -> UUID {
        let subjectHex = subjectID.uuidString.replacingOccurrences(of: "-", with: "")
        let topicHex = String((hexSeed(for: topicName) + String(repeating: "0", count: 32)).prefix(32))

        var mixed = ""
        for index in 0..<32 {
            let subjectIndex = subjectHex.index(subjectHex.startIndex, offsetBy: index)
            let topicIndex = topicHex.index(topicHex.startIndex, offsetBy: index)
            mixed.append(index.isMultiple(of: 2) ? subjectHex[subjectIndex] : topicHex[topicIndex])
        }

        let uuid = "\(mixed.prefix(8))-\(mixed.dropFirst(8).prefix(4))-\(mixed.dropFirst(12).prefix(4))-\(mixed.dropFirst(16).prefix(4))-\(mixed.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuid) ?? subjectID
    }

    private static func hexSeed(for topicName: String) -> String {
        let bytes = Array(topicName.utf8)
        guard !bytes.isEmpty else { return "756e736f72746564" }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
