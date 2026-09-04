import SwiftUI

struct OpeningFormView: View {
    let woningId: UUID
    @Binding var opening: Opening
    var standaardOrientatie: Orientatie

    @EnvironmentObject private var refData: ReferenceData
    @State private var toonMeetBreedte = false
    @State private var toonMeetHoogte = false

    var body: some View {
        Form {
            Section("Type") {
                Picker("Type", selection: $opening.type) {
                    ForEach(OpeningType.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Grenst aan", selection: $opening.grenstAan) {
                    ForEach(AangrenzendeRuimte.allCases) { Text($0.weergaveNaam).tag($0) }
                }
            }

            if opening.type == .raam || opening.type == .paneelInKozijn {
                Section("Glas / kozijn") {
                    Picker("Glastype", selection: Binding(
                        get: { opening.glas ?? .dubbelGlas },
                        set: { opening.glas = $0 }
                    )) {
                        ForEach(GlasType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Kozijnmateriaal", selection: Binding(
                        get: { opening.kozijnMateriaal ?? .houtOfKunststof },
                        set: { opening.kozijnMateriaal = $0 }
                    )) {
                        ForEach(KozijnMateriaal.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            } else {
                Section("Isolatie") {
                    Picker("Isolatie", selection: Binding(
                        get: { opening.deurIsolatieLabel ?? "" },
                        set: { opening.deurIsolatieLabel = $0 }
                    )) {
                        Text("Kies isolatie").tag("")
                        ForEach(refData.deurIsolatie) { optie in
                            Text(optie.label).tag(optie.label)
                        }
                    }
                }
            }

            Section("Afmetingen") {
                HStack {
                    Text("Breedte")
                    Spacer()
                    TextField("cm", value: $opening.breedteCm, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Button { toonMeetBreedte = true } label: { Image(systemName: "arkit") }
                        .buttonStyle(.borderless)
                }
                HStack {
                    Text("Hoogte")
                    Spacer()
                    TextField("cm", value: $opening.hoogteCm, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Button { toonMeetHoogte = true } label: { Image(systemName: "arkit") }
                        .buttonStyle(.borderless)
                }
                HStack {
                    Text("Oppervlakte")
                    Spacer()
                    Text(String(format: "%.2f m²", opening.oppM2)).foregroundStyle(.secondary)
                }
            }

            Section("Overstek") {
                Toggle("Heeft overstek", isOn: $opening.isOverstek)
                if opening.isOverstek {
                    HStack {
                        Text("Hoogteverschil")
                        Spacer()
                        TextField("cm", value: Binding(
                            get: { opening.overstekHoogteverschilCm ?? 0 },
                            set: { opening.overstekHoogteverschilCm = $0 }
                        ), format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                    HStack {
                        Text("Afstand")
                        Spacer()
                        TextField("cm", value: Binding(
                            get: { opening.overstekAfstandCm ?? 0 },
                            set: { opening.overstekAfstandCm = $0 }
                        ), format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                }
            }

            Section("Zonwering") {
                Picker("Type", selection: $opening.zonweringType) {
                    ForEach(ZonweringType.allCases) { Text($0.rawValue).tag($0) }
                }
                if opening.zonweringType != .geen {
                    TextField("Kleur", text: Binding(
                        get: { opening.zonweringKleur ?? "" },
                        set: { opening.zonweringKleur = $0 }
                    ))
                    Picker("Regeling", selection: $opening.zonweringRegeling) {
                        ForEach(ZonweringRegeling.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }

            Section("Foto") {
                FotoVeld(woningId: woningId, bestandsnaam: $opening.fotoBestandsnaam)
            }

            Section("Notities") {
                TextEditor(text: $opening.notities).frame(minHeight: 60)
            }
        }
        .navigationTitle(opening.type.rawValue)
        .onAppear {
            if opening.glas == nil { opening.glas = .dubbelGlas }
            if opening.kozijnMateriaal == nil { opening.kozijnMateriaal = .houtOfKunststof }
        }
        .fullScreenCover(isPresented: $toonMeetBreedte) {
            MeetScherm(titel: "Meet de breedte") { afstand in
                opening.breedteCm = (afstand * 100 * 10).rounded() / 10
            }
        }
        .fullScreenCover(isPresented: $toonMeetHoogte) {
            MeetScherm(titel: "Meet de hoogte") { afstand in
                opening.hoogteCm = (afstand * 100 * 10).rounded() / 10
            }
        }
    }
}
