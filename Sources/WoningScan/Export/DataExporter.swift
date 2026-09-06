import Foundation

/// Exporteert een Woning-opname als één .zip met daarin:
/// - woning.json (volledige data, 1-op-1 herbruikbaar / later te verwerken)
/// - CSV-bestanden per categorie (gemakkelijk te openen in Excel), met een kolomindeling die al dicht
///   tegen het benodigde Vabi-importformaat aan zit zodat latere fine-tuning naar het exacte format
///   weinig werk is
/// - de gemaakte foto's, met bestandsnamen die corresponderen met de "foto"-kolom in de CSV's
enum DataExporter {
    @MainActor
    static func exporteer(_ woning: Woning) throws -> URL {
        var entries: [SimpleZip.Entry] = []

        // 1. Volledige data als JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(woning)
        entries.append(.init(naam: "woning.json", data: jsonData))

        // 2. CSV's per categorie
        if woning.toontEnergielabel {
            entries.append(.init(naam: "BENG_wanden_en_wandopeningen.csv", data: csvWanden(woning)))
            entries.append(.init(naam: "BENG_daken.csv", data: csvDaken(woning)))
            entries.append(.init(naam: "BENG_vloeren.csv", data: csvVloeren(woning)))
            entries.append(.init(naam: "BENG_gebouwhoogte.csv", data: csvGebouwhoogte(woning)))
            entries.append(.init(naam: "BENG_GO.csv", data: csvGO(woning)))
            entries.append(.init(naam: "BENG_boilers.csv", data: csvBoilers(woning)))
        }
        if woning.toontPuntentelling {
            entries.append(.init(naam: "Puntentelling.csv", data: csvPuntentelling(woning)))
        }

        // 3. Foto's
        let fotosMap = ProjectStore.shared.fotosMap(voor: woning.id)
        if let bestanden = try? FileManager.default.contentsOfDirectory(at: fotosMap, includingPropertiesForKeys: nil) {
            for bestand in bestanden {
                if let data = try? Data(contentsOf: bestand) {
                    entries.append(.init(naam: "Fotos/\(bestand.lastPathComponent)", data: data))
                }
            }
        }

        // 4. 3D-modellen (LiDAR-scans, .usdz)
        let modellenMap = ProjectStore.shared.modellenMap(voor: woning.id)
        if let bestanden = try? FileManager.default.contentsOfDirectory(at: modellenMap, includingPropertiesForKeys: nil) {
            for bestand in bestanden {
                if let data = try? Data(contentsOf: bestand) {
                    entries.append(.init(naam: "3D-modellen/\(bestand.lastPathComponent)", data: data))
                }
            }
        }

        let exportNaam = "\(schoon(woning.naam.isEmpty ? "woning" : woning.naam))_\(datumStempel()).zip"
        let tijdelijkeMap = FileManager.default.temporaryDirectory
        let url = tijdelijkeMap.appendingPathComponent(exportNaam)
        try? FileManager.default.removeItem(at: url)
        try SimpleZip.schrijf(entries, naar: url)
        return url
    }

    private static func schoon(_ tekst: String) -> String {
        tekst.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
    }

    private static func datumStempel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    // MARK: - CSV per categorie

    private static func csvWanden(_ woning: Woning) -> Data {
        var rows: [[String]] = [[
            "Rekenzone", "Verdieping", "Geveldeel", "Type", "Grenst Aan", "Eigenschappen",
            "Overstek (Hoogteverschil/Afstand)", "Zonwering", "Hoogte (m)", "Breedte (m)", "Opp (m2)", "Oriëntatie", "Notities", "Foto"
        ]]
        for gevel in woning.gevels {
            rows.append([
                "", gevel.verdieping, gevel.geveldeelNaam, "Gevel", gevel.grenstAan.rawValue, gevel.eigenschappenLabel,
                "", "", getal(gevel.hoogteM), getal(gevel.breedteM), getal(gevel.oppM2), gevel.orientatie.rawValue,
                gevel.notities, gevel.fotoBestandsnaam ?? ""
            ])
            for opening in gevel.openingen {
                rows.append([
                    "", "", "", opening.type.rawValue, opening.grenstAan.rawValue, opening.eigenschappenKolomTekst,
                    opening.overstekKolomTekst ?? "", opening.zonweringType == .geen ? "" : opening.zonweringType.rawValue,
                    getal(opening.hoogteCm / 100.0), getal(opening.breedteCm / 100.0), getal(opening.oppM2),
                    opening.orientatie.rawValue, opening.notities, opening.fotoBestandsnaam ?? ""
                ])
            }
        }
        return csvData(rows)
    }

