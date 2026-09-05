import SwiftUI
import ARKit
import SceneKit

/// Volledig-scherm 3D-scan van een ruimte: loop rond met de telefoon terwijl LiDAR een gekleurde
/// mesh van wanden/vloer/plafond opbouwt (zelfde soort weergave als bekende scan-apps: de kleuren
/// tonen wat ARKit herkent, niet een afstandswaarschuwing). Onderin: Annuleren, opnemen (rood),
/// en een foto-knop - een foto tijdens het scannen wordt direct een notitie die je kan toelichten
/// (type bouwdeel + bericht), net als bij de app die als voorbeeld is aangeleverd.
struct RoomScanScherm: View {
    let titel: String
    let woningId: UUID
    var onVoltooid: (_ notities: [ScanNotitie], _ modelUrl: URL?, _ pointcloudUrl: URL?, _ duurSeconden: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var coordinator = ScanCoordinator()
    @State private var isOpnemen = false
    @State private var verstrekenSeconden = 0
    @State private var toonNotitieForm = false
    @State private var laatsteFoto: UIImage?
    @State private var laatsteFotoBestandsnaam: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let ondersteund = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    var body: some View {
        ZStack(alignment: .bottom) {
            if Self.ondersteund {
                ScanCameraRepresentable(coordinator: coordinator)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                Text("Dit toestel ondersteunt geen 3D-scannen (LiDAR-sensor vereist, bv. iPhone 12 Pro of nieuwer).")
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            VStack {
                HStack {
                    Button {
                        coordinator.stop()
                        dismiss()
                    } label: {
                        Text("Annuleren")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                    Spacer()
                    if isOpnemen {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 10, height: 10)
                            Text("\(verstrekenSeconden) s")
                        }
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                    }
                    Spacer()
                    Color.clear.frame(width: 90, height: 36)
                }
                .padding()

                Spacer()

                Text(titel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())

                if !isOpnemen {
                    Text("Tik op de rode knop om te beginnen met scannen. Loop rustig langs alle wanden.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                HStack {
                    Spacer()
                    Button {
                        maakFotoNotitie()
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.black)
                            .frame(width: 60, height: 60)
                            .background(.white, in: Circle())
                    }
                    .disabled(!isOpnemen)
                    .opacity(isOpnemen ? 1 : 0.4)

                    Spacer()

                    Button {
                        if isOpnemen { stopOpname() } else { startOpname() }
                    } label: {
                        ZStack {
                            Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                            if isOpnemen {
                                RoundedRectangle(cornerRadius: 6).fill(.red).frame(width: 30, height: 30)
                            } else {
                                Circle().fill(.red).frame(width: 62, height: 62)
                            }
                        }
                    }

                    Spacer()

                    Color.clear.frame(width: 60, height: 60)
                    Spacer()
                }
                .padding(.vertical, 24)
            }
        }
        .statusBarHidden()
        .onAppear { coordinator.woningIdVoorFotos = woningId }
        .onReceive(timer) { _ in
            if isOpnemen { verstrekenSeconden += 1 }
        }
        .sheet(isPresented: $toonNotitieForm) {
            ScanNotitieForm(foto: laatsteFoto) { type, bericht in
                coordinator.notities.append(ScanNotitie(type: type, bericht: bericht, fotoBestandsnaam: laatsteFotoBestandsnaam))
            }
        }
    }

    private func startOpname() {
        isOpnemen = true
        verstrekenSeconden = 0
        coordinator.notities = []
    }

    private func stopOpname() {
        isOpnemen = false
        let modelUrl = coordinator.exporteerModel()
        let pointcloudUrl = coordinator.exporteerPointcloud()
        onVoltooid(coordinator.notities, modelUrl, pointcloudUrl, verstrekenSeconden)
        coordinator.stop()
        dismiss()
    }

    private func maakFotoNotitie() {
        guard let foto = coordinator.maakFoto() else { return }
        laatsteFoto = foto
        laatsteFotoBestandsnaam = ProjectStore.shared.slaFotoOp(foto, voor: coordinator.woningIdVoorFotos ?? UUID())
        toonNotitieForm = true
    }
}

/// Klein formulier na een foto-notitie: welk bouwdeel is dit, en een bericht om later toe te lichten.
private struct ScanNotitieForm: View {
    let foto: UIImage?
    var onOpslaan: (_ type: String, _ bericht: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type = "Gevel"
    @State private var bericht = ""

    private let types = ["Gevel", "Raam", "Deur", "Dak", "Vloer", "Anders"]

    var body: some View {
        NavigationStack {
            Form {
                if let foto {
                    Section {
                        Image(uiImage: foto)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                }
                Section("Type bouwdeel") {
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Bericht (later toe te lichten)") {
                    TextEditor(text: $bericht).frame(minHeight: 100)
                }
            }
            .navigationTitle("Notitie")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        onOpslaan(type, bericht)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
            }
        }
    }
}

private struct ScanCameraRepresentable: UIViewRepresentable {
    let coordinator: ScanCoordinator

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.delegate = coordinator
        view.session.delegate = coordinator
        view.automaticallyUpdatesLighting = true
        view.scene = SCNScene()

