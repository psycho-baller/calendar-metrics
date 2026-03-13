import Foundation
import SwiftUI

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var configuration: IntentCalendarConfiguration {
        didSet {
            persistConfiguration()
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard) {
        self.defaults = defaults
        self.configuration = IntentCalendarConfiguration(
            hasCompletedOnboarding: defaults.bool(forKey: AppConstants.UserDefaultsKey.hasCompletedOnboarding),
            selectedTemplateCalendarID: defaults.string(forKey: AppConstants.UserDefaultsKey.selectedTemplateCalendarID),
            selectedPlanningCalendarID: defaults.string(forKey: AppConstants.UserDefaultsKey.selectedPlanningCalendarID),
            selectedConstraintCalendarIDs: defaults.stringArray(forKey: AppConstants.UserDefaultsKey.selectedConstraintCalendarIDs) ?? [],
            plannerModel: PlannerModel(rawValue: defaults.string(forKey: AppConstants.UserDefaultsKey.plannerModel) ?? "") ?? .gpt41Mini,
            selectedDateContextWindow: defaults.object(forKey: AppConstants.UserDefaultsKey.selectedDateContextWindow) as? Int ?? 2
        )
    }

    var hasCompletedOnboarding: Bool {
        get { configuration.hasCompletedOnboarding }
        set { configuration.hasCompletedOnboarding = newValue }
    }

    var selectedTemplateCalendarID: String? {
        get { configuration.selectedTemplateCalendarID }
        set { configuration.selectedTemplateCalendarID = newValue }
    }

    var selectedPlanningCalendarID: String? {
        get { configuration.selectedPlanningCalendarID }
        set { configuration.selectedPlanningCalendarID = newValue }
    }

    var selectedConstraintCalendarIDs: [String] {
        get { configuration.selectedConstraintCalendarIDs }
        set { configuration.selectedConstraintCalendarIDs = newValue.sorted() }
    }

    var plannerModel: PlannerModel {
        get { configuration.plannerModel }
        set { configuration.plannerModel = newValue }
    }

    var selectedDateContextWindow: Int {
        get { configuration.selectedDateContextWindow }
        set { configuration.selectedDateContextWindow = max(0, min(newValue, 7)) }
    }

    private func persistConfiguration() {
        defaults.set(configuration.hasCompletedOnboarding, forKey: AppConstants.UserDefaultsKey.hasCompletedOnboarding)
        defaults.set(configuration.selectedTemplateCalendarID, forKey: AppConstants.UserDefaultsKey.selectedTemplateCalendarID)
        defaults.set(configuration.selectedPlanningCalendarID, forKey: AppConstants.UserDefaultsKey.selectedPlanningCalendarID)
        defaults.set(configuration.selectedConstraintCalendarIDs, forKey: AppConstants.UserDefaultsKey.selectedConstraintCalendarIDs)
        defaults.set(configuration.plannerModel.rawValue, forKey: AppConstants.UserDefaultsKey.plannerModel)
        defaults.set(configuration.selectedDateContextWindow, forKey: AppConstants.UserDefaultsKey.selectedDateContextWindow)
    }
}
