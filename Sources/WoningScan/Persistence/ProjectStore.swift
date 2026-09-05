import Foundation
import UIKit

/// Beheert het opslaan/laden van Woning-projecten en hun foto's op het toestel zelf.
/// Elke woning wordt weggeschreven als `<id>.json` in Documents/Projecten, met bijbehorende
/// foto's in Documents/Projecten/<id>/Fotos. Geen netwerk of account nodig - alles blijft lokaal
/// op de telefoon totdat je zelf exporteert (zie Export/).
@MainActor
final class ProjectStore: ObservableObject {
    static let shared = ProjectStore()

    @Published private(set) var projecten: [Woning] = []

    private let fm = FileManager.default

    private var projectenMap: URL {
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Projecten", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        laadAlleProjecten()
    }

    func map(voor woningId: UUID) -> URL {
        let dir = projectenMap.appendingPathComponent(woningId.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func fotosMap(voor woningId: UUID) -> URL {
        let dir = map(voor: woningId).appendingPathComponent("Fotos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Map met de opgeslagen .usdz 3D-modellen en puntenwolken (LiDAR-scans) van een project.
    func modellenMap(voor woningId: UUID) -> URL {
        let dir = map(voor: woningId).appendingPathComponent("Modellen", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func laadAlleProjecten() {
        guard let items = try? fm.contentsOfDirectory(at: projectenMap, includingPropertiesForKeys: nil) else {
            projecten = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var geladen: [Woning] = []
        for item in items where item.pathExtension == "json" {
            if let data = try? Data(contentsOf: item),
               let woning = try? decoder.decode(Woning.self, from: data) {
                geladen.append(woning)
            }
        }
        projecten = geladen.sorted { $0.laatstGewijzigd > $1.laatstGewijzigd }
    }

    func opslaan(_ woning: Woning) {
        var bijgewerkt = woning
        bijgewerkt.laatstGewijzigd = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(bijgewerkt) else { return }
        let url = projectenMap.appendingPathComponent("\(bijgewerkt.id.uuidString).json")
        try? data.write(to: url, options: .atomic)
        if let idx = projecten.firstIndex(where: { $0.id == bijgewerkt.id }) {
            projecten[idx] = bijgewerkt
        } else {
            projecten.append(bijgewerkt)
        }
        projecten.sort { $0.laatstGewijzigd > $1.laatstGewijzigd }
    }

    func verwijder(_ woning: Woning) {
        let url = projectenMap.appendingPathComponent("\(woning.id.uuidString).json")
        try? fm.removeItem(at: url)
        try? fm.removeItem(at: map(voor: woning.id))
        projecten.removeAll { $0.id == woning.id }
    }

    /// Slaat een foto op bij een project en geeft de relatieve bestandsnaam terug om in het model op te slaan.
    func slaFotoOp(_ image: UIImage, voor woningId: UUID) -> String? {
        let bestandsnaam = "\(UUID().uuidString).jpg"
        let url = fotosMap(voor: woningId).appendingPathComponent(bestandsnaam)
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return bestandsnaam
        } catch {
            return nil
        }
    }

    func laadFoto(bestandsnaam: String?, woningId: UUID) -> UIImage? {
        guard let bestandsnaam else { return nil }
        let url = fotosMap(voor: woningId).appendingPathComponent(bestandsnaam)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Verplaatst een geëxporteerd .usdz-bestand (3D-model of puntenwolk, van een LiDAR-scan in de
    /// tijdelijke map) naar de permanente opslag van een project en geeft de relatieve bestandsnaam terug.
    func slaModelOp(vanaf tijdelijkeUrl: URL, voor woningId: UUID) -> String? {
        let bestandsnaam = "\(UUID().uuidString).usdz"
        let url = modellenMap(voor: woningId).appendingPathComponent(bestandsnaam)
        do {
            try? fm.removeItem(at: url)
            try fm.moveItem(at: tijdelijkeUrl, to: url)
            return bestandsnaam
        } catch {
            return nil
        }
    }

    func modelUrl(bestandsnaam: String, woningId: UUID) -> URL {
        modellenMap(voor: woningId).appendingPathComponent(bestandsnaam)
    }

    func verwijderModel(bestandsnaam: String, woningId: UUID) {
        try? fm.removeItem(at: modelUrl(bestandsnaam: bestandsnaam, woningId: woningId))
    }
}
