import Foundation
import SceneKit

struct GraphNode {
    let id: UUID
    let label: String
    let type: NodeType
    let noteCount: Int
    var position: SCNVector3

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
}

struct GraphDataBuilder {
    static func build(from subjects: [Subject]) -> GraphData {
        var nodes: [GraphNode] = []
        var edges: [GraphEdge] = []

        let radius: Float = 2.5
        let subjectCount = subjects.count

        for (i, subject) in subjects.enumerated() {
            let angle = Float(i) / Float(max(subjectCount, 1)) * Float.pi * 2
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            let subjectNode = GraphNode(
                id: subject.id,
                label: subject.name,
                type: .subject,
                noteCount: subject.notes.count,
                position: SCNVector3(x, 0, z)
            )
            nodes.append(subjectNode)

            // Topic nodes (one per note)
            let noteRadius: Float = 0.9
            for (j, note) in subject.notes.enumerated() {
                let noteAngle = angle + Float(j + 1) / Float(max(subject.notes.count, 1)) * Float.pi * 0.8
                let nx = x + noteRadius * cos(noteAngle)
                let nz = z + noteRadius * sin(noteAngle)
                let topicNode = GraphNode(
                    id: note.id,
                    label: String(note.extractedText.prefix(20)),
                    type: .topic,
                    noteCount: 0,
                    position: SCNVector3(nx, Float.random(in: -0.3...0.3), nz)
                )
                nodes.append(topicNode)
                edges.append(GraphEdge(fromID: subject.id, toID: note.id))
            }
        }

        return GraphData(nodes: nodes, edges: edges)
    }
}
