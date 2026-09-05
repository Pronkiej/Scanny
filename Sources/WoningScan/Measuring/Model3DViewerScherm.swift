import SwiftUI
import SceneKit

/// Scherm om een opgeslagen 3D-scan achteraf te bekijken en te verwerken: schakel tussen de puntenwolk
/// (losse grijze meetpunten) en het verbonden 3D-model, draai/verplaats/zoom vrij rond om er "doorheen"
/// te kijken, en teken in het 3D-model meetlijnen (bv. muur-tot-muur, later te bevestigen met een
/// handmatig ingemeten afstand - rolmaat of bluetooth-laser) en begrenzingslijnen (de rand van een
/// bouwdeel).
struct Model3DViewerScherm: View {
    let woningId: UUID
    let kamerScanId: UUID

    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var weergave: Weergave = .model
    @State private var modus: Modus = .bekijken
    @State private var scnScene: SCNScene?
    @State private var tijdelijkePunten: [SCNVector3] = []
    @State private var meetlijnen: [Meetlijn] = []
    @State private var begrenzingslijnen: [Begrenzingslijn] = []
    @State private var notities: [ScanNotitie] = []
    @State private var wachtOpBevestiging: PendingMeetlijn?
    @State private var toonLijst = false

    enum Weergave: String, CaseIterable { case puntenwolk = "Puntenwolk", model = "3D-model" }
    enum Modus { case bekijken, meten, begrenzing }

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }
    private var kamerScan: KamerScan? {
        woning.kamerScans.first(where: { $0.id == kamerScanId })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let scnScene {
                Model3DRepresentable(
                    scene: scnScene,
                    tikActief: modus != .bekijken && weergave == .model,
                    onTik: { punt in verwerkTik(punt) }
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            }

            VStack {
                bovenBalk
                Spacer()
                if modus != .bekijken {
                    Text(instructieTekst)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(.bottom, 8)
                }
                onderBalk
            }
        }
        .statusBarHidden()
        .onAppear {
            meetlijnen = kamerScan?.meetlijnen ?? []
            begrenzingslijnen = kamerScan?.begrenzingslijnen ?? []
            notities = kamerScan?.notities ?? []
            laadScene()
        }
        .onChange(of: weergave) { _, nieuweWaarde in
            if nieuweWaarde != .model { modus = .bekijken }
            laadScene()
        }
        .onChange(of: modus) { _, _ in tijdelijkePunten = [] }
        .sheet(item: $wachtOpBevestiging) { pending in
            BevestigMeetlijnForm(berekendeAfstandM: pending.afstandM) { bevestigdeWaarde in
                voegMeetlijnToe(pending, bevestigdeAfstandM: bevestigdeWaarde)
            }
        }
        .sheet(isPresented: $toonLijst) {
            LijnenLijstView(
                meetlijnen: meetlijnen,
                begrenzingslijnen: begrenzingslijnen,
                notities: notities,
                woningId: woningId,
                onVerwijderMeetlijn: { verwijderMeetlijn($0) },
                onVerwijderBegrenzing: { verwijderBegrenzing($0) },
                onBijwerkenNotitie: { bijwerkenNotitie($0) }
            )
        }
    }

    private var instructieTekst: String {
        switch modus {
        case .meten: return "Tik twee punten op het model aan om een afstand te meten."
        case .begrenzing: return "Tik punten aan om een begrenzing te tekenen. Tik op 'Klaar met deze lijn' om af te ronden."
        case .bekijken: return ""
        }
    }

    private var bovenBalk: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Sluiten")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
            }
            Spacer()
            Picker("Weergave", selection: $weergave) {
                ForEach(Weergave.allCases, id: \.self) { optie in
                    Text(optie.rawValue).tag(optie)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Spacer()
            Button {
                toonLijst = true
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5), in: Circle())
            }
        }
        .padding()
    }

    private var onderBalk: some View {
        VStack(spacing: 10) {
            if modus == .begrenzing && !tijdelijkePunten.isEmpty {
                Button {
                    rondBegrenzingAf()
                } label: {
                    Label("Klaar met deze lijn", systemImage: "checkmark")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                }
            }
            if weergave == .model {
                Picker("Modus", selection: $modus) {
                    Text("Bekijken").tag(Modus.bekijken)
                    Text("Meten").tag(Modus.meten)
                    Text("Begrenzing").tag(Modus.begrenzing)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            } else {
                Text("Meten en begrenzen kan alleen in de 3D-model-weergave.")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: Capsule())
            }
        }
        .padding(.bottom, 24)
    }

    private func laadScene() {
        guard let kamerScan else { scnScene = nil; return }
        let bestandsnaam = weergave == .model ? kamerScan.modelBestandsnaam : kamerScan.pointcloudBestandsnaam
        guard let bestandsnaam else { scnScene = nil; return }
        let url = ProjectStore.shared.modelUrl(bestandsnaam: bestandsnaam, woningId: woningId)
        guard let scene = try? SCNScene(url: url, options: nil) else { scnScene = nil; return }
        scnScene = scene
        herbouwLijnen()
    }

    private func verwerkTik(_ punt: SCNVector3) {
        switch modus {
        case .bekijken:
            break
        case .meten:
            tijdelijkePunten.append(punt)
            tekenMarkering(op: punt, kleur: .systemYellow)
            if tijdelijkePunten.count == 2 {
                let a = tijdelijkePunten[0]
                let b = tijdelijkePunten[1]
                let berekend = afstand(a, b)
                wachtOpBevestiging = PendingMeetlijn(start: a, eind: b, afstandM: Double(berekend))
                tijdelijkePunten = []
            }
        case .begrenzing:
            if let laatste = tijdelijkePunten.last {
                tekenLijn(van: laatste, naar: punt, kleur: .systemRed)
            }
            tijdelijkePunten.append(punt)
            tekenMarkering(op: punt, kleur: .systemRed)
        }
    }

    private func rondBegrenzingAf() {
        guard tijdelijkePunten.count > 1 else { tijdelijkePunten = []; return }
        let lijn = Begrenzingslijn(
            naam: "Begrenzing \(begrenzingslijnen.count + 1)",
            punten: tijdelijkePunten.map { Punt3D(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
        )
        begrenzingslijnen.append(lijn)
        tijdelijkePunten = []
        slaOp()
    }

    private func voegMeetlijnToe(_ pending: PendingMeetlijn, bevestigdeAfstandM: Double?) {
        let lijn = Meetlijn(
            naam: "Meting \(meetlijnen.count + 1)",
            start: Punt3D(x: Double(pending.start.x), y: Double(pending.start.y), z: Double(pending.start.z)),
            eind: Punt3D(x: Double(pending.eind.x), y: Double(pending.eind.y), z: Double(pending.eind.z)),
            berekendeAfstandM: pending.afstandM,
            bevestigdeAfstandM: bevestigdeAfstandM
        )
        meetlijnen.append(lijn)
        tekenLijn(van: pending.start, naar: pending.eind, kleur: .systemYellow)
        slaOp()
    }

    private func verwijderMeetlijn(_ lijn: Meetlijn) {
        meetlijnen.removeAll { $0.id == lijn.id }
        slaOp()
        herbouwLijnen()
    }

    private func verwijderBegrenzing(_ lijn: Begrenzingslijn) {
        begrenzingslijnen.removeAll { $0.id == lijn.id }
        slaOp()
        herbouwLijnen()
    }

    /// Slaat de tijdens het scannen vastgelegde foto pas hier op met het door de gebruiker gekozen
    /// type en bericht - de foto zelf stond al klaar, alleen de toelichting was nog niet ingevuld.
    private func bijwerkenNotitie(_ bijgewerkt: ScanNotitie) {
        guard let idx = notities.firstIndex(where: { $0.id == bijgewerkt.id }) else { return }
        notities[idx] = bijgewerkt
        slaOp()
    }

    private func slaOp() {
        guard var bijgewerkt = store.projecten.first(where: { $0.id == woningId }),
              let idx = bijgewerkt.kamerScans.firstIndex(where: { $0.id == kamerScanId }) else { return }
        bijgewerkt.kamerScans[idx].meetlijnen = meetlijnen
        bijgewerkt.kamerScans[idx].begrenzingslijnen = begrenzingslijnen
        bijgewerkt.kamerScans[idx].notities = notities
        store.opslaan(bijgewerkt)
    }

    private func annotatieNode() -> SCNNode? {
        guard let scnScene else { return nil }
        if let bestaand = scnScene.rootNode.childNode(withName: "annotaties", recursively: false) {
            return bestaand
        }
        let node = SCNNode()
        node.name = "annotaties"
        scnScene.rootNode.addChildNode(node)
        return node
    }

    private func herbouwLijnen() {
        guard let scnScene else { return }
        scnScene.rootNode.childNode(withName: "annotaties", recursively: false)?.removeFromParentNode()
        guard let annotaties = annotatieNode() else { return }

        for lijn in meetlijnen {
            let a = SCNVector3(Float(lijn.start.x), Float(lijn.start.y), Float(lijn.start.z))
            let b = SCNVector3(Float(lijn.eind.x), Float(lijn.eind.y), Float(lijn.eind.z))
            annotaties.addChildNode(lijnNode(van: a, naar: b, kleur: .systemYellow))
        }
        for lijn in begrenzingslijnen {
            let punten = lijn.punten.map { SCNVector3(Float($0.x), Float($0.y), Float($0.z)) }
            var i = 0
            while i < punten.count - 1 {
                annotaties.addChildNode(lijnNode(van: punten[i], naar: punten[i + 1], kleur: .systemRed))
                i += 1
            }
        }
    }

    private func tekenMarkering(op punt: SCNVector3, kleur: UIColor) {
        guard let annotaties = annotatieNode() else { return }
        let bol = SCNSphere(radius: 0.015)
        bol.firstMaterial?.diffuse.contents = kleur
        bol.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: bol)
        node.position = punt
        annotaties.addChildNode(node)
    }

    private func tekenLijn(van a: SCNVector3, naar b: SCNVector3, kleur: UIColor) {
        guard let annotaties = annotatieNode() else { return }
        annotaties.addChildNode(lijnNode(van: a, naar: b, kleur: kleur))
    }

    private func afstand(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dz = b.z - a.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    private func lijnNode(van a: SCNVector3, naar b: SCNVector3, kleur: UIColor) -> SCNNode {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dz = b.z - a.z
        let lengte = (dx * dx + dy * dy + dz * dz).squareRoot()

        let cylinder = SCNCylinder(radius: 0.006, height: CGFloat(max(lengte, 0.001)))
        cylinder.firstMaterial?.diffuse.contents = kleur
        cylinder.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)

        guard lengte > 0.0001 else { return node }
        let richting = SCNVector3(dx / lengte, dy / lengte, dz / lengte)
        let omhoog = SCNVector3(0, 1, 0)
        let rotatieAs = SCNVector3(
            omhoog.y * richting.z - omhoog.z * richting.y,
            omhoog.z * richting.x - omhoog.x * richting.z,
            omhoog.x * richting.y - omhoog.y * richting.x
        )
        let asLengte = (rotatieAs.x * rotatieAs.x + rotatieAs.y * rotatieAs.y + rotatieAs.z * rotatieAs.z).squareRoot()
        let dotProduct = max(-1, min(1, omhoog.x * richting.x + omhoog.y * richting.y + omhoog.z * richting.z))
        let hoek = Float(acos(Double(dotProduct)))
        if asLengte > 0.0001 && hoek.isFinite {
            node.rotation = SCNVector4(rotatieAs.x / asLengte, rotatieAs.y / asLengte, rotatieAs.z / asLengte, hoek)
        }
        return node
    }
}

