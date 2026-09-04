import SwiftUI

struct VloerFormView: View {
    let woningId: UUID
    let verdieping: String
    let vloerId: UUID?

    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var refData: ReferenceData
    @Environment(\.dismiss) private var dismiss

    @State private var vloer = Vloer(level: "", lengteM: 0, breedteM: 0, perimeterM: 0)

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Vloer") {
                Picker("Isolatie vloer", selection: $vloer.isolatieLabel) {
                    Text("Kies isolatie").tag("")
                    ForEach(refData.vloerIsolatie) { optie in
                        Text(optie.label).tag(optie.label)
                    }
                }
                Picker("Isolatie aangrenzende wanden (Rbw)", selection: $vloer.rbwWaardeWandenLabel) {
                    Text("Kies isolatie").tag("")
                    ForEach(refData.vloerIsolatie) { optie in
                        Text(optie.label).tag(optie.label)
                    }
                }
                MeetVeld(titel: "Lengte", waardeMeters: $vloer.lengteM, meetTitel: "Meet de lengte van de vloer")
                MeetVeld(titel: "Breedte", waardeMeters: $vloer.breedteM, meetTitel: "Meet de breedte van de vloer")
                MeetVeld(titel: "Perimeter", waardeMeters: $vloer.perimeterM, meetTitel: "Meet de omtrek van de vloer")
                HStack {
                    Text("Oppervlakte")
                    Spacer()
                    Text(String(format: "%.2f m²", vloer.oppM2)).foregroundStyle(.secondary)
                }
            }

            Section("Foto") {
                FotoVeld(woningId: woningId, bestandsnaam: $vloer.fotoBestandsnaam)
            }

            Section("Notities") {
                TextEditor(text: $vloer.notities).frame(minHeight: 80)
            }

            if vloerId != nil {
                Section {
                    Button(role: .destructive) {
                        var bijgewerkt = woning
                        bijgewerkt.vloeren.removeAll { $0.id == vloer.id }
                        store.opslaan(bijgewerkt)
                        dismiss()
                    } label: {
                        Text("Vloer verwijderen")
                    }
                }
            }
        }
        .navigationTitle("Vloer")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Opslaan") {
                    var bijgewerkt = woning
                    if let index = bijgewerkt.vloeren.firstIndex(where: { $0.id == vloer.id }) {
                        bijgewerkt.vloeren[index] = vloer
                    } else {
                        bijgewerkt.vloeren.append(vloer)
                    }
                    store.opslaan(bijgewerkt)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let vloerId, let bestaand = woning.vloeren.first(where: { $0.id == vloerId }) {
                vloer = bestaand
            } else {
                vloer.level = verdieping
            }
        }
    }
}
