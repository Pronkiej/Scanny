import SwiftUI

struct GevelFormView: View {
    let woningId: UUID
    let verdieping: String
    let gevelId: UUID?   // nil = nieuwe gevel

    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var refData: ReferenceData
    @Environment(\.dismiss) private var dismiss

    @State private var gevel = Gevel(geveldeelNaam: "", verdieping: "", hoogteM: 0, breedteM: 0, orientatie: .noord)
    @State private var toonNieuweOpening = false
    @State private var nieuweOpeningWerk = Opening(type: .raam, orientatie: .noord, breedteCm: 0, hoogteCm: 0)

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Gevel") {
                TextField("Naam (bv. D : 01)", text: $gevel.geveldeelNaam)
                Picker("Grenst aan", selection: $gevel.grenstAan) {
                    ForEach(AangrenzendeRuimte.allCases) { Text($0.weergaveNaam).tag($0) }
                }
                Picker("Isolatie", selection: $gevel.eigenschappenLabel) {
                    Text("Kies isolatie").tag("")
                    ForEach(refData.wandIsolatie) { optie in
                        Text(optie.label).tag(optie.label)
                    }
                }
                OrientatiePicker(orientatie: $gevel.orientatie)
                MeetVeld(titel: "Hoogte", waardeMeters: $gevel.hoogteM, meetTitel: "Meet de hoogte van de gevel")
                MeetVeld(titel: "Breedte", waardeMeters: $gevel.breedteM, meetTitel: "Meet de breedte van de gevel")
                HStack {
                    Text("Oppervlakte")
                    Spacer()
                    Text(String(format: "%.2f m²", gevel.oppM2)).foregroundStyle(.secondary)
                }
            }

            Section("Foto") {
                FotoVeld(woningId: woningId, bestandsnaam: $gevel.fotoBestandsnaam)
            }

            Section("Notities") {
                TextEditor(text: $gevel.notities).frame(minHeight: 80)
            }

            Section("Ramen / deuren / panelen (\(gevel.openingen.count))") {
                ForEach($gevel.openingen) { $opening in
                    NavigationLink {
                        OpeningFormView(woningId: woningId, opening: $opening, standaardOrientatie: gevel.orientatie)
                    } label: {
                        VStack(alignment: .leading) {
                            Text("\(opening.type.rawValue) · \(String(format: "%.2f", opening.oppM2)) m²")
                            Text(opening.eigenschappenKolomTekst).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { gevel.openingen.remove(atOffsets: $0) }

                Button {
                    nieuweOpeningWerk = Opening(type: .raam, orientatie: gevel.orientatie, breedteCm: 0, hoogteCm: 0)
                    toonNieuweOpening = true
                } label: {
                    Label("Opening toevoegen", systemImage: "plus")
                }
            }

            if gevelId != nil {
                Section {
                    Button(role: .destructive) {
                        var bijgewerkt = woning
                        bijgewerkt.gevels.removeAll { $0.id == gevel.id }
                        store.opslaan(bijgewerkt)
                        dismiss()
                    } label: {
                        Text("Gevel verwijderen")
                    }
                }
            }
        }
        .navigationTitle(gevel.geveldeelNaam.isEmpty ? "Nieuwe gevel" : gevel.geveldeelNaam)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Opslaan") { sla_op() }
            }
        }
        .sheet(isPresented: $toonNieuweOpening) {
            NavigationStack {
                OpeningFormView(woningId: woningId, opening: $nieuweOpeningWerk, standaardOrientatie: gevel.orientatie)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Toevoegen") {
                                gevel.openingen.append(nieuweOpeningWerk)
                                toonNieuweOpening = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annuleren") { toonNieuweOpening = false }
                        }
                    }
            }
        }
        .onAppear {
            if let gevelId, let bestaand = woning.gevels.first(where: { $0.id == gevelId }) {
                gevel = bestaand
            } else {
                gevel.verdieping = verdieping
            }
        }
    }

    private func sla_op() {
        var bijgewerkt = woning
        if let index = bijgewerkt.gevels.firstIndex(where: { $0.id == gevel.id }) {
            bijgewerkt.gevels[index] = gevel
        } else {
            bijgewerkt.gevels.append(gevel)
        }
        store.opslaan(bijgewerkt)
        dismiss()
    }
}
