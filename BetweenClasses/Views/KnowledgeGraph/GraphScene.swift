import SceneKit
import UIKit

final class GraphScene: SCNScene {
    private var nodeMap: [UUID: SCNNode] = [:]
    private var tooltipData: [UUID: GraphNode] = [:]
    var onNodeTapped: ((GraphNode) -> Void)?

    func build(from data: GraphData) {
        rootNode.removeAllActions()
        rootNode.childNodes.forEach { $0.removeFromParentNode() }
        nodeMap.removeAll()
        tooltipData.removeAll()

        // Ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 200
        ambient.light?.color = UIColor.white
        rootNode.addChildNode(ambient)

        // Omni light
        let omni = SCNNode()
        omni.light = SCNLight()
        omni.light?.type = .omni
        omni.light?.intensity = 800
        omni.position = SCNVector3(0, 5, 5)
        rootNode.addChildNode(omni)

        // Nodes
        for node in data.nodes {
            let scnNode = makeNode(node)
            scnNode.position = node.position
            rootNode.addChildNode(scnNode)
            nodeMap[node.id] = scnNode
            tooltipData[node.id] = node
        }

        // Edges
        for edge in data.edges {
            guard let from = nodeMap[edge.fromID], let to = nodeMap[edge.toID] else { continue }
            let line = makeLine(from: from.position, to: to.position)
            rootNode.addChildNode(line)
        }

        // Idle rotation
        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 30))
        rootNode.runAction(spin)
    }

    private func makeNode(_ data: GraphNode) -> SCNNode {
        let radius: CGFloat = data.type == .subject ? 0.28 : 0.12
        let geo = SCNSphere(radius: radius)

        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor.white.withAlphaComponent(data.type == .subject ? 0.12 : 0.06)
        mat.emission.contents = UIColor.white.withAlphaComponent(data.type == .subject ? 0.55 : 0.25)
        mat.metalness.contents = 0.0
        mat.roughness.contents = 0.8
        geo.firstMaterial = mat

        let node = SCNNode(geometry: geo)
        node.name = data.id.uuidString

        // Pulse glow for subject nodes
        if data.type == .subject {
            let pulse = SCNAction.sequence([
                SCNAction.customAction(duration: 1.5) { node, elapsed in
                    let t = Float(elapsed / 1.5)
                    let scale = 1.0 + 0.06 * sin(t * .pi * 2)
                    node.scale = SCNVector3(scale, scale, scale)
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
        let distance = sqrt(dx*dx + dy*dy + dz*dz)

        let cylinder = SCNCylinder(radius: 0.008, height: CGFloat(distance))
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor.white.withAlphaComponent(0.15)
        mat.emission.contents = UIColor.white.withAlphaComponent(0.1)
        cylinder.firstMaterial = mat

        let node = SCNNode(geometry: cylinder)

        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        let midZ = (start.z + end.z) / 2
        node.position = SCNVector3(midX, midY, midZ)

        // Orient cylinder
        let dir = SCNVector3(dx, dy, dz)
        node.orientation = quaternion(from: SCNVector3(0, 1, 0), to: normalized(dir))
        return node
    }

    func node(at id: UUID) -> GraphNode? { tooltipData[id] }

    // MARK: - Math helpers

    private func normalized(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
        guard len > 0 else { return v }
        return SCNVector3(v.x/len, v.y/len, v.z/len)
    }

    private func quaternion(from: SCNVector3, to: SCNVector3) -> SCNQuaternion {
        let cross = SCNVector3(
            from.y * to.z - from.z * to.y,
            from.z * to.x - from.x * to.z,
            from.x * to.y - from.y * to.x
        )
        let dot = from.x*to.x + from.y*to.y + from.z*to.z
        let w = 1 + dot
        let len = sqrt(cross.x*cross.x + cross.y*cross.y + cross.z*cross.z + w*w)
        guard len > 0 else { return SCNQuaternion(0, 0, 0, 1) }
        return SCNQuaternion(cross.x/len, cross.y/len, cross.z/len, w/len)
    }
}
