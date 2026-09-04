import Foundation

/// 8-punts kompasoriëntatie, exact zoals gebruikt in het BENG/Vabi-exportformaat.
enum Orientatie: String, CaseIterable, Codable, Identifiable {
    case noord = "N"
    case noordoost = "NO"
    case oost = "O"
    case zuidoost = "ZO"
    case zuid = "Z"
    case zuidwest = "ZW"
    case west = "W"
    case noordwest = "NW"

    var id: String { rawValue }

    var volledigeNaam: String {
        switch self {
        case .noord: return "Noord"
        case .noordoost: return "Noordoost"
        case .oost: return "Oost"
        case .zuidoost: return "Zuidoost"
        case .zuid: return "Zuid"
        case .zuidwest: return "Zuidwest"
        case .west: return "West"
        case .noordwest: return "Noordwest"
        }
    }

    /// Zet een kompasrichting in graden (0-360, 0 = noord) om naar de dichtstbijzijnde 8-punts oriëntatie.
    static func vanGraden(_ graden: Double) -> Orientatie {
        let normalized = graden.truncatingRemainder(dividingBy: 360)
        let positive = normalized < 0 ? normalized + 360 : normalized
        let index = Int((positive / 45.0).rounded()) % 8
        return Orientatie.allCases[index]
    }
}

/// Het type aangrenzende ruimte voor een gevel/dak/vloer-element.
/// Namen zijn 1-op-1 overgenomen uit het Vabi-exportformaat ("Grenst Aan" kolom).
enum AangrenzendeRuimte: String, CaseIterable, Codable, Identifiable {
    case buitenlucht = "Buitenlucht"
    case kruipruimte = "Kruipruimte"
    case grond = "Grond"
    case aangrenzendeOnverwarmdeRuimte = "AangrenzendeOnverwarmdeRuimte"
    case aangrenzendeVerwarmdeRuimte = "AangrenzendeVerwarmdeRuimte"

    var id: String { rawValue }

    /// Leesbare Nederlandse tekst voor gebruik in de UI (bv. checklist-vragen).
    var weergaveNaam: String {
        switch self {
        case .buitenlucht: return "Buitenlucht"
        case .kruipruimte: return "Kruipruimte"
        case .grond: return "Grond"
        case .aangrenzendeOnverwarmdeRuimte: return "Aangrenzende onverwarmde ruimte"
        case .aangrenzendeVerwarmdeRuimte: return "Aangrenzende verwarmde ruimte"
        }
    }
}

/// Het type bouwdeel-vlak: gevel (wand), (schuin/plat) dak, of vloer.
enum VlakType: String, CaseIterable, Codable, Identifiable {
    case gevel = "Gevel"
    case schuinDak = "Schuin-dak"
    case platDak = "Plat-dak"
    case vloer = "Vloer"

    var id: String { rawValue }
}

/// Het type opening in een gevel/dak.
enum OpeningType: String, CaseIterable, Codable, Identifiable {
    case raam = "Raam"
    case deur = "Deur"
    case paneelInKozijn = "Paneel in kozijn"

    var id: String { rawValue }
}

/// Kozijnmateriaal, zoals gebruikt in de glas/kozijn-eigenschappen ("Hout of kunststof", etc).
enum KozijnMateriaal: String, CaseIterable, Codable, Identifiable {
    case houtOfKunststof = "Hout of kunststof"
    case aluminium = "Aluminium"
    case staal = "Staal"
    case onbekend = "Onbekend"

    var id: String { rawValue }
}

/// Glastype voor een raam/paneel, met bijbehorende U- en g-waarde.
enum GlasType: String, CaseIterable, Codable, Identifiable {
    case enkelGlas = "Enkel glas"
    case dubbelGlas = "Dubbel glas"
    case hrGlas = "HR-glas"
    case hrPlusGlas = "HR+-glas"
    case hrPlusPlusGlas = "HR++-glas"
    case tripleGlas = "Triple glas / HR+++"
    case geenGlas = "Geen glas (paneel)"

    var id: String { rawValue }

    /// Standaard U-waarde (W/m²K) en g-waarde (zontoetredingsfactor) per glastype,
    /// gebaseerd op de gangbare ISSO/NTA 8800 kentallen voor bestaande bouw zonder kwaliteitsverklaring.
    /// Pas deze aan (of vul aan) in ReferenceData.swift als jullie eigen Vabi-installatie afwijkende waarden gebruikt.
    var standaardUWaarde: Double {
        switch self {
        case .enkelGlas: return 5.10
        case .dubbelGlas: return 2.90
        case .hrGlas: return 1.80
        case .hrPlusGlas: return 1.20
        case .hrPlusPlusGlas: return 1.00
        case .tripleGlas: return 0.70
        case .geenGlas: return 0.0
        }
    }

    var standaardGWaarde: Double {
        switch self {
        case .enkelGlas: return 0.85
        case .dubbelGlas: return 0.75
        case .hrGlas: return 0.65
        case .hrPlusGlas: return 0.60
        case .hrPlusPlusGlas: return 0.50
        case .tripleGlas: return 0.45
        case .geenGlas: return 0.0
        }
    }
}

/// Zonwering-type voor een opening.
enum ZonweringType: String, CaseIterable, Codable, Identifiable {
    case geen = "NONE"
    case buitenzonwering = "Buitenzonwering"
    case screen = "Screen"
    case rolluik = "Rolluik"
    case binnenzonwering = "Binnenzonwering"

    var id: String { rawValue }
}

/// Zonwering-bediening (regeling).
enum ZonweringRegeling: String, CaseIterable, Codable, Identifiable {
    case geen = "NONE"
    case handmatig = "Handmatig"
    case automatischTemperatuurgestuurd = "Automatisch (temperatuurgestuurd)"
    case automatischZongestuurd = "Automatisch (zongestuurd)"

    var id: String { rawValue }
}

/// Vraag/antwoord-resultaat voor de intro-checklist (boven/onder).
enum GrenstAanKeuze: String, CaseIterable, Codable, Identifiable {
    case buitenlucht = "Buitenlucht"
    case kruipruimte = "Kruipruimte"
    case verwarmdeRuimte = "Verwarmde ruimte"
    case onverwarmdeRuimte = "Onverwarmde ruimte"
    case grond = "Grond"

    var id: String { rawValue }
}
