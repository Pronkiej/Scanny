import SwiftUI

/// Toont alle gevels, daken en vloeren die aan één verdieping (level) hangen, met knoppen om
/// nieuwe elementen toe te voegen. Dit is het scherm waar het gros van het scanwerk gebeurt.
struct VerdiepingView: View {
    let woningId: UUID
    let verdieping: String

    @EnvironmentObject private var store: ProjectStore

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    private var gevels: [Gevel] { woning.gevels.filter { $0.verdieping == verdieping } }
    private var daken: [Dak] { woning.daken.filter { $0.verdieping == verdieping } }
    private var vloeren: [Vloer] { woning.vloeren.filter { $0.level == verdieping } }

    var body: some View {
        List {
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
}
