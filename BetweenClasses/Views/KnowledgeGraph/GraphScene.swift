import SceneKit
import SwiftUI
import UIKit

final class GraphScene: SCNScene {
    private var nodeMap: [UUID: SCNNode] = [:]
    private var tooltipData: [UUID: GraphNode] = [:]
    private var edgeRecords: [(node: SCNNode, from: UUID, to: UUID)] = []

    func build(from data: GraphData) {
        rootNode.childNodes.forEach { $0.removeFromParentNode() }
        nodeMap.removeAll()
        tooltipData.removeAll()
        edgeRecords.removeAll()

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 180
        ambient.light?.color = UIColor(white: 0.85, alpha: 1)
        rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 650
        key.light?.castsShadow = false
        key.light?.color = UIColor(white: 0.95, alpha: 1)
        key.eulerAngles = SCNVector3(-0.45, 0.55, 0)
        rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 280
        rim.light?.castsShadow = false
        rim.light?.color = UIColor(red: 0.55, green: 0.65, blue: 1, alpha: 1)
        rim.eulerAngles = SCNVector3(0.2, -1.1, 0)
        rootNode.addChildNode(rim)

        for node in data.nodes {
            let scnNode = makeNode(node)
            scnNode.position = node.position
            rootNode.addChildNode(scnNode)
            nodeMap[node.id] = scnNode
            tooltipData[node.id] = node
        }

        for edge in data.edges {
            guard let from = nodeMap[edge.fromID], let to = nodeMap[edge.toID] else { continue }
            let line = makeLine(from: from.position, to: to.position)
            rootNode.addChildNode(line)
            edgeRecords.append((line, edge.fromID, edge.toID))
        }

        fogStartDistance = 6
        fogEndDistance = 22
        fogColor = UIColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)
    }

    func node(at id: UUID) -> GraphNode? { tooltipData[id] }

    func worldPosition(of id: UUID) -> SCNVector3? {
        nodeMap[id]?.position
    }

    /// Obsidian-style local graph: dim nodes and edges outside the active neighborhood.
    func applyFocus(activeNodeIDs: Set<UUID>, dimNonNeighbors: Bool) {
        for (id, scn) in nodeMap {
            guard let data = tooltipData[id], let sphere = scn.geometry as? SCNSphere else { continue }
            let active = activeNodeIDs.contains(id)
            let dimmed = dimNonNeighbors && !active
            sphere.firstMaterial = makeSphereMaterial(for: data, dimmed: dimmed)
        }

        for record in edgeRecords {
            let on = activeNodeIDs.contains(record.from) && activeNodeIDs.contains(record.to)
            let dimmed = dimNonNeighbors && !on
            if let cyl = record.node.geometry as? SCNCylinder {
                cyl.firstMaterial = makeEdgeMaterial(strong: on || !dimNonNeighbors, dimmed: dimmed)
            }
        }
    }

    private func makeSphereMaterial(for data: GraphNode, dimmed: Bool) -> SCNMaterial {
        let tint = Color(hex: data.tintHex).uiColor
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.metalness.contents = 0.35
        mat.roughness.contents = 0.42

        if dimmed {
            mat.diffuse.contents = tint.withAlphaComponent(0.06)
            mat.emission.contents = tint.withAlphaComponent(0.08)
        } else {
            switch data.type {
            case .subject:
                mat.diffuse.contents = tint.withAlphaComponent(0.22)
                mat.emission.contents = tint.withAlphaComponent(0.85)
            case .topic:
                mat.diffuse.contents = tint.withAlphaComponent(0.16)
                mat.emission.contents = tint.withAlphaComponent(0.58)
            case .note:
                mat.diffuse.contents = tint.withAlphaComponent(0.10)
                mat.emission.contents = tint.withAlphaComponent(0.32)
            }
        }
        return mat
    }

    private func makeEdgeMaterial(strong: Bool, dimmed: Bool) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        if dimmed {
            mat.diffuse.contents = UIColor.white.withAlphaComponent(0.03)
            mat.emission.contents = UIColor.white.withAlphaComponent(0.02)
        } else if strong {
            mat.diffuse.contents = UIColor.white.withAlphaComponent(0.28)
            mat.emission.contents = UIColor.white.withAlphaComponent(0.18)
        } else {
            mat.diffuse.contents = UIColor.white.withAlphaComponent(0.14)
            mat.emission.contents = UIColor.white.withAlphaComponent(0.08)
        }
        return mat
    }

    private func makeNode(_ data: GraphNode) -> SCNNode {
        let radius: CGFloat
        switch data.type {
        case .subject:
            radius = 0.32
        case .topic:
            radius = 0.18
        case .note:
            radius = 0.11
        }
        let geo = SCNSphere(radius: radius)
        geo.segmentCount = 28
        geo.firstMaterial = makeSphereMaterial(for: data, dimmed: false)

        let node = SCNNode(geometry: geo)
        node.name = data.id.uuidString

        if data.type == .subject {
            let pulse = SCNAction.sequence([
                SCNAction.customAction(duration: 2.2) { n, elapsed in
                    let t = Float(elapsed / 2.2)
                    let scale = 1.0 + 0.05 * sin(t * .pi * 2)
                    n.scale = SCNVector3(scale, scale, scale)
                },
            ])
            node.runAction(SCNAction.repeatForever(pulse))
        }

        return node
    }

    private func makeLine(from start: SCNVector3, to end: SCNVector3) -> SCNNode {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        let cylinder = SCNCylinder(radius: 0.006, height: CGFloat(distance))
        cylinder.firstMaterial = makeEdgeMaterial(strong: true, dimmed: false)

        let node = SCNNode(geometry: cylinder)

        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        let midZ = (start.z + end.z) / 2
        node.position = SCNVector3(midX, midY, midZ)

        let dir = SCNVector3(dx, dy, dz)
        node.orientation = quaternion(from: SCNVector3(0, 1, 0), to: normalized(dir))
        return node
    }

    private func normalized(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        guard len > 0 else { return v }
        return SCNVector3(v.x / len, v.y / len, v.z / len)
    }

    private func quaternion(from: SCNVector3, to: SCNVector3) -> SCNQuaternion {
        let cross = SCNVector3(
            from.y * to.z - from.z * to.y,
            from.z * to.x - from.x * to.z,
            from.x * to.y - from.y * to.x
        )
        let dot = from.x * to.x + from.y * to.y + from.z * to.z
        let w = 1 + dot
        let len = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z + w * w)
        guard len > 0 else { return SCNQuaternion(0, 0, 0, 1) }
        return SCNQuaternion(cross.x / len, cross.y / len, cross.z / len, w / len)
    }
}
