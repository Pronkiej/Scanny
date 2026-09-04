import Foundation

/// Exporteert een Woning-opname als één .zip met daarin:
/// - woning.json (volledige data, 1-op-1 herbruikbaar / later te verwerken)
/// - CSV-bestanden per categorie (gemakkelijk te openen in Excel), met een kolomindeling die al dicht
///   tegen het benodigde Vabi-importformaat aan zit zodat latere fine-tuning naar het exacte format
///   weinig werk is
/// - de gemaakte foto's, met bestandsnamen die corresponderen met de "foto"-kolom in de CSV's
enum DataExporter {
    static func exporteer(_ woning: Woning) throws -> URL {
        var entries: [SimpleZip.Entry] = []

        // 1. Volledige data als JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(woning)
        entries.append(.init(naam: "woning.json", data: jsonData))

        // 2. CSV's per categorie
        entries.append(.init(naam: "BENG_wanden_en_wandopeningen.csv", data: csvWanden(woning)))
        entries.append(.init(naam: "BENG_daken.csv", data: csvDaken(woning)))
        entries.append(.init(naam: "BENG_vloeren.csv", data: csvVloeren(woning)))
        entries.append(.init(naam: "BENG_gebouwhoogte.csv", data: csvGebouwhoogte(woning)))
        entries.append(.init(naam: "BENG_GO.csv", data: csvGO(woning)))
        entries.append(.init(naam: "BENG_boilers.csv", data: csvBoilers(woning)))

        // 3. Foto's
        let fotosMap = ProjectStore.shared.fotosMap(voor: woning.id)
        if let bestanden = try? FileManager.default.contentsOfDirectory(at: fotosMap, includingPropertiesForKeys: nil) {
            for bestand in bestanden {
                if let data = try? Data(contentsOf: bestand) {
                    entries.append(.init(naam: "Fotos/\(bestand.lastPathComponent)", data: data))
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
