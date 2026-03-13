import Combine
import XCTest
@testable import IntentCalendar

@MainActor
final class IntentCalendarAppModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testModelPublishesWhenSettingsStoreChanges() {
        let suiteName = "IntentCalendarAppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let settingsStore = AppSettingsStore(defaults: defaults)
        let model = IntentCalendarAppModel(
            draftManager: DraftManager(),
            transcriberService: TranscriberService(),
            vaultManager: VaultManager(),
            settingsStore: settingsStore
        )

        let expectation = expectation(description: "Model forwards settings changes")
        model.objectWillChange
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        settingsStore.hasCompletedOnboarding = true

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(model.configuration.hasCompletedOnboarding)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
