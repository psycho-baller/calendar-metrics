import EventKit
import Foundation

@MainActor
final class CalendarPermissionsManager: ObservableObject {
    enum AccessState: Equatable {
        case notDetermined
        case denied
        case writeOnly
        case fullAccess
        case restricted

        var title: String {
            switch self {
            case .notDetermined:
                return "Not requested"
            case .denied:
                return "Denied"
            case .writeOnly:
                return "Write only"
            case .fullAccess:
                return "Full access"
            case .restricted:
                return "Restricted"
            }
        }
    }

    @Published private(set) var accessState: AccessState = .notDetermined

    init() {
        refresh()
    }

    func refresh() {
        if #available(iOS 17.0, macOS 14.0, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .notDetermined:
                accessState = .notDetermined
            case .fullAccess:
                accessState = .fullAccess
            case .writeOnly:
                accessState = .writeOnly
            case .denied:
                accessState = .denied
            case .restricted:
                accessState = .restricted
            @unknown default:
                accessState = .restricted
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .notDetermined:
                accessState = .notDetermined
            case .authorized:
                accessState = .fullAccess
            case .fullAccess:
                accessState = .fullAccess
            case .writeOnly:
                accessState = .writeOnly
            case .denied:
                accessState = .denied
            case .restricted:
                accessState = .restricted
            @unknown default:
                accessState = .restricted
            }
        }
    }

    func requestAccess(using eventStore: EKEventStore) async throws -> Bool {
        let granted: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { accessGranted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: accessGranted)
                    }
                }
            }
        }

        refresh()
        return granted
    }
}
