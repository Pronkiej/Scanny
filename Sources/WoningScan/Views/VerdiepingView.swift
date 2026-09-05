import SwiftUI

/// Toont alle gevels, daken en vloeren die aan één verdieping (level) hangen, met knoppen om
/// nieuwe elementen toe te voegen. Dit is het scherm waar het gros van het scanwerk gebeurt.
struct VerdiepingView: View {
    let woningId: UUID
    let verdieping: String

    @EnvironmentObject private var store: ProjectStore
    @State private var toonRoomScan = false
    @State private var actieveScan: KamerScan?

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    private var gevels: [Gevel] { woning.gevels.filter { $0.verdieping == verdieping } }
    private var daken: [Dak] { woning.daken.filter { $0.verdieping == verdieping } }
    private var vloeren: [Vloer] { woning.vloeren.filter { $0.level == verdieping } }
    private var kamerScans: [KamerScan] { woning.kamerScans.filter { $0.verdieping == verdieping } }

    var body: some View {
        List {
            Section("3D-scan (\(kamerScans.count))") {
                ForEach(kamerScans) { scan in
                    VStack(alignment: .leading, spacing: 4) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scan.naam.isEmpty ? "3D-scan" : scan.naam)
                            Text("\(scan.duurSeconden) s scan · \(scan.notities.count) notitie(s) · \(scan.datum.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            actieveScan = scan
                        } label: {
                            Label("Bekijken & meten", systemImage: "cube.transparent")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(scan.modelBestandsnaam == nil && scan.pointcloudBestandsnaam == nil)

                        ForEach(scan.notities) { notitie in
                            HStack(alignment: .top, spacing: 8) {
                                if let fotoBestandsnaam = notitie.fotoBestandsnaam,
                                   let foto = ProjectStore.shared.laadFoto(bestandsnaam: fotoBestandsnaam, woningId: woningId) {
                                    Image(uiImage: foto)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    if notitie.type.isEmpty {
                                        Text("Nog niet ingevuld").font(.caption).bold().foregroundStyle(.orange)
                                    } else {
                                        Text(notitie.type).font(.caption).bold()
                                    }
                                    if !notitie.bericht.isEmpty {
                                        Text(notitie.bericht).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .onDelete { indexSet in
                    var bijgewerkt = woning
                    for index in indexSet {
                        let scan = kamerScans[index]
                        if let bestandsnaam = scan.modelBestandsnaam {
                            ProjectStore.shared.verwijderModel(bestandsnaam: bestandsnaam, woningId: woningId)
                        }
                        if let bestandsnaam = scan.pointcloudBestandsnaam {
                            ProjectStore.shared.verwijderModel(bestandsnaam: bestandsnaam, woningId: woningId)
                        }
                        bijgewerkt.kamerScans.removeAll { $0.id == scan.id }
                    }
                    store.opslaan(bijgewerkt)
                }
                Button {
                    toonRoomScan = true
                } label: {
                    Label("Scan verdieping in 3D", systemImage: "cube.transparent")
                }
            }

            Section("Gevels (\(gevels.count))") {
                ForEach(gevels) { gevel in
                    NavigationLink {
                        GevelFormView(woningId: woningId, verdieping: verdieping, gevelId: gevel.id)
                    } label: {
                        gevelRij(gevel)
                    }
                }
                NavigationLink("Gevel toevoegen") {
                    GevelFormView(woningId: woningId, verdieping: verdieping, gevelId: nil)
                }
            }

            Section("Daken (\(daken.count))") {
                ForEach(daken) { dak in
                    NavigationLink {
                        DakFormView(woningId: woningId, verdieping: verdieping, dakId: dak.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Dak \(dak.geveldeelNaam) · \(dak.orientatie.rawValue)")
                            Text("\(String(format: "%.1f", dak.oppM2)) m² · \(dak.vlakType.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink("Dak toevoegen") {
                    DakFormView(woningId: woningId, verdieping: verdieping, dakId: nil)
                }
            }

            Section("Vloeren (\(vloeren.count))") {
                ForEach(vloeren) { vloer in
                    NavigationLink {
                        VloerFormView(woningId: woningId, verdieping: verdieping, vloerId: vloer.id)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("Vloer · \(String(format: "%.1f", vloer.oppM2)) m²")
                            Text(vloer.isolatieLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink("Vloer toevoegen") {
                    VloerFormView(woningId: woningId, verdieping: verdieping, vloerId: nil)
                }
            }
        }
        .navigationTitle(verdieping)
        .fullScreenCover(isPresented: $toonRoomScan) {
            RoomScanScherm(titel: verdieping, woningId: woningId) { notities, modelUrl, pointcloudUrl, duurSeconden in
                verwerkScanResultaat(notities: notities, modelUrl: modelUrl, pointcloudUrl: pointcloudUrl, duurSeconden: duurSeconden)
            }
        }
        .fullScreenCover(item: $actieveScan) { scan in
            Model3DViewerScherm(woningId: woningId, kamerScanId: scan.id)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func gevelRij(_ gevel: Gevel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(gevel.geveldeelNaam) · \(gevel.orientatie.rawValue)")
                .font(.body)
            Text("\(String(format: "%.1f", gevel.oppM2)) m² · \(gevel.openingen.count) opening(en)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func verwerkScanResultaat(notities: [ScanNotitie], modelUrl: URL?, pointcloudUrl: URL?, duurSeconden: Int) {
        var modelBestandsnaam: String?
        if let modelUrl {
            modelBestandsnaam = ProjectStore.shared.slaModelOp(vanaf: modelUrl, voor: woningId)
        }
        var pointcloudBestandsnaam: String?
        if let pointcloudUrl {
            pointcloudBestandsnaam = ProjectStore.shared.slaModelOp(vanaf: pointcloudUrl, voor: woningId)
        }
        let scan = KamerScan(
            verdieping: verdieping,
            naam: "\(verdieping) · scan \(kamerScans.count + 1)",
            modelBestandsnaam: modelBestandsnaam,
            pointcloudBestandsnaam: pointcloudBestandsnaam,
            notities: notities,
            duurSeconden: duurSeconden
        )
        var bijgewerkt = woning
        bijgewerkt.kamerScans.append(scan)
        store.opslaan(bijgewerkt)
    }
}
