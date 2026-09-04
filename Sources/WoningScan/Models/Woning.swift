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

    var laatstGewijzigd: Date = Date()

    /// Totaal aantal gescande elementen, gebruikt als korte voortgangsindicatie in de projectenlijst.
    var aantalElementen: Int {
        gevels.count + daken.count + vloeren.count + gevels.reduce(0) { $0 + $1.openingen.count }
    }
}
