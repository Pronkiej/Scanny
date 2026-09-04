import SwiftUI
import ARKit
import SceneKit

/// Eenvoudige AR-liniaal: tik twee punten aan in de camera-weergave om de afstand ertussen te meten.
/// Gebruikt de LiDAR-scene-reconstructie voor nauwkeurige diepte waar beschikbaar, en valt anders terug
/// op ARKit's vlakherkenning. Vereist een fysiek toestel (werkt niet in de Simulator, en LiDAR-precisie
/// vereist een Pro-model iPhone/iPad).
struct ARMeasureView: UIViewRepresentable {
    /// Wordt aangeroepen na elke voltooide meting (twee tikken), met de afstand in meters.
    var onMeasured: (Double) -> Void
    /// Verhoog dit getal van buitenaf om de huidige meting te wissen en opnieuw te beginnen.
    var resetTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(onMeasured: onMeasured)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = context.coordinator
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()
        view.debugOptions = []

        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        view.session.run(config)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.arView = view
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if context.coordinator.laatsteResetTrigger != resetTrigger {
            context.coordinator.laatsteResetTrigger = resetTrigger
            context.coordinator.wisMeting()
        }
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        weak var arView: ARSCNView?
        var onMeasured: (Double) -> Void
        var laatsteResetTrigger: Int = 0

        private var eerstePunt: SCNVector3?
        private var geplaatsteNodes: [SCNNode] = []

        init(onMeasured: @escaping (Double) -> Void) {
            self.onMeasured = onMeasured
        }

        func wisMeting() {
            eerstePunt = nil
            geplaatsteNodes.forEach { $0.removeFromParentNode() }
            geplaatsteNodes.removeAll()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let point = gesture.location(in: arView)

            guard let query = arView.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any) else { return }
            let results = arView.session.raycast(query)
            guard let result = results.first else { return }

            let positie = SCNVector3(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )

            plaatsMarker(op: positie)

            if let eerste = eerstePunt {
                let afstand = afstandTussen(eerste, positie)
                tekenLijn(van: eerste, naar: positie)
                onMeasured(Double(afstand))
                eerstePunt = nil
            } else {
                eerstePunt = positie
            }
        }

        private func plaatsMarker(op positie: SCNVector3) {
            let bol = SCNSphere(radius: 0.008)
            bol.firstMaterial?.diffuse.contents = UIColor.systemYellow
            let node = SCNNode(geometry: bol)
            node.position = positie
            arView?.scene.rootNode.addChildNode(node)
            geplaatsteNodes.append(node)
        }

        private func tekenLijn(van a: SCNVector3, naar b: SCNVector3) {
            let indices: [Int32] = [0, 1]
            let bron = SCNGeometrySource(vertices: [a, b])
            let element = SCNGeometryElement(indices: indices, primitiveType: .line)
            let geometry = SCNGeometry(sources: [bron], elements: [element])
            geometry.firstMaterial?.diffuse.contents = UIColor.systemYellow
            let node = SCNNode(geometry: geometry)
            arView?.scene.rootNode.addChildNode(node)
            geplaatsteNodes.append(node)
        }

        private func afstandTussen(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            let dx = a.x - b.x
            let dy = a.y - b.y
            let dz = a.z - b.z
            return (dx * dx + dy * dy + dz * dz).squareRoot()
        }
    }
}
