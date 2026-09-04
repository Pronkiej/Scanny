import SwiftUI

struct DakFormView: View {
    let woningId: UUID
    let verdieping: String
    let dakId: UUID?

    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var refData: ReferenceData
    @Environment(\.dismiss) private var dismiss

    @State private var dak = Dak(geveldeelNaam: "", verdieping: "", lengteM: 0, breedteM: 0, orientatie: .noord)

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Dak") {
                TextField("Naam / nummer", text: $dak.geveldeelNaam)
                Picker("Type", selection: $dak.vlakType) {
                    Text(VlakType.schuinDak.rawValue).tag(VlakType.schuinDak)
                    Text(VlakType.platDak.rawValue).tag(VlakType.platDak)
                }
                Picker("Grenst aan", selection: $dak.grenstAan) {
                    ForEach(AangrenzendeRuimte.allCases) { Text($0.weergaveNaam).tag($0) }
                }
                Picker("Isolatie", selection: $dak.eigenschappenLabel) {
                    Text("Kies isolatie").tag("")
                    ForEach(refData.dakIsolatie) { optie in
                        Text(optie.label).tag(optie.label)
                    }
                }
                OrientatiePicker(orientatie: $dak.orientatie)
                HStack {
                    Text("Helling")
                    Spacer()
                    TextField("°", value: $dak.hellingGraden, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                MeetVeld(titel: "Lengte", waardeMeters: $dak.lengteM, meetTitel: "Meet de lengte van het dakvlak")
                MeetVeld(titel: "Breedte", waardeMeters: $dak.breedteM, meetTitel: "Meet de breedte van het dakvlak")
                HStack {
                    Text("Oppervlakte")
                    Spacer()
                    Text(String(format: "%.2f m²", dak.oppM2)).foregroundStyle(.secondary)
                }
            }

            Section("Foto") {
                FotoVeld(woningId: woningId, bestandsnaam: $dak.fotoBestandsnaam)
            }

            Section("Notities") {
                TextEditor(text: $dak.notities).frame(minHeight: 80)
            }

            if dakId != nil {
                Section {
                    Button(role: .destructive) {
                        var bijgewerkt = woning
                        bijgewerkt.daken.removeAll { $0.id == dak.id }
                        store.opslaan(bijgewerkt)
                        dismiss()
                    } label: {
                        Text("Dak verwijderen")
                    }
                }
            }
        }
        .navigationTitle(dak.geveldeelNaam.isEmpty ? "Nieuw dak" : "Dak \(dak.geveldeelNaam)")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Opslaan") {
                    var bijgewerkt = woning
                    if let index = bijgewerkt.daken.firstIndex(where: { $0.id == dak.id }) {
                        bijgewerkt.daken[index] = dak
                    } else {
                        bijgewerkt.daken.append(dak)
                    }
                    store.opslaan(bijgewerkt)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let dakId, let bestaand = woning.daken.first(where: { $0.id == dakId }) {
                dak = bestaand
            } else {
                dak.verdieping = verdieping
            }
        }
    }
}
