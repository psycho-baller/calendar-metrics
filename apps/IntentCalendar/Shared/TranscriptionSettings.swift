import Foundation
import os

enum TranscriptionModel: String, CaseIterable, Codable, Identifiable {
    case tiny = "openai_whisper-tiny.en"
    case base = "openai_whisper-base.en"
    case small = "openai_whisper-small.en"
    case medium = "openai_whisper-medium"
    case largeV3 = "distil-whisper_distil-large-v3_turbo"
    case cloudMini = "gpt-4o-mini-transcribe"
    case cloudBest = "gpt-4o-transcribe"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (English)"
        case .base: return "Base (English)"
        case .small: return "Small (English)"
        case .medium: return "Medium (English)"
        case .largeV3: return "Large v3 (Best)"
        case .cloudMini: return "Cloud mini"
        case .cloudBest: return "Cloud best"
        }
    }

    var isCloud: Bool {
        self == .cloudMini || self == .cloudBest
    }

    var sizeDescription: String {
        switch self {
        case .tiny: return "~39 MB"
        case .base: return "~74 MB"
        case .small: return "~244 MB"
        case .medium: return "~769 MB"
        case .largeV3: return "~626 MB"
        case .cloudMini, .cloudBest: return "Uses API"
        }
    }

    var accuracyDescription: String {
        switch self {
        case .tiny: return "Basic"
        case .base: return "Good"
        case .small: return "Better"
        case .medium: return "High"
        case .largeV3: return "Excellent"
        case .cloudMini: return "Fast"
        case .cloudBest: return "Best"
        }
    }

    var cloudAPIModel: String? {
        switch self {
        case .cloudMini, .cloudBest:
            return rawValue
        default:
            return nil
        }
    }
}

class TranscriptionSettings: ObservableObject {
    static let shared = TranscriptionSettings()

    private let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private static let modelKey = "selectedTranscriptionModel"

    @Published var selectedModel: TranscriptionModel {
        didSet {
            saveModel()
        }
    }

    private init() {
        if let savedRawValue = defaults?.string(forKey: Self.modelKey),
           let model = TranscriptionModel(rawValue: savedRawValue) {
            selectedModel = model
            Logger.transcription.info("Restored transcription model: \(model.displayName)")
        } else {
            selectedModel = .cloudMini
            Logger.transcription.info("Using default transcription model: Cloud mini")
        }
    }

    private func saveModel() {
        defaults?.set(selectedModel.rawValue, forKey: Self.modelKey)
        Logger.transcription.info("Saved transcription model: \(self.selectedModel.displayName)")
    }
}
