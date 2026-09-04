import SwiftUI

struct GebouwhoogteFormView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var hoogteM: Double = 0
    @State private var toonMeetScherm = false

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Gebouwhoogte (BIB_gebouwhoogte)") {
                HStack {
                    Text("Hoogte")
                    Spacer()
                    TextField("m", value: $hoogteM, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Button { toonMeetScherm = true } label: { Image(systemName: "arkit") }
                        .buttonStyle(.borderless)
                }
                Text("Meet van maaiveld tot aan de nok/bovenkant van het gebouw.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Gebouwhoogte")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Opslaan") {
                    var bijgewerkt = woning
                    bijgewerkt.gebouwhoogteMm = hoogteM * 1000
                    store.opslaan(bijgewerkt)
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $toonMeetScherm) {
            MeetScherm(titel: "Meet de gebouwhoogte") { afstand in
                hoogteM = (afstand * 100).rounded() / 100
            }
        }
        .onAppear {
            if let mm = woning.gebouwhoogteMm { hoogteM = mm / 1000 }
        }
    }
}

struct GebruiksoppervlakView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @State private var nieuwLevel = ""
    @State private var nieuweOpp: Double = 0

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Per verdieping (BENG_GO)") {
                ForEach(woning.gebruiksoppervlaktes) { entry in
                    HStack {
                        Text(entry.level)
                        Spacer()
                        Text(String(format: "%.1f m²", entry.oppM2)).foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    var bijgewerkt = woning
                    bijgewerkt.gebruiksoppervlaktes.remove(atOffsets: indexSet)
                    store.opslaan(bijgewerkt)
                }
            }
            Section("Toevoegen") {
                Picker("Verdieping", selection: $nieuwLevel) {
                    Text("Kies verdieping").tag("")
                    ForEach(woning.verdiepingNamen, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Oppervlakte")
                    Spacer()
                    TextField("m²", value: $nieuweOpp, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Button("Toevoegen") {
                    guard !nieuwLevel.isEmpty else { return }
                    var bijgewerkt = woning
                    bijgewerkt.gebruiksoppervlaktes.append(GebruiksoppervlakEntry(level: nieuwLevel, oppM2: nieuweOpp))
                    store.opslaan(bijgewerkt)
                    nieuwLevel = ""
                    nieuweOpp = 0
                }
            }
        }
        .navigationTitle("Gebruiksoppervlak")
    }
}

struct AftappuntenView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @State private var nieuw = Aftappunt(naam: "", verdieping: "")

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        Form {
            Section("Boiler / aftappunten (BENG_boilers)") {
                ForEach(woning.aftappunten) { punt in
                    VStack(alignment: .leading) {
                        Text(punt.naam)
                        if let afstand = punt.afstandM {
                            Text(String(format: "%.2f m (h: %.2f / v: %.2f)", afstand, punt.afstandHorizontaalM ?? 0, punt.afstandVerticaalM ?? 0))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    var bijgewerkt = woning
                    bijgewerkt.aftappunten.remove(atOffsets: indexSet)
                    store.opslaan(bijgewerkt)
                }
            }
            Section("Toevoegen") {
                TextField("Naam (bv. Boiler, Bad, Spoelbak)", text: $nieuw.naam)
                TextField("Categorie (bv. Badkamer, Keuken)", text: Binding(
                    get: { nieuw.categorie ?? "" },
                    set: { nieuw.categorie = $0 }
                ))
                Picker("Verdieping", selection: $nieuw.verdieping) {
                    Text("Kies verdieping").tag("")
                    ForEach(woning.verdiepingNamen, id: \.self) { Text($0).tag($0) }
                }
                HStack {
                    Text("Afstand (m)")
                    Spacer()
                    TextField("m", value: Binding(get: { nieuw.afstandM ?? 0 }, set: { nieuw.afstandM = $0 }), format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                }
                HStack {
                    Text("Horizontaal (m)")
                    Spacer()
                    TextField("m", value: Binding(get: { nieuw.afstandHorizontaalM ?? 0 }, set: { nieuw.afstandHorizontaalM = $0 }), format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                }
                HStack {
                    Text("Verticaal (m)")
                    Spacer()
                    TextField("m", value: Binding(get: { nieuw.afstandVerticaalM ?? 0 }, set: { nieuw.afstandVerticaalM = $0 }), format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                }
                Button("Toevoegen") {
                    guard !nieuw.naam.isEmpty else { return }
                    var bijgewerkt = woning
                    bijgewerkt.aftappunten.append(nieuw)
                    store.opslaan(bijgewerkt)
                    nieuw = Aftappunt(naam: "", verdieping: "")
                }
            }
        }
        .navigationTitle("Boiler / aftappunten")
    }
}
