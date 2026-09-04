import Foundation

/// Eén rij uit de bewerkbare isolatie-catalogus (EigenschappenCatalogus.json).
struct IsolatieOptie: Codable, Identifiable, Hashable {
    var label: String
    var rc: Double?
    var u: Double?
    var spouw: Bool?
    var dikteMm: Int?
    var materiaal: String?
    var bron: String?

    var id: String { label }
}

/// Laadt en houdt de bewerkbare "Eigenschappen"-catalogus bij (isolatiewaarden per bouwdeeltype).
/// De catalogus zelf staat in Resources/EigenschappenCatalogus.json - pas dat bestand aan
/// om de lijst te laten aansluiten op de exacte opties die jullie Vabi-installatie gebruikt.
@MainActor
final class ReferenceData: ObservableObject {
    static let shared = ReferenceData()

    @Published private(set) var wandIsolatie: [IsolatieOptie] = []
    @Published private(set) var dakIsolatie: [IsolatieOptie] = []
    @Published private(set) var vloerIsolatie: [IsolatieOptie] = []
    @Published private(set) var deurIsolatie: [IsolatieOptie] = []
    @Published private(set) var paneelIsolatie: [IsolatieOptie] = []

    private init() {
        load()
    }

    /// Herlaadt de catalogus, bv. na het overschrijven van het JSON-bestand vanaf een eigen server later.
    func load() {
        guard let url = Bundle.main.url(forResource: "EigenschappenCatalogus", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("EigenschappenCatalogus.json ontbreekt in de app bundle")
            return
        }
        do {
            let decoded = try JSONDecoder().decode(Catalogus.self, from: data)
            wandIsolatie = decoded.wandIsolatie
            dakIsolatie = decoded.dakIsolatie
            vloerIsolatie = decoded.vloerIsolatie
            deurIsolatie = decoded.deurIsolatie
            paneelIsolatie = decoded.paneelIsolatie
        } catch {
            assertionFailure("Kon EigenschappenCatalogus.json niet lezen: \(error)")
        }
    }

    private struct Catalogus: Codable {
        var wandIsolatie: [IsolatieOptie]
        var dakIsolatie: [IsolatieOptie]
        var vloerIsolatie: [IsolatieOptie]
        var deurIsolatie: [IsolatieOptie]
        var paneelIsolatie: [IsolatieOptie]
    }
}
