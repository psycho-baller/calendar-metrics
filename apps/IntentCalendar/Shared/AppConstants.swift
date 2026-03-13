import Foundation

enum AppConstants {
    static let appGroupID = "group.studio.orbitlabs.intentcalendar"
    static let urlScheme = "intentcalendar"
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-intentcalendar-ui-testing")

    enum UserDefaultsKey {
        static let sharedContent = "shared_content"
        static let selectedTemplateCalendarID = "selectedTemplateCalendarID"
        static let selectedPlanningCalendarID = "selectedPlanningCalendarID"
        static let selectedConstraintCalendarIDs = "selectedConstraintCalendarIDs"
        static let plannerModel = "plannerModel"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let vaultBookmark = "vaultBookmark"
        static let selectedDateContextWindow = "selectedDateContextWindow"
    }

    enum Metadata {
        static let templateRuleStart = "[IntentCalendarRule]"
        static let templateRuleEnd = "[/IntentCalendarRule]"
        static let plannedEventStart = "[IntentCalendarPlannedEvent]"
        static let plannedEventEnd = "[/IntentCalendarPlannedEvent]"
    }
}
