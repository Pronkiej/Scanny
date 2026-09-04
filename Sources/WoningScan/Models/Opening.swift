import Foundation

/// Eén raam, deur of paneel-in-kozijn binnen een geveldeel.
/// Veldnamen zijn afgestemd op de kolommen die per kozijn worden bijgehouden:
/// hoogte_cm, breedte_cm, glas, kozijn, is_overstek, afstand_cm, hoogteverschil_cm,
/// zonweringtype, zonwering_kleur, zonwering_regeling, zonwering_ggl_alt/diff, construction_type.
struct Opening: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: OpeningType
    var grenstAan: AangrenzendeRuimte = .buitenlucht
    var orientatie: Orientatie

    // Glas/kozijn (alleen relevant voor Raam en Paneel in kozijn)
    var glas: GlasType?
    var kozijnMateriaal: KozijnMateriaal?

    /// Isolatielabel voor een Deur, gekozen uit ReferenceData.deurIsolatie (bv. "ongeïsoleerd (U = 3.40)").
    /// Voor Raam/Paneel wordt de eigenschappentekst afgeleid van `glas` + `kozijnMateriaal` (zie `eigenschappenKolomTekst`).
    var deurIsolatieLabel: String?

    // Afmetingen
    var breedteCm: Double
    var hoogteCm: Double

    // Overstek (zonwerend effect van bv. een dakoverstek boven het kozijn)
    var isOverstek: Bool = false
    var overstekHoogteverschilCm: Double?
    var overstekAfstandCm: Double?

    // Zonwering
    var zonweringType: ZonweringType = .geen
    var zonweringKleur: String?
    var zonweringRegeling: ZonweringRegeling = .geen
    var zonweringGglAlt: Double = 0
    var zonweringGglDiff: Double = 0

    var notities: String = ""
    var fotoBestandsnaam: String?

    var oppM2: Double {
        (breedteCm / 100.0) * (hoogteCm / 100.0)
    }

    /// De "Overstek (Hoogteverschil/Afstand)"-kolomtekst zoals in het BENG-exportformaat, bv. "1.26m / 0.68m".
    var overstekKolomTekst: String? {
        guard isOverstek, let h = overstekHoogteverschilCm, let a = overstekAfstandCm else { return nil }
        return String(format: "%.2fm / %.2fm", h / 100.0, a / 100.0)
    }

    /// De "Eigenschappen"-kolomtekst voor deze opening, zoals in het BENG-exportformaat.
    var eigenschappenKolomTekst: String {
        switch type {
        case .raam, .paneelInKozijn:
            guard let glas else { return "" }
            let materiaal = kozijnMateriaal?.rawValue ?? KozijnMateriaal.onbekend.rawValue
            if glas == .geenGlas {
                return "\(materiaal)"
            }
            return "\(glas.rawValue) (\(materiaal), U = \(String(format: "%.2f", glas.standaardUWaarde)), g = \(String(format: "%.2f", glas.standaardGWaarde)))"
        case .deur:
            return deurIsolatieLabel ?? ""
        }
    }
}
