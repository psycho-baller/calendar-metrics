//
//  IntentionalityModels.swift
//  Intent
//
//  Created by Codex on 2026-05-11.
//

import Foundation
import UIKit

struct IntentConfiguration: Codable, Equatable {
    var backendBaseURL = ""
    var setupKey = ""
    var deviceName = UIDevice.current.name
    var deviceId = ""
    var deviceSecret = ""
    var windowDays = 30

    var isPaired: Bool {
        !backendBaseURL.isEmpty && !deviceId.isEmpty && !deviceSecret.isEmpty
    }

    static let storageKey = "intent.ios.configuration"

    static func load() -> IntentConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(IntentConfiguration.self, from: data)
        else {
            return IntentConfiguration()
        }

        return decoded
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct IntentBootstrapRequest: Encodable {
    let setupKey: String
    let deviceName: String
    let platform: String
    let settings: IntentBootstrapSettings
}

struct IntentBootstrapSettings: Encodable {
    let autoStartFocus: Bool
    let autoCompleteFocus: Bool
    let autoShowReview: Bool
    let bundleId: String
}

struct IntentBootstrapResponse: Decodable {
    let ok: Bool
    let device: IntentRegisteredDevice
}

struct IntentRegisteredDevice: Decodable {
    let deviceId: String
    let deviceSecret: String
    let isDefault: Bool
}

struct IntentionalityRecordResponse: Decodable {
    let ok: Bool
}

struct IntentionalitySnapshot: Decodable, Equatable {
    let generatedAt: Int
    let windowDays: Int
    let timeZoneOffsetMinutes: Int
    let totalEntries: Int
    let averageScore: Double
    let todayAverage: Double?
    let yesterdayAverage: Double?
    let deltaFromYesterday: Double?
    let last24Average: Double?
    let currentHourScore: Double?
    let currentStreakDays: Int
    let responseRate7d: Double
    let bestHourOfDay: IntentionalityBestHour?
    let recentEntries: [IntentionalityEntry]
    let dailyAverages: [IntentionalityDailyAverage]
    let hourlyAverages: [IntentionalityHourlyAverage]
    let lastRecordedAt: Int?
    let lastUpdatedAt: Int?
}

struct IntentionalityEntry: Decodable, Equatable, Identifiable {
    let id: String
    let hourStartMs: Int
    let score: Double
    let dayKey: String
    let hour: Int
    let hourLabel: String
    let source: String
    let updatedAt: Int

    var date: Date {
        Date(timeIntervalSince1970: Double(hourStartMs) / 1000)
    }
}

struct IntentionalityDailyAverage: Decodable, Equatable, Identifiable {
    let id: String
    let dayKey: String
    let dayStartMs: Int
    let average: Double
    let count: Int

    var date: Date {
        Date(timeIntervalSince1970: Double(dayStartMs) / 1000)
    }
}

struct IntentionalityHourlyAverage: Decodable, Equatable, Identifiable {
    let id: String
    let hour: Int
    let label: String
    let average: Double?
    let count: Int
}

struct IntentionalityBestHour: Decodable, Equatable {
    let id: String
    let hour: Int
    let label: String
    let average: Double
    let count: Int
}
