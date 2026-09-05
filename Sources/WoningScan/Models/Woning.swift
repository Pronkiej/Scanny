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

    var introChecklist: IntroChecklist = IntroChecklist()
    var gevels: [Gevel] = []
    var daken: [Dak] = []
    var vloeren: [Vloer] = []
    var gebouwhoogteMm: Double?
    var gebruiksoppervlaktes: [GebruiksoppervlakEntry] = []
    var aftappunten: [Aftappunt] = []
    var kamerScans: [KamerScan] = []

    var laatstGewijzigd: Date = Date()

    /// Totaal aantal gescande elementen, gebruikt als korte voortgangsindicatie in de projectenlijst.
    var aantalElementen: Int {
        gevels.count + daken.count + vloeren.count + gevels.reduce(0) { $0 + $1.openingen.count }
    }
}

/// Eén 3D-scan (LiDAR-meshscan met ARKit) van een verdieping: een doorlopende opname terwijl je door
/// de ruimte loopt. Een LiDAR-scan levert twee dingen op die je allebei apart kan bekijken: een
/// puntenwolk (de losse datapunten die ARKit in de ruimte meet, vóórdat ze tot een oppervlak worden
/// verbonden) en een 3D-model (dezelfde punten, maar dan verbonden tot een gekleurde mesh die het
/// uiterlijk van de wanden/vloer/plafond nabootst) - plus de tijdens het scannen gemaakte foto-notities
/// (zie ScanNotitie) die je later kan toelichten.
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

/// Eén foto-notitie, gemaakt tijdens het 3D-scannen door op de foto-knop te drukken: legt vast wát
/// (type bouwdeel) en waarom (bericht), zodat je 'm later kan toelichten bij het verwerken van de opname.
struct ScanNotitie: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: String = "Gevel"
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
