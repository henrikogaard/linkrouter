import AppKit
import Combine
import CoreLocation
import CoreWLAN
import Darwin
import Foundation
import SystemConfiguration

@MainActor
final class NetworkContext: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = NetworkContext()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var wifiSSID: String?

    private let locationManager: CLLocationManager

    private override init() {
        locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        refresh()
    }

    var locationAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    func refresh() {
        authorizationStatus = locationManager.authorizationStatus
        refreshWiFiSSID()
    }

    func requestLocationAccess() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                NSWorkspace.shared.open(settingsURL)
            }
        default:
            refreshWiFiSSID()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        refreshWiFiSSID()
    }

    nonisolated static func isVPN(primaryInterface: String?, activeIPv4Interfaces: [String]) -> Bool {
        let primaryPrefixes = ["utun", "ipsec", "ppp", "tun", "tap", "wg"]
        if let primaryInterface, primaryPrefixes.contains(where: primaryInterface.hasPrefix) {
            return true
        }
        let activePrefixes = ["utun", "ipsec", "ppp"]
        return activeIPv4Interfaces.contains { name in
            activePrefixes.contains(where: name.hasPrefix)
        }
    }

    nonisolated static func currentVPNConnected() -> Bool {
        let store = SCDynamicStoreCreate(nil, "LinkRouter" as CFString, nil, nil)
        let globalIPv4 = store.flatMap {
            SCDynamicStoreCopyValue($0, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        }
        let primaryInterface = globalIPv4?["PrimaryInterface"] as? String

        var activeIPv4Interfaces: [String] = []
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&firstAddress) == 0, let firstAddress {
            defer { freeifaddrs(firstAddress) }
            var address = Optional(firstAddress)
            while let current = address {
                if let socketAddress = current.pointee.ifa_addr,
                   socketAddress.pointee.sa_family == sa_family_t(AF_INET),
                   let name = current.pointee.ifa_name {
                    activeIPv4Interfaces.append(String(cString: name))
                }
                address = current.pointee.ifa_next
            }
        }

        return isVPN(primaryInterface: primaryInterface, activeIPv4Interfaces: activeIPv4Interfaces)
    }

    private func refreshWiFiSSID() {
        guard locationAuthorized else {
            wifiSSID = nil
            return
        }
        wifiSSID = CWWiFiClient.shared().interface()?.ssid()
    }
}

enum FocusModeStore {
    static let defaultsKey = "LinkRouterFocusMode"

    static func current(defaults: UserDefaults = .standard) -> String? {
        guard let value = defaults.string(forKey: defaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    static func set(_ mode: String?, defaults: UserDefaults = .standard) {
        let value = mode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(value, forKey: defaultsKey)
        }
    }
}
