import UIKit

/// Genereert een overzichtelijk PDF-rapport van de puntentelling (Woningwaarderingsstelsel):
/// per ruimte de status (aanwezig/verwarmd) en alle ingevulde kwaliteitspunten, met - waar aanwezig -
/// de eerste foto van die ruimte. Bedoeld als leesbaar rapport naast de Puntentelling.csv (zie
/// DataExporter), die bedoeld is om verder te verwerken.
enum PuntentellingPDFExporter {
    private static let paginaBreedte: CGFloat = 595.2   // A4 @ 72dpi
    private static let paginaHoogte: CGFloat = 841.8

    @MainActor
    static func exporteer(_ woning: Woning) throws -> URL {
        let bounds = CGRect(x: 0, y: 0, width: paginaBreedte, height: paginaHoogte)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let naam = woning.naam.isEmpty ? "Naamloos project" : woning.naam
        let datum = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let p = woning.puntentelling

        let data = renderer.pdfData { context in
            var cursor = PDFCursor(context: context, bounds: bounds)
            cursor.nieuwePagina()
            cursor.tekenTitel("Puntentelling")
            cursor.tekenSubtitel(naam)
            if !woning.adres.isEmpty { cursor.tekenSubtitel(woning.adres) }
            cursor.tekenSubtitel("Gegenereerd op \(datum)")
            cursor.spatie(10)

            cursor.tekenRuimte("Woonkamer", ruimte: p.woonkamer, woningId: woning.id)
            cursor.tekenRuimte("Woonkamer met open keuken", ruimte: p.woonkamerMetOpenKeuken, woningId: woning.id)
            cursor.tekenKeuken(p.keuken, woningId: woning.id)
            cursor.tekenBadkamer(p.badkamer, woningId: woning.id)
            cursor.tekenRuimte("1e slaapkamer", ruimte: p.slaapkamer1, woningId: woning.id)
            cursor.tekenRuimte("2e slaapkamer", ruimte: p.slaapkamer2, woningId: woning.id)
            cursor.tekenRuimte("3e slaapkamer", ruimte: p.slaapkamer3, woningId: woning.id)
            cursor.tekenRuimte("4e slaapkamer", ruimte: p.slaapkamer4, woningId: woning.id)
            cursor.tekenRuimte("Serre", ruimte: p.serre, woningId: woning.id)
            cursor.tekenRuimte("Zolderkamer", ruimte: p.zolderkamer, woningId: woning.id)

            cursor.tekenSectieKop("Buitenruimte")
            if let opp = p.oppervlakteBuitenruimteM2 {
                cursor.tekenRij("Oppervlakte", String(format: "%.1f m²", opp))
            } else {
                cursor.tekenRij("Oppervlakte", "-")
            }
        }

        let exportNaam = "Puntentelling_\(schoon(naam))_\(datumStempel()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(exportNaam)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url)
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
}

/// Houdt de teken-cursor (huidige y-positie) bij tijdens het opbouwen van het PDF en breekt
/// automatisch naar een nieuwe pagina zodra de inhoud niet meer past.
@MainActor
private struct PDFCursor {
    let context: UIGraphicsPDFRendererContext
    let bounds: CGRect
    let marge: CGFloat = 36
    var y: CGFloat = 36

    init(context: UIGraphicsPDFRendererContext, bounds: CGRect) {
        self.context = context
        self.bounds = bounds
    }

    mutating func nieuwePagina() {
        context.beginPage()
        y = marge
    }

    mutating func zorgVoorRuimte(_ hoogte: CGFloat) {
        if y + hoogte > bounds.height - marge {
            nieuwePagina()
        }
    }

    mutating func spatie(_ hoogte: CGFloat) { y += hoogte }

    mutating func tekenTitel(_ tekst: String) {
        zorgVoorRuimte(30)
        (tekst as NSString).draw(at: CGPoint(x: marge, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.black,
        ])
        y += 30
    }

    mutating func tekenSubtitel(_ tekst: String) {
        zorgVoorRuimte(16)
        (tekst as NSString).draw(at: CGPoint(x: marge, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray,
        ])
        y += 16
    }

    mutating func tekenSectieKop(_ tekst: String) {
        zorgVoorRuimte(34)
        y += 8
        (tekst as NSString).draw(at: CGPoint(x: marge, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: UIColor.black,
        ])
        y += 18
        context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
        context.cgContext.setLineWidth(0.5)
        context.cgContext.move(to: CGPoint(x: marge, y: y))
        context.cgContext.addLine(to: CGPoint(x: bounds.width - marge, y: y))
        context.cgContext.strokePath()
        y += 8
    }

    mutating func tekenRij(_ label: String, _ waarde: String) {
        zorgVoorRuimte(16)
        (label as NSString).draw(at: CGPoint(x: marge + 8, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray,
        ])
        (waarde as NSString).draw(at: CGPoint(x: marge + 240, y: y), withAttributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.black,
        ])
        y += 15
    }

