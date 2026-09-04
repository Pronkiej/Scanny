import Foundation

/// Eén geveldeel (wandsegment), met de ramen/deuren/panelen die erin zitten.
/// Komt overeen met een groep rijen in het "BENG_wanden en wandopeningen"-tabblad:
/// de eerste rij is de gevel zelf (Type = Gevel), gevolgd door de openingen in die gevel.
struct Gevel: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var geveldeelNaam: String   // bv. "D : 01"
    var verdieping: String      // bv. "Begane grond"
    var grenstAan: AangrenzendeRuimte = .buitenlucht
    var eigenschappenLabel: String = ""   // gekozen uit ReferenceData.wandIsolatie
    var hoogteM: Double
    var breedteM: Double
    var orientatie: Orientatie
    var notities: String = ""
    var fotoBestandsnaam: String?
    var openingen: [Opening] = []

    var oppM2: Double { hoogteM * breedteM }

    var nettoOppM2: Double {
        max(0, oppM2 - openingen.reduce(0) { $0 + $1.oppM2 })
    }
}