        // Toont automatisch de door ARKit herkende mesh, gekleurd per classificatie
        // (wand/vloer/plafond/etc) - dit is Apple's eigen "scene understanding" debug-weergave.
        view.debugOptions = [.showSceneUnderstanding]

        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        view.session.run(config)

        coordinator.arView = view
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

/// Houdt de AR-sessie, de opgebouwde mesh-scène en de tijdens het scannen gemaakte notities bij.
/// Bewust geen @MainActor/ObservableObject: dit is een gewone referentie die door de SwiftUI-view
/// wordt vastgehouden (net als ARMeasureView.Coordinator), zodat er geen actor-isolatie-mismatch kan
/// ontstaan met ARSCNViewDelegate/ARSessionDelegate-callbacks (die ARKit soms buiten de main thread aanroept).
final class ScanCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    weak var arView: ARSCNView?
    var notities: [ScanNotitie] = []
    /// Gezet door VerdiepingView zodat foto's meteen bij het juiste project worden opgeslagen.
    var woningIdVoorFotos: UUID?

    func stop() {
        arView?.session.pause()
    }

    /// Maakt een schone camerafoto (zonder de mesh-overlay) van het huidige AR-beeld.
    func maakFoto() -> UIImage? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .right)
    }

    /// Best-effort export van de opgebouwde scène (inclusief de zichtbare mesh) als .usdz 3D-model.
    func exporteerModel() -> URL? {
        guard let scene = arView?.scene else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).usdz")
        let gelukt = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        return gelukt ? url : nil
    }

    /// Bouwt een losse puntenwolk (.usdz) uit de ruwe LiDAR-meetpunten van alle herkende mesh-ankers:
    /// dit zijn de datapunten in het 3D-coördinatenstelsel zoals ARKit ze meet, vóórdat ze tot een
    /// oppervlak (het 3D-model hierboven) worden verbonden. Wordt apart opgeslagen zodat je in de app
    /// kan kiezen tussen de puntenwolk en het verbonden 3D-model.
    func exporteerPointcloud() -> URL? {
        guard let frame = arView?.session.currentFrame else { return nil }

        var punten: [SIMD3<Float>] = []
        for anchor in frame.anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let bron = meshAnchor.geometry.vertices
            let transform = meshAnchor.transform
            let buffer = bron.buffer.contents()
            for i in 0..<bron.count {
                let offset = bron.offset + bron.stride * i
                let vertex = buffer.advanced(by: offset).assumingMemoryBound(to: (Float, Float, Float).self).pointee
                let lokaalPunt = SIMD4<Float>(vertex.0, vertex.1, vertex.2, 1)
                let wereldPunt = transform * lokaalPunt
                punten.append(SIMD3<Float>(wereldPunt.x, wereldPunt.y, wereldPunt.z))
            }
        }
        guard !punten.isEmpty else { return nil }

        // Beperk het aantal punten zodat het bestand werkbaar van grootte blijft.
        let maxPunten = 150_000
        if punten.count > maxPunten {
            let stap = max(punten.count / maxPunten, 1)
            punten = stride(from: 0, to: punten.count, by: stap).map { punten[$0] }
        }

        var floatData: [Float] = []
        floatData.reserveCapacity(punten.count * 3)
        for punt in punten {
            floatData.append(punt.x)
            floatData.append(punt.y)
            floatData.append(punt.z)
        }
        let vertexData = floatData.withUnsafeBufferPointer { Data(buffer: $0) }

        let bron = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: punten.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )

        let indices: [Int32] = Array(0..<Int32(punten.count))
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: punten.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        element.pointSize = 4
        element.minimumPointScreenSpaceRadius = 2
        element.maximumPointScreenSpaceRadius = 6

        let geometrie = SCNGeometry(sources: [bron], elements: [element])
        geometrie.firstMaterial?.diffuse.contents = UIColor.systemGreen
        geometrie.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: geometrie)
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_pointcloud.usdz")
        let gelukt = scene.write(to: url, options: nil, delegate: nil, progressHandler: nil)
        return gelukt ? url : nil
    }
}