    mutating func tekenFoto(_ image: UIImage) {
        let maxBreedte: CGFloat = 140
        guard image.size.width > 0 else { return }
        let schaal = maxBreedte / image.size.width
        let hoogte = image.size.height * schaal
        zorgVoorRuimte(hoogte + 8)
        image.draw(in: CGRect(x: marge + 8, y: y, width: maxBreedte, height: hoogte))
        y += hoogte + 8
    }

    mutating func tekenRuimte(_ titel: String, ruimte: PuntentellingRuimte, woningId: UUID) {
        tekenSectieKop(titel)
        tekenRij("Aanwezig", jaNee(ruimte.aanwezig))
        guard ruimte.aanwezig else { return }
        tekenRij("Verwarmd", jaNee(ruimte.verwarmd))
        if let eersteFoto = ruimte.fotoBestandsnamen.first,
           let image = ProjectStore.shared.laadFoto(bestandsnaam: eersteFoto, woningId: woningId) {
            tekenFoto(image)
        }
    }

    mutating func tekenKeuken(_ keuken: PuntentellingKeuken, woningId: UUID) {
        tekenSectieKop("Keuken")
        tekenRij("Aanwezig", jaNee(keuken.aanwezig))
        guard keuken.aanwezig else { return }
        tekenRij("Verwarmd", jaNee(keuken.verwarmd))
        tekenRij("Lengte aanrechtblad", keuken.lengteAanrechtbladCm.map { "\(getal($0)) cm" } ?? "-")
        tekenRij("Totale breedte keukenkasten", keuken.totaleBreedteKeukenkastenCm.map { "\(getal($0)) cm" } ?? "-")
        tekenRij("Inbouw kookplaat", jaNee(keuken.inbouwKookplaat))
        tekenRij("Inbouw oven", jaNee(keuken.inbouwOven))
        tekenRij("Afzuigkap", jaNee(keuken.afzuigkap))
        tekenRij("Inbouw magnetron", jaNee(keuken.inbouwMagnetron))
        tekenRij("Inbouw koelkast", jaNee(keuken.inbouwKoelkast))
        tekenRij("Inbouw vriezer", jaNee(keuken.inbouwVriezer))
        tekenRij("Inbouw vaatwasser", jaNee(keuken.inbouwVaatwasser))
        tekenRij("Kokend-waterkraan", jaNee(keuken.kokendWaterkraan))
        tekenRij("Luxe mengkraan", "\(keuken.luxeMengkranen)")
        tekenRij("Thermostatische mengkraan", "\(keuken.thermostatischeMengkranen)")
        if let eersteFoto = keuken.fotoBestandsnamen.first,
           let image = ProjectStore.shared.laadFoto(bestandsnaam: eersteFoto, woningId: woningId) {
            tekenFoto(image)
        }
    }

    mutating func tekenBadkamer(_ badkamer: PuntentellingBadkamer, woningId: UUID) {
        tekenSectieKop("Badkamer")
        tekenRij("Aanwezig", jaNee(badkamer.aanwezig))
        guard badkamer.aanwezig else { return }
        tekenRij("Verwarmd", jaNee(badkamer.verwarmd))
        tekenRij("Aantal toiletten", "\(badkamer.aantalToiletten)")
        tekenRij("Waarvan zwevende toiletten", "\(badkamer.waarvanZwevendeToiletten)")
        tekenRij("Waarvan toiletten in badkamer", "\(badkamer.waarvanToilettenInBadkamer)")
        tekenRij("Aantal wastafels", "\(badkamer.aantalWastafels)")
        tekenRij("Meerpersoons wastafels (min. 70 cm)", "\(badkamer.aantalMeerpersoonsWastafels)")
        tekenRij("Douche/bad", badkamer.doucheOfBad.rawValue)
        tekenRij("Badkamermeubel met wastafel", jaNee(badkamer.badkamermeubelMetWastafel))
        tekenRij("Bubbelbad (whirlpool)", jaNee(badkamer.bubbelbad))
        tekenRij("Volledig gesloten doucheafscheiding", jaNee(badkamer.volledigGeslotenDoucheafscheiding))
        tekenRij("Handdoekradiator", jaNee(badkamer.handdoekradiator))
        tekenRij("Kastruimte (min. 40 cm)", jaNee(badkamer.kastruimte))
        tekenRij("Stopcontacten", "\(badkamer.stopcontacten)")
        tekenRij("Luxe mengkraan", "\(badkamer.luxeMengkranen)")
        tekenRij("Thermostatische mengkraan", "\(badkamer.thermostatischeMengkranen)")
        if let eersteFoto = badkamer.fotoBestandsnamen.first,
           let image = ProjectStore.shared.laadFoto(bestandsnaam: eersteFoto, woningId: woningId) {
            tekenFoto(image)
        }
    }

    private func jaNee(_ waarde: Bool) -> String { waarde ? "Ja" : "Nee" }
    private func getal(_ waarde: Double) -> String { String(format: "%.1f", waarde) }
}
