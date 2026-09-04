import Foundation

/// Eén dakvlak (schuin of plat), komt overeen met een rij in het "BENG_daken"-tabblad.
struct Dak: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var geveldeelNaam: String   // bv. "1"
    var verdieping: String
    var vlakType: VlakType = .schuinDak   // .schuinDak of .platDak
    var grenstAan: AangrenzendeRuimte = .buitenlucht
    var hellingGraden: Double = 0
    var eigenschappenLabel: String = ""   // gekozen uit ReferenceData.dakIsolatie
    var lengteM: Double
    var breedteM: Double
    var orientatie: Orientatie
    var notities: String = ""
    var fotoBestandsnaam: String?

    var oppM2: Double { lengteM * breedteM }

    /// Combinatiestring voor de "Type"-kolom in de BENG-export, bv. "Schuin-dak_-_AangrenzendeOnverwarmdeRuimte".
    var typeKolomTekst: String {
        "\(vlakType.rawValue)_-_\(grenstAan.rawValue)"
    }
}
