import Foundation

enum SharedPayloadStore {
    private static let defaults = UserDefaults(suiteName: AppConstants.appGroupID)

    static func consumeSharedText() -> String? {
        guard let text = defaults?.string(forKey: AppConstants.UserDefaultsKey.sharedContent) else {
            return nil
        }
        defaults?.removeObject(forKey: AppConstants.UserDefaultsKey.sharedContent)
        return text
    }

    static func sharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
    }

    static func audioURL(for filename: String) -> URL? {
        sharedContainerURL()?.appendingPathComponent(filename)
    }
}
