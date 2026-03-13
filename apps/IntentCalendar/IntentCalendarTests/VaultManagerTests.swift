import XCTest
@testable import IntentCalendar

final class VaultManagerTests: XCTestCase {
    func testFetchDailyNotesContextLoadsRequestedDayAndRecentHistory() throws {
        let suiteName = "IntentCalendarTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let manager = VaultManager(defaults: defaults)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suiteName)
        }

        try """
        # Today
        Plan the launch.
        """.write(to: root.appendingPathComponent("2026-03-12.md"), atomically: true, encoding: .utf8)
        try """
        # Yesterday
        Wrapped the planner.
        """.write(to: root.appendingPathComponent("2026-03-11.md"), atomically: true, encoding: .utf8)
        try """
        # Earlier
        Captured errands.
        """.write(to: root.appendingPathComponent("2026-03-10.md"), atomically: true, encoding: .utf8)
        try "Ignore me".write(to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        manager.vaultURL = root
        manager.isVaultConfigured = true

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!
        let notes = try manager.fetchDailyNotesContext(for: date, count: 2)

        XCTAssertEqual(notes.map { $0.url.lastPathComponent }, ["2026-03-12.md", "2026-03-11.md", "2026-03-10.md"])
        XCTAssertTrue(notes.first?.content.contains("Plan the launch.") == true)
    }
}