    private static func csvDaken(_ woning: Woning) -> Data {
        var rows: [[String]] = [[
            "Rekenzone", "Geveldeel", "Verdieping", "Type", "Helling (°)", "Eigenschappen",
            "Lengte (m)", "Breedte (m)", "Opp (m2)", "Oriëntatie", "Notities", "Foto"
        ]]
        for dak in woning.daken {
            rows.append([
                "", dak.geveldeelNaam, dak.verdieping, dak.typeKolomTekst, getal(dak.hellingGraden), dak.eigenschappenLabel,
                getal(dak.lengteM), getal(dak.breedteM), getal(dak.oppM2), dak.orientatie.rawValue, dak.notities, dak.fotoBestandsnaam ?? ""
            ])
        }
        return csvData(rows)
    }

    private static func csvVloeren(_ woning: Woning) -> Data {
        var rows: [[String]] = [[
            "Rekenzone", "Type", "Level", "Isolatie", "Rbw-waarde wanden", "Lengte (m)", "Breedte (m)", "Opp (m2)", "Perimeter (m1)", "Notities", "Foto"
        ]]
        for vloer in woning.vloeren {
            rows.append([
                "", "Vloer", vloer.level, vloer.isolatieLabel, vloer.rbwWaardeWandenLabel,
                getal(vloer.lengteM), getal(vloer.breedteM), getal(vloer.oppM2), getal(vloer.perimeterM), vloer.notities, vloer.fotoBestandsnaam ?? ""
            ])
        }
        return csvData(rows)
    }

    private static func csvGebouwhoogte(_ woning: Woning) -> Data {
        let rows: [[String]] = [
            ["Type", "Hoogte (mm)"],
            ["BIB_gebouwhoogte", woning.gebouwhoogteMm != nil ? getal(woning.gebouwhoogteMm!) : ""]
        ]
        return csvData(rows)
    }

    private static func csvGO(_ woning: Woning) -> Data {
        var rows: [[String]] = [["Rekenzone", "Type", "Level", "Opp (m2)"]]
        for entry in woning.gebruiksoppervlaktes {
            rows.append(["", "Vloer_GO", entry.level, getal(entry.oppM2)])
        }
        return csvData(rows)
    }

    private static func csvBoilers(_ woning: Woning) -> Data {
        var rows: [[String]] = [["Naam", "Categorie", "Verdieping", "afstand (m)", "afstand (horizontaal)", "afstand (verticaal)"]]
        for punt in woning.aftappunten {
            rows.append([
                punt.naam, punt.categorie ?? "", punt.verdieping,
                punt.afstandM.map(getal) ?? "", punt.afstandHorizontaalM.map(getal) ?? "", punt.afstandVerticaalM.map(getal) ?? ""
            ])
        }
        return csvData(rows)
    }

