import SwiftUI

/// Overzicht van alle ruimtes voor de puntentelling (Woningwaarderingsstelsel): per ruimte zet je
/// "Aanwezig" en "Verwarmd" aan of uit en voeg je eventueel foto's toe. Keuken en badkamer hebben
/// daarnaast hun eigen kwaliteitspunten en krijgen een los scherm.
struct PuntentellingView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        List {
            Section("Woonruimtes") {
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "Woonkamer", keyPath: \.woonkamer)
                } label: {
                    ruimteRij("Woonkamer", ruimte: woning.puntentelling.woonkamer)
                }
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "Woonkamer met open keuken", keyPath: \.woonkamerMetOpenKeuken)
                } label: {
                    ruimteRij("Woonkamer met open keuken", ruimte: woning.puntentelling.woonkamerMetOpenKeuken)
                }
            }

            Section("Keuken") {
                NavigationLink {
                    PuntentellingKeukenFormView(woningId: woningId)
                } label: {
                    ruimteRij("Keuken", aanwezig: woning.puntentelling.keuken.aanwezig, aantalFotos: woning.puntentelling.keuken.fotoBestandsnamen.count)
                }
            }

            Section("Badkamer") {
                NavigationLink {
                    PuntentellingBadkamerFormView(woningId: woningId)
                } label: {
                    ruimteRij("Badkamer", aanwezig: woning.puntentelling.badkamer.aanwezig, aantalFotos: woning.puntentelling.badkamer.fotoBestandsnamen.count)
                }
            }

            Section("Slaapkamers") {
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "1e slaapkamer", keyPath: \.slaapkamer1)
                } label: {
                    ruimteRij("1e slaapkamer", ruimte: woning.puntentelling.slaapkamer1)
                }
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "2e slaapkamer", keyPath: \.slaapkamer2)
                } label: {
                    ruimteRij("2e slaapkamer", ruimte: woning.puntentelling.slaapkamer2)
                }
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "3e slaapkamer", keyPath: \.slaapkamer3)
                } label: {
                    ruimteRij("3e slaapkamer", ruimte: woning.puntentelling.slaapkamer3)
                }
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "4e slaapkamer", keyPath: \.slaapkamer4)
                } label: {
                    ruimteRij("4e slaapkamer", ruimte: woning.puntentelling.slaapkamer4)
                }
            }

            Section("Overige ruimtes") {
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "Serre", keyPath: \.serre)
                } label: {
                    ruimteRij("Serre", ruimte: woning.puntentelling.serre)
                }
                NavigationLink {
                    PuntentellingRuimteFormView(woningId: woningId, titel: "Zolderkamer", keyPath: \.zolderkamer)
                } label: {
                    ruimteRij("Zolderkamer", ruimte: woning.puntentelling.zolderkamer)
                }
            }

            Section("Buitenruimte") {
                HStack {
                    Text("Oppervlakte buitenruimte")
                    Spacer()
                    TextField("m²", value: oppervlakteBuitenBinding, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("m²").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Puntentelling")
    }

    @ViewBuilder
    private func ruimteRij(_ titel: String, ruimte: PuntentellingRuimte) -> some View {
        ruimteRij(titel, aanwezig: ruimte.aanwezig, aantalFotos: ruimte.fotoBestandsnamen.count)
    }

    @ViewBuilder
    private func ruimteRij(_ titel: String, aanwezig: Bool, aantalFotos: Int) -> some View {
        HStack {
            Text(titel)
            if aantalFotos > 0 {
                Image(systemName: "photo.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(aanwezig ? "Aanwezig" : "Niet aanwezig")
                .font(.caption)
                .foregroundStyle(aanwezig ? Color.accentColor : Color.secondary)
        }
    }

    private var oppervlakteBuitenBinding: Binding<Double> {
        Binding(
            get: { woning.puntentelling.oppervlakteBuitenruimteM2 ?? 0 },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling.oppervlakteBuitenruimteM2 = nieuw
                store.opslaan(bijgewerkt)
            }
        )
    }
}

/// Generiek ruimte-scherm voor woonkamer(s), slaapkamers, serre en zolderkamer: aanwezig, verwarmd
/// (alleen relevant als aanwezig) en foto's van de ruimte.
struct PuntentellingRuimteFormView: View {
    let woningId: UUID
    let titel: String
    let keyPath: WritableKeyPath<Puntentelling, PuntentellingRuimte>

    @EnvironmentObject private var store: ProjectStore

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }
    private var ruimte: PuntentellingRuimte { woning.puntentelling[keyPath: keyPath] }

    var body: some View {
        Form {
            Section {
                Toggle("Aanwezig", isOn: bindingAanwezig)
                if ruimte.aanwezig {
                    Toggle("Verwarmd", isOn: bindingVerwarmd)
                }
            }
            if ruimte.aanwezig {
                Section("Foto's") {
                    FotoLijstVeld(woningId: woningId, bestandsnamen: bindingFotos)
                }
            }
        }
        .navigationTitle(titel)
    }

    private var bindingAanwezig: Binding<Bool> {
        Binding(
            get: { ruimte.aanwezig },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling[keyPath: keyPath].aanwezig = nieuw
                if !nieuw { bijgewerkt.puntentelling[keyPath: keyPath].verwarmd = false }
                store.opslaan(bijgewerkt)
            }
        )
    }

    private var bindingVerwarmd: Binding<Bool> {
        Binding(
            get: { ruimte.verwarmd },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling[keyPath: keyPath].verwarmd = nieuw
                store.opslaan(bijgewerkt)
            }
        )
    }

    private var bindingFotos: Binding<[String]> {
        Binding(
            get: { ruimte.fotoBestandsnamen },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling[keyPath: keyPath].fotoBestandsnamen = nieuw
                store.opslaan(bijgewerkt)
            }
        )
    }
}

