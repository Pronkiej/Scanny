import Foundation

/// Eén vloersegment, komt overeen met een rij in het "BENG_vloeren"-tabblad.
struct Vloer: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var level: String   // bv. "Begane grond"
    var isolatieLabel: String = ""            // gekozen uit ReferenceData.vloerIsolatie
    var rbwWaardeWandenLabel: String = ""      // isolatiewaarde van de aangrenzende kruipruimte-wanden
    var lengteM: Double
    var breedteM: Double
    var perimeterM: Double
    var notities: String = ""
    var fotoBestandsnaam: String?

    var oppM2: Double { lengteM * breedteM }
}

/// Eén rij in het "BENG_GO"-tabblad: het gebruiksoppervlak per verdieping.
struct GebruiksoppervlakEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var level: String
    var oppM2: Double
}

/// Eén rij in het "BENG_boilers"-tabblad: boiler + aftappunten met hun afstand (voor de leidinglengte tapwater).
struct Aftappunt: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var naam: String            // bv. "Boiler", "Bad", "Dubbele spoelbak"
    var categorie: String?      // bv. "Badkamer", "Keuken" - leeg voor de boiler zelf
    var verdieping: String
    var afstandM: Double?
    var afstandHorizontaalM: Double?
    var afstandVerticaalM: Double?
}

/// De introductie-checklist die aan het begin van een opname wordt gesteld (zolder/kelder-check).
struct IntroChecklist: Codable, Hashable {
    var heeftZolderOfVliering: Bool?
    var bovenGrenstAan: GrenstAanKeuze?   // "Grenst het plafond/dak in zijn geheel aan de buitenlucht of een andere verwarmde ruimte?"
    var heeftKelder: Bool?
    var onderGrenstAan: GrenstAanKeuze?   // "Grenst de vloer in zijn geheel aan de grond, kruipruimte of verwarmde ruimte?"
    var notities: String = ""

    /// Vertaalt het antwoord op de "boven"-vraag naar het bijbehorende resultaatveld.
    var bovenResultaat: String {
        switch bovenGrenstAan {
        case .buitenlucht: return "Buitenlucht"
        case .verwarmdeRuimte: return "AangrenzendeVerwarmdeRuimte"
        case .onverwarmdeRuimte: return "AangrenzendeOnverwarmdeRuimte"
        case .kruipruimte: return "Kruipruimte"
        case .grond: return "Grond"
        case .none: return ""
        }
    }

    var onderResultaat: String {
        switch onderGrenstAan {
        case .kruipruimte: return "Kruipruimte"
        case .grond: return "Grond"
        case .verwarmdeRuimte: return "AangrenzendeVerwarmdeRuimte"
        case .buitenlucht: return "Buitenlucht"
        case .onverwarmdeRuimte: return "AangrenzendeOnverwarmdeRuimte"
        case .none: return ""
        }
    }
}