    /// Eén rij per ingevuld veld ("tidy" formaat: Ruimte, Veld, Waarde) zodat dit los van de precieze
    /// kolomindeling in Excel of op een website verder te verwerken is.
    private static func csvPuntentelling(_ woning: Woning) -> Data {
        var rows: [[String]] = [["Ruimte", "Veld", "Waarde"]]
        let p = woning.puntentelling

        func voegRuimteToe(_ naam: String, _ ruimte: PuntentellingRuimte) {
            rows.append([naam, "Aanwezig", jaNee(ruimte.aanwezig)])
            if ruimte.aanwezig {
                rows.append([naam, "Verwarmd", jaNee(ruimte.verwarmd)])
                rows.append([naam, "Aantal foto's", "\(ruimte.fotoBestandsnamen.count)"])
            }
        }

        voegRuimteToe("Woonkamer", p.woonkamer)
        voegRuimteToe("Woonkamer met open keuken", p.woonkamerMetOpenKeuken)

        rows.append(["Keuken", "Aanwezig", jaNee(p.keuken.aanwezig)])
        if p.keuken.aanwezig {
            let k = p.keuken
            rows.append(["Keuken", "Verwarmd", jaNee(k.verwarmd)])
            rows.append(["Keuken", "Lengte aanrechtblad (cm)", k.lengteAanrechtbladCm.map(getal) ?? ""])
            rows.append(["Keuken", "Totale breedte keukenkasten (cm)", k.totaleBreedteKeukenkastenCm.map(getal) ?? ""])
            rows.append(["Keuken", "Inbouw kookplaat", jaNee(k.inbouwKookplaat)])
            rows.append(["Keuken", "Inbouw oven", jaNee(k.inbouwOven)])
            rows.append(["Keuken", "Afzuigkap", jaNee(k.afzuigkap)])
            rows.append(["Keuken", "Inbouw magnetron", jaNee(k.inbouwMagnetron)])
            rows.append(["Keuken", "Inbouw koelkast", jaNee(k.inbouwKoelkast)])
            rows.append(["Keuken", "Inbouw vriezer", jaNee(k.inbouwVriezer)])
            rows.append(["Keuken", "Inbouw vaatwasser", jaNee(k.inbouwVaatwasser)])
            rows.append(["Keuken", "Kokend-waterkraan", jaNee(k.kokendWaterkraan)])
            rows.append(["Keuken", "Luxe mengkraan (aantal)", "\(k.luxeMengkranen)"])
            rows.append(["Keuken", "Thermostatische mengkraan (aantal)", "\(k.thermostatischeMengkranen)"])
            rows.append(["Keuken", "Aantal foto's", "\(k.fotoBestandsnamen.count)"])
        }

        rows.append(["Badkamer", "Aanwezig", jaNee(p.badkamer.aanwezig)])
        if p.badkamer.aanwezig {
            let b = p.badkamer
            rows.append(["Badkamer", "Verwarmd", jaNee(b.verwarmd)])
            rows.append(["Badkamer", "Aantal toiletten", "\(b.aantalToiletten)"])
            rows.append(["Badkamer", "Waarvan zwevende toiletten", "\(b.waarvanZwevendeToiletten)"])
            rows.append(["Badkamer", "Waarvan toiletten in badkamer", "\(b.waarvanToilettenInBadkamer)"])
            rows.append(["Badkamer", "Aantal wastafels", "\(b.aantalWastafels)"])
            rows.append(["Badkamer", "Meerpersoons wastafels (min. 70cm)", "\(b.aantalMeerpersoonsWastafels)"])
            rows.append(["Badkamer", "Douche/bad", b.doucheOfBad.rawValue])
            rows.append(["Badkamer", "Badkamermeubel met wastafel", jaNee(b.badkamermeubelMetWastafel)])
            rows.append(["Badkamer", "Bubbelbad (whirlpool)", jaNee(b.bubbelbad)])
            rows.append(["Badkamer", "Volledig gesloten doucheafscheiding", jaNee(b.volledigGeslotenDoucheafscheiding)])
            rows.append(["Badkamer", "Handdoekradiator", jaNee(b.handdoekradiator)])
            rows.append(["Badkamer", "Kastruimte (min. 40cm)", jaNee(b.kastruimte)])
            rows.append(["Badkamer", "Stopcontacten (aantal)", "\(b.stopcontacten)"])
            rows.append(["Badkamer", "Luxe mengkraan (aantal)", "\(b.luxeMengkranen)"])
            rows.append(["Badkamer", "Thermostatische mengkraan (aantal)", "\(b.thermostatischeMengkranen)"])
            rows.append(["Badkamer", "Aantal foto's", "\(b.fotoBestandsnamen.count)"])
        }

        voegRuimteToe("1e slaapkamer", p.slaapkamer1)
        voegRuimteToe("2e slaapkamer", p.slaapkamer2)
        voegRuimteToe("3e slaapkamer", p.slaapkamer3)
        voegRuimteToe("4e slaapkamer", p.slaapkamer4)
        voegRuimteToe("Serre", p.serre)
        voegRuimteToe("Zolderkamer", p.zolderkamer)

        rows.append(["Buitenruimte", "Oppervlakte (m2)", p.oppervlakteBuitenruimteM2.map(getal) ?? ""])

        return csvData(rows)
    }

    private static func jaNee(_ waarde: Bool) -> String {
        waarde ? "Ja" : "Nee"
    }

    private static func getal(_ waarde: Double) -> String {
        String(format: "%.2f", waarde)
    }

    private static func csvData(_ rows: [[String]]) -> Data {
        let tekst = rows.map { row in
            row.map { veld -> String in
                if veld.contains(",") || veld.contains("\"") || veld.contains("\n") {
                    return "\"\(veld.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return veld
            }.joined(separator: ",")
        }.joined(separator: "\r\n")
        return Data((tekst + "\r\n").utf8)
    }
}