/// Keuken-scherm: aanwezig/verwarmd, aanrecht & kastruimte, inbouwapparatuur, kranen en foto's.
struct PuntentellingKeukenFormView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }
    private var keuken: PuntentellingKeuken { woning.puntentelling.keuken }

    var body: some View {
        Form {
            Section {
                Toggle("Aanwezig", isOn: binding(\.aanwezig, resetVerwarmd: true))
                if keuken.aanwezig {
                    Toggle("Verwarmd", isOn: binding(\.verwarmd))
                }
            }
            if keuken.aanwezig {
                Section("Aanrecht & kasten") {
                    numeriekRij("Lengte aanrechtblad", eenheid: "cm", waarde: optioneleNumeriekBinding(\.lengteAanrechtbladCm))
                    numeriekRij("Totale breedte keukenkasten", eenheid: "cm", waarde: optioneleNumeriekBinding(\.totaleBreedteKeukenkastenCm))
                }
                Section("Inbouwapparatuur") {
                    Toggle("Inbouw kookplaat", isOn: binding(\.inbouwKookplaat))
                    Toggle("Inbouw oven", isOn: binding(\.inbouwOven))
                    Toggle("Afzuigkap", isOn: binding(\.afzuigkap))
                    Toggle("Inbouw magnetron", isOn: binding(\.inbouwMagnetron))
                    Toggle("Inbouw koelkast", isOn: binding(\.inbouwKoelkast))
                    Toggle("Inbouw vriezer", isOn: binding(\.inbouwVriezer))
                    Toggle("Inbouw vaatwasser", isOn: binding(\.inbouwVaatwasser))
                    Toggle("Kokend-waterkraan", isOn: binding(\.kokendWaterkraan))
                }
                Section("Kranen") {
                    stepperRij("Luxe mengkraan", aantal: binding(\.luxeMengkranen))
                    stepperRij("Thermostatische mengkraan", aantal: binding(\.thermostatischeMengkranen))
                }
                Section("Foto's") {
                    FotoLijstVeld(woningId: woningId, bestandsnamen: binding(\.fotoBestandsnamen))
                }
            }
        }
        .navigationTitle("Keuken")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PuntentellingKeuken, Value>, resetVerwarmd: Bool = false) -> Binding<Value> {
        Binding(
            get: { woning.puntentelling.keuken[keyPath: keyPath] },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling.keuken[keyPath: keyPath] = nieuw
                if resetVerwarmd, let aanwezig = nieuw as? Bool, !aanwezig {
                    bijgewerkt.puntentelling.keuken.verwarmd = false
                }
                store.opslaan(bijgewerkt)
            }
        )
    }

    private func optioneleNumeriekBinding(_ keyPath: WritableKeyPath<PuntentellingKeuken, Double?>) -> Binding<Double> {
        Binding(
            get: { woning.puntentelling.keuken[keyPath: keyPath] ?? 0 },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling.keuken[keyPath: keyPath] = nieuw
                store.opslaan(bijgewerkt)
            }
        )
    }

    @ViewBuilder
    private func numeriekRij(_ titel: String, eenheid: String, waarde: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField(eenheid, value: waarde, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(eenheid).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func stepperRij(_ titel: String, aantal: Binding<Int>) -> some View {
        Stepper(value: aantal, in: 0...20) {
            HStack {
                Text(titel)
                Spacer()
                Text("\(aantal.wrappedValue)").foregroundStyle(.secondary)
            }
        }
    }
}

/// Badkamer-scherm: aanwezig/verwarmd, sanitair (toiletten/wastafels/douche-bad), overige
/// voorzieningen, kranen en foto's.
struct PuntentellingBadkamerFormView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }
    private var badkamer: PuntentellingBadkamer { woning.puntentelling.badkamer }

    var body: some View {
        Form {
            Section {
                Toggle("Aanwezig", isOn: binding(\.aanwezig, resetVerwarmd: true))
                if badkamer.aanwezig {
                    Toggle("Verwarmd", isOn: binding(\.verwarmd))
                }
            }
            if badkamer.aanwezig {
                Section("Toiletten") {
                    stepperRij("Aantal toiletten", aantal: binding(\.aantalToiletten))
                    stepperRij("Waarvan zwevende toiletten", aantal: binding(\.waarvanZwevendeToiletten))
                    stepperRij("Waarvan toiletten in badkamer", aantal: binding(\.waarvanToilettenInBadkamer))
                }
                Section("Wastafels & douche/bad") {
                    stepperRij("Aantal wastafels", aantal: binding(\.aantalWastafels))
                    stepperRij("Meerpersoons wastafels (min. 70 cm)", aantal: binding(\.aantalMeerpersoonsWastafels))
                    Picker("Douche/bad", selection: binding(\.doucheOfBad)) {
                        ForEach(DoucheOfBad.allCases) { optie in
                            Text(optie.rawValue).tag(optie)
                        }
                    }
                }
                Section("Voorzieningen") {
                    Toggle("Badkamermeubel met wastafel", isOn: binding(\.badkamermeubelMetWastafel))
                    Toggle("Bubbelbad (whirlpool)", isOn: binding(\.bubbelbad))
                    Toggle("Volledig gesloten doucheafscheiding", isOn: binding(\.volledigGeslotenDoucheafscheiding))
                    Toggle("Handdoekradiator", isOn: binding(\.handdoekradiator))
                    Toggle("Kastruimte (min. 40 cm breed en hoog)", isOn: binding(\.kastruimte))
                    stepperRij("Stopcontacten", aantal: binding(\.stopcontacten))
                }
                Section("Kranen") {
                    stepperRij("Luxe mengkraan", aantal: binding(\.luxeMengkranen))
                    stepperRij("Thermostatische mengkraan", aantal: binding(\.thermostatischeMengkranen))
                }
                Section("Foto's") {
                    FotoLijstVeld(woningId: woningId, bestandsnamen: binding(\.fotoBestandsnamen))
                }
            }
        }
        .navigationTitle("Badkamer")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PuntentellingBadkamer, Value>, resetVerwarmd: Bool = false) -> Binding<Value> {
        Binding(
            get: { woning.puntentelling.badkamer[keyPath: keyPath] },
            set: { nieuw in
                var bijgewerkt = woning
                bijgewerkt.puntentelling.badkamer[keyPath: keyPath] = nieuw
                if resetVerwarmd, let aanwezig = nieuw as? Bool, !aanwezig {
                    bijgewerkt.puntentelling.badkamer.verwarmd = false
                }
                store.opslaan(bijgewerkt)
            }
        )
    }

    @ViewBuilder
    private func stepperRij(_ titel: String, aantal: Binding<Int>) -> some View {
        Stepper(value: aantal, in: 0...20) {
            HStack {
                Text(titel)
                Spacer()
                Text("\(aantal.wrappedValue)").foregroundStyle(.secondary)
            }
        }
    }
}

