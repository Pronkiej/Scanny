import Foundation

/// Eén opname-project: een woning/gebouw met alle gescande gevels, daken, vloeren en overige gegevens.
/// Dit is de root die als los JSON-bestand wordt opgeslagen (zie Persistence/ProjectStore.swift)
/// en die 1-op-1 wordt omgezet naar het BENG-exportformaat (zie Export/BENGExporter.swift).
struct Woning: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var naam: String = ""          // bv. "Koopmans van Boekerenstraat 50"
    var adres: String = ""
    var opnameDatum: Date = Date()
    var gebruiker: String = ""     // gekoppeld aan de ingelogde gebruiker
    var verdiepingNamen: [String] = ["Begane grond"]

    /// Welke opname(s) dit project bevat - gekozen via vinkjes bij het aanmaken. Een leeg overzicht
    /// (oudere projecten van vóór deze functie) wordt behandeld als "Energielabel", zodat bestaande
    /// projecten precies blijven werken zoals voorheen.
    var projectTypes: Set<ProjectType> = []

    var introChecklist: IntroChecklist = IntroChecklist()
    var gevels: [Gevel] = []
    var daken: [Dak] = []
    var vloeren: [Vloer] = []
    var gebouwhoogteMm: Double?
    var gebruiksoppervlaktes: [GebruiksoppervlakEntry] = []
    var aftappunten: [Aftappunt] = []
    var kamerScans: [KamerScan] = []
    var puntentelling: Puntentelling = Puntentelling()

    var laatstGewijzigd: Date = Date()

    /// Totaal aantal gescande elementen, gebruikt als korte voortgangsindicatie in de projectenlijst.
    var aantalElementen: Int {
        gevels.count + daken.count + vloeren.count + gevels.reduce(0) { $0 + $1.openingen.count }
    }

    /// Of de Energielabel-opname (verdiepingen/gevels/daken/vloeren) getoond moet worden. Een leeg
    /// `projectTypes` (oudere projecten) telt hier ook mee, zodat niets verdwijnt voor bestaande opnames.
    var toontEnergielabel: Bool {
        projectTypes.contains(.energielabel) || projectTypes.isEmpty
    }

    /// Of het Puntentelling-onderdeel getoond moet worden - alleen als expliciet aangevinkt bij het aanmaken.
    var toontPuntentelling: Bool {
        projectTypes.contains(.puntentelling)
    }
}

/// Eén 3D-scan (LiDAR-meshscan met ARKit) van een verdieping: een doorlopende opname terwijl je door
/// de ruimte loopt, met eventueel een geëxporteerd .usdz 3D-model en de tijdens het scannen gemaakte
/// foto-notities (zie ScanNotitie) die je later kan toelichten - net als bij het scannen zelf.
struct KamerScan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var verdieping: String
    var naam: String = ""
    var modelBestandsnaam: String?         // 3D-model (.usdz) met de gekleurde mesh, zie ProjectStore.modellenMap
    var pointcloudBestandsnaam: String?    // losse puntenwolk (.usdz) van dezelfde scan, apart te bekijken
    var notities: [ScanNotitie] = []
    var meetlijnen: [Meetlijn] = []             // handmatig ingetekende afstanden in het 3D-model (bv. muur-tot-muur)
    var begrenzingslijnen: [Begrenzingslijn] = [] // handmatig ingetekende randen/begrenzingen in het 3D-model
    var duurSeconden: Int = 0
    var datum: Date = Date()
}

/// Eén foto-notitie: tijdens het scannen wordt alleen de foto vastgelegd (geen invoer, geen pop-up) -
/// type bouwdeel en bericht vul je pas later in, door de foto aan te tikken in het overzicht van de
/// 3D-viewer (zie Model3DViewerScherm). Een lege `type` betekent: nog niet ingevuld.
struct ScanNotitie: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: String = ""
    var bericht: String = ""
    var fotoBestandsnaam: String?
    var datum: Date = Date()
}

/// Eén punt in de lokale 3D-ruimte van een scan (meters, zelfde coördinatenstelsel als het opgeslagen
/// .usdz-bestand van die scan).
struct Punt3D: Codable, Hashable {
    var x: Double
    var y: Double
    var z: Double
}

