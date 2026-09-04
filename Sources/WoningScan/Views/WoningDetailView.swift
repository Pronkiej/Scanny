import SwiftUI

struct WoningDetailView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @State private var toonExport = false
    @State private var toonChecklist = false
    @State private var toonNieuweVerdieping = false
    @State private var nieuweVerdiepingNaam = ""

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        List {
            Section {
                Button {
                    toonChecklist = true
                } label: {
                    Label("Start-checklist (zolder/kelder)", systemImage: "checklist")
                }
            }

            Section("Verdiepingen") {
                ForEach(woning.verdiepingNamen, id: \.self) { verdieping in
                    NavigationLink(verdieping) {
                        VerdiepingView(woningId: woningId, verdieping: verdieping)
                    }
                }
                Button {
                    toonNieuweVerdieping = true
                } label: {
                    Label("Verdieping toevoegen", systemImage: "plus")
                }
            }

            Section("Overige gegevens") {
                NavigationLink {
                    GebouwhoogteFormView(woningId: woningId)
                } label: {
                    HStack {
                        Text("Gebouwhoogte")
                        Spacer()
                        if let hoogte = woning.gebouwhoogteMm {
                            Text("\(Int(hoogte)) mm").foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink {
                    GebruiksoppervlakView(woningId: woningId)
                } label: {
                    Text("Gebruiksoppervlak per verdieping (\(woning.gebruiksoppervlaktes.count))")
                }
                NavigationLink {
                    AftappuntenView(woningId: woningId)
                } label: {
                    Text("Boiler / aftappunten (\(woning.aftappunten.count))")
                }
            }

            Section {
                Button {
                    toonExport = true
                } label: {
                    Label("Exporteer opname", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(woning.naam.isEmpty ? "Project" : woning.naam)
        .sheet(isPresented: $toonChecklist) {
            IntroChecklistView(woningId: woningId)
        }
        .sheet(isPresented: $toonExport) {
            ExportView(woningId: woningId)
        }
        .alert("Nieuwe verdieping", isPresented: $toonNieuweVerdieping) {
            TextField("Naam (bv. 1e verdieping)", text: $nieuweVerdiepingNaam)
            Button("Annuleren", role: .cancel) { nieuweVerdiepingNaam = "" }
            Button("Toevoegen") {
                guard !nieuweVerdiepingNaam.isEmpty else { return }
                var bijgewerkt = woning
                bijgewerkt.verdiepingNamen.append(nieuweVerdiepingNaam)
                store.opslaan(bijgewerkt)
                nieuweVerdiepingNaam = ""
            }
        }
    }
}
