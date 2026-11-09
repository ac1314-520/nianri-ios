import Foundation
import CoreLocation
import Combine

final class CurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var error: String?
    @Published var requestInFlight = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        requestInFlight = true
        error = nil
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            requestInFlight = false
            error = "定位权限被关闭了。可以到设置里允许，或手动搜索区县。"
        } else {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if requestInFlight { manager.requestLocation() }
        case .denied, .restricted:
            requestInFlight = false
            error = "定位权限被关闭了。可以到设置里允许，或手动搜索区县。"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        requestInFlight = false
        guard let last = locations.last else {
            error = "暂时拿不到当前位置，手动搜索区县也可以。"
            return
        }
        location = last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        requestInFlight = false
        self.error = "定位失败：\(error.localizedDescription)"
    }
}