private struct PendingMeetlijn: Identifiable {
    let id = UUID()
    let start: SCNVector3
    let eind: SCNVector3
    let afstandM: Double
}

/// Formulier om de automatisch berekende afstand tussen twee getikte punten te bevestigen of te
/// corrigeren - bijvoorbeeld met een handmatig ingemeten waarde (rolmaat of bluetooth-laser).
private struct BevestigMeetlijnForm: View {
    let berekendeAfstandM: Double
    var onBevestig: (_ bevestigdeAfstandM: Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var handmatigeWaarde: Double

    init(berekendeAfstandM: Double, onBevestig: @escaping (_ bevestigdeAfstandM: Double?) -> Void) {
        self.berekendeAfstandM = berekendeAfstandM
        self.onBevestig = onBevestig
        _handmatigeWaarde = State(initialValue: (berekendeAfstandM * 100).rounded() / 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Uit het 3D-model gemeten") {
                    Text("\(String(format: "%.2f", berekendeAfstandM)) m")
                        .font(.title2.bold())
                }
                Section("Bevestig of corrigeer (bv. met een rolmaat of bluetooth-laserafstandsmeter)") {
                    HStack {
                        TextField("meters", value: $handmatigeWaarde, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                        Text("m").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Meetlijn")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        onBevestig(handmatigeWaarde)
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

/// Overzicht van deze scan: de tijdens het scannen gemaakte foto's (nog te toelichten door ze aan te
/// tikken) en alle meet- en begrenzingslijnen, met mogelijkheid om er een te verwijderen.
private struct LijnenLijstView: View {
    let meetlijnen: [Meetlijn]
    let begrenzingslijnen: [Begrenzingslijn]
    let notities: [ScanNotitie]
    let woningId: UUID
    var onVerwijderMeetlijn: (Meetlijn) -> Void
    var onVerwijderBegrenzing: (Begrenzingslijn) -> Void
    var onBijwerkenNotitie: (ScanNotitie) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actieveNotitie: ScanNotitie?

    var body: some View {
        NavigationStack {
            List {
                Section("Foto's (\(notities.count))") {
                    if notities.isEmpty {
                        Text("Nog geen foto's gemaakt tijdens deze scan.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(notities) { notitie in
                        Button {
                            actieveNotitie = notitie
                        } label: {
                            fotoRij(notitie)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Meetlijnen (\(meetlijnen.count))") {
                    ForEach(meetlijnen) { lijn in
                        VStack(alignment: .leading) {
                            Text(lijn.naam)
                            Text(
                                "Model: \(String(format: "%.2f", lijn.berekendeAfstandM)) m"
                                    + (lijn.bevestigdeAfstandM.map { " · Bevestigd: \(String(format: "%.2f", $0)) m" } ?? "")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet { onVerwijderMeetlijn(meetlijnen[index]) }
                    }
                }
                Section("Begrenzingslijnen (\(begrenzingslijnen.count))") {
                    ForEach(begrenzingslijnen) { lijn in
                        Text("\(lijn.naam) · \(lijn.punten.count) punten")
                    }
                    .onDelete { indexSet in
                        for index in indexSet { onVerwijderBegrenzing(begrenzingslijnen[index]) }
                    }
                }
            }
            .navigationTitle("Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
            .sheet(item: $actieveNotitie) { notitie in
                FotoNotitieForm(woningId: woningId, notitie: notitie) { bijgewerkt in
                    onBijwerkenNotitie(bijgewerkt)
                }
            }
        }
    }

    @ViewBuilder
    private func fotoRij(_ notitie: ScanNotitie) -> some View {
        HStack(spacing: 10) {
            if let foto = ProjectStore.shared.laadFoto(bestandsnaam: notitie.fotoBestandsnaam, woningId: woningId) {
                Image(uiImage: foto)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                if notitie.type.isEmpty {
                    Text("Nog niet ingevuld")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    Text(notitie.type)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                if !notitie.bericht.isEmpty {
                    Text(notitie.bericht)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

/// Formulier om een tijdens het scannen gemaakte foto achteraf toe te lichten: welk bouwdeel is dit
/// en een bericht erbij - wordt pas hier ingevuld, niet meer tijdens het scannen zelf.
private struct FotoNotitieForm: View {
    let woningId: UUID
    let notitie: ScanNotitie
    var onOpslaan: (_ bijgewerkt: ScanNotitie) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: String
    @State private var bericht: String
    @State private var foto: UIImage?

    private let types = ["Gevel", "Raam", "Deur", "Dak", "Vloer", "Anders"]

    init(woningId: UUID, notitie: ScanNotitie, onOpslaan: @escaping (_ bijgewerkt: ScanNotitie) -> Void) {
        self.woningId = woningId
        self.notitie = notitie
        self.onOpslaan = onOpslaan
        _type = State(initialValue: notitie.type.isEmpty ? "Gevel" : notitie.type)
        _bericht = State(initialValue: notitie.bericht)
    }

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
                Section("Bericht") {
                    TextEditor(text: $bericht).frame(minHeight: 100)
                }
            }
            .navigationTitle("Foto-notitie")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        var bijgewerkt = notitie
                        bijgewerkt.type = type
                        bijgewerkt.bericht = bericht
                        onOpslaan(bijgewerkt)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
            }
            .onAppear {
                foto = ProjectStore.shared.laadFoto(bestandsnaam: notitie.fotoBestandsnaam, woningId: woningId)
            }
        }
    }
}

/// SCNView-wrapper met vrije camera (draaien/verplaatsen/zoomen, zodat je "erdoorheen" kan kijken) en,
/// als tikken actief zijn (meten/begrenzing), een tik-naar-punt hit-test op het 3D-model.
private struct Model3DRepresentable: UIViewRepresentable {
    let scene: SCNScene
    let tikActief: Bool
    var onTik: (SCNVector3) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .black

        let tikGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tik(_:)))
        view.addGestureRecognizer(tikGesture)
        context.coordinator.scnView = view
        context.coordinator.tikActief = tikActief
        context.coordinator.onTik = onTik

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene {
            uiView.scene = scene
        }
        context.coordinator.tikActief = tikActief
        context.coordinator.onTik = onTik
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var scnView: SCNView?
        var tikActief = false
        var onTik: ((SCNVector3) -> Void)?

        @objc func tik(_ gesture: UITapGestureRecognizer) {
            guard tikActief, let scnView else { return }
            let locatie = gesture.location(in: scnView)
            let resultaten = scnView.hitTest(locatie, options: nil)
            guard let eerste = resultaten.first else { return }
            onTik?(eerste.worldCoordinates)
        }
    }
}
