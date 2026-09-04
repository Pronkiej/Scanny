import Foundation
import CoreLocation
import Combine

/// Leest het kompas van het toestel uit en zet dit om naar de dichtstbijzijnde 8-punts oriëntatie
/// (N/NO/O/ZO/Z/ZW/W/NW), zodat je tijdens het scannen niet zelf handmatig de windrichting per gevel
/// hoeft te bepalen. Vereist locatietoestemming ("When In Use") vanwege Apple's koppeling van
/// kompas-API's aan Core Location.
@MainActor
final class CompassHeading: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = CompassHeading()

    @Published private(set) var huidigeGraden: Double = 0
    @Published private(set) var huidigeOrientatie: Orientatie = .noord
    @Published private(set) var beschikbaar: Bool = CLLocationManager.headingAvailable()

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func start() {
        guard beschikbaar else { return }
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingHeading()
    }

    func stop() {
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let graden = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.huidigeGraden = graden
            self.huidigeOrientatie = Orientatie.vanGraden(graden)
        }
    }
}