/// Eén ingetekende afstand tussen twee punten in het 3D-model (bv. muur-tot-muur), met de afstand die
/// uit het model zelf is berekend en een eventueel later bevestigde/gecorrigeerde afstand - handmatig
/// ingevoerd na het zelf opmeten, bijvoorbeeld met een rolmaat of een bluetooth-laserafstandsmeter.
struct Meetlijn: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var naam: String = ""
    var start: Punt3D
    var eind: Punt3D
    var berekendeAfstandM: Double
    var bevestigdeAfstandM: Double?
}

/// Eén ingetekende begrenzingslijn (bv. de rand van een muur, vloer of ander bouwdeel) in het 3D-model,
/// opgebouwd uit een reeks aangetikte punten.
struct Begrenzingslijn: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var naam: String = ""
    var punten: [Punt3D] = []
}

/// Alle gegevens voor de puntentelling (Woningwaarderingsstelsel): per ruimte of deze aanwezig en
/// verwarmd is, plus de losse kwaliteitspunten voor keuken en badkamer, en de oppervlakte buitenruimte.
struct Puntentelling: Codable, Hashable {
    var woonkamer: PuntentellingRuimte = PuntentellingRuimte()
    var woonkamerMetOpenKeuken: PuntentellingRuimte = PuntentellingRuimte()
    var keuken: PuntentellingKeuken = PuntentellingKeuken()
    var badkamer: PuntentellingBadkamer = PuntentellingBadkamer()
    var slaapkamer1: PuntentellingRuimte = PuntentellingRuimte()
    var slaapkamer2: PuntentellingRuimte = PuntentellingRuimte()
    var slaapkamer3: PuntentellingRuimte = PuntentellingRuimte()
    var slaapkamer4: PuntentellingRuimte = PuntentellingRuimte()
    var serre: PuntentellingRuimte = PuntentellingRuimte()
    var zolderkamer: PuntentellingRuimte = PuntentellingRuimte()
    var oppervlakteBuitenruimteM2: Double?
}

/// Een simpele ruimte in de puntentelling (woonkamer, slaapkamer, serre, zolderkamer): alleen aanwezig
/// en verwarmd of niet, plus eventueel één of meer foto's van de ruimte.
struct PuntentellingRuimte: Codable, Hashable {
    var aanwezig: Bool = false
    var verwarmd: Bool = false
    var fotoBestandsnamen: [String] = []
}

/// Puntentelling-gegevens van de keuken: naast aanwezig/verwarmd ook de kwaliteitspunten voor
/// aanrecht, inbouwapparatuur en kranen.
struct PuntentellingKeuken: Codable, Hashable {
    var aanwezig: Bool = false
    var verwarmd: Bool = false
    var lengteAanrechtbladCm: Double?
    var inbouwKookplaat: Bool = false
    var inbouwOven: Bool = false
    var afzuigkap: Bool = false
    var inbouwMagnetron: Bool = false
    var inbouwKoelkast: Bool = false
    var inbouwVriezer: Bool = false
    var inbouwVaatwasser: Bool = false
    var luxeMengkranen: Int = 0
    var thermostatischeMengkranen: Int = 0
    var totaleBreedteKeukenkastenCm: Double?
    var kokendWaterkraan: Bool = false
    var fotoBestandsnamen: [String] = []
}

/// Puntentelling-gegevens van de badkamer: naast aanwezig/verwarmd ook de kwaliteitspunten voor
/// sanitair, kranen en overige voorzieningen.
struct PuntentellingBadkamer: Codable, Hashable {
    var aanwezig: Bool = false
    var verwarmd: Bool = false
    var aantalToiletten: Int = 0
    var waarvanZwevendeToiletten: Int = 0
    var waarvanToilettenInBadkamer: Int = 0
    var aantalWastafels: Int = 0
    var aantalMeerpersoonsWastafels: Int = 0   // min. 70 cm breed
    var doucheOfBad: DoucheOfBad = .douche
    var badkamermeubelMetWastafel: Bool = false
    var bubbelbad: Bool = false
    var volledigGeslotenDoucheafscheiding: Bool = false
    var luxeMengkranen: Int = 0
    var thermostatischeMengkranen: Int = 0
    var handdoekradiator: Bool = false
    var stopcontacten: Int = 0
    var kastruimte: Bool = false   // min. 40 cm breed en hoog
    var fotoBestandsnamen: [String] = []
}
