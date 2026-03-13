import AVFoundation
import SwiftUI

class PermissionsManager: ObservableObject {
    @Published var microphonePermission: PermissionStatus = .notDetermined

    enum PermissionStatus {
        case notDetermined
        case denied
        case authorized
    }

    init() {
        checkMicrophonePermission()
    }

    func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                microphonePermission = .notDetermined
            case .denied:
                microphonePermission = .denied
            case .granted:
                microphonePermission = .authorized
            @unknown default:
                microphonePermission = .notDetermined
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .undetermined:
                microphonePermission = .notDetermined
            case .denied:
                microphonePermission = .denied
            case .granted:
                microphonePermission = .authorized
            @unknown default:
                microphonePermission = .notDetermined
            }
        }
    }

    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermission = granted ? .authorized : .denied
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.microphonePermission = granted ? .authorized : .denied
                }
            }
        }
    }
}
