import XCTest
@testable import IntentCalendar

final class TemplateRuleNoteCodecTests: XCTestCase {
    func testEncodePreservesUserNotesAndRoundTripsRule() {
        let rule = TemplateBlockRule(
            isLocked: true,
            blockLabel: "Prayer",
            allowedActivities: ["Prayer"],
            planningHint: "Do not schedule over this block.",
            destinationCalendarID: "planning",
            minimumDurationMinutes: 15,
            maximumDurationMinutes: 30
        )

        let encoded = TemplateRuleNoteCodec.encode(
            rule: rule,
            existingNotes: "Keep this block sacred."
        )
        let decoded = TemplateRuleNoteCodec.decode(from: encoded)

        XCTAssertEqual(decoded.rule, rule)
        XCTAssertEqual(decoded.userNotes, "Keep this block sacred.")
        XCTAssertTrue(encoded.contains(AppConstants.Metadata.templateRuleStart))
        XCTAssertTrue(encoded.contains(AppConstants.Metadata.templateRuleEnd))
    }

    func testDecodeReturnsOriginalNotesWhenMetadataMissing() {
        let decoded = TemplateRuleNoteCodec.decode(from: "Plain notes only")

        XCTAssertNil(decoded.rule)
        XCTAssertEqual(decoded.userNotes, "Plain notes only")
    }

    func testDecodeDropsMalformedRuleButKeepsUserNotes() {
        let malformed = """
        Notes above.

        \(AppConstants.Metadata.templateRuleStart)
        {"isLocked":
        \(AppConstants.Metadata.templateRuleEnd)
        """

        let decoded = TemplateRuleNoteCodec.decode(from: malformed)

        XCTAssertNil(decoded.rule)
        XCTAssertEqual(decoded.userNotes, "Notes above.")
    }
}
