import XCTest
@testable import IntentCalendar

final class PlannerResponseTests: XCTestCase {
    func testPlannerEnvelopeDecodesPlanResponse() throws {
        let json = """
        {
          "response": {
            "outcome": "plan",
            "summary": "Your day is fully planned.",
            "questions": [],
            "plannedBlocks": [
              {
                "id": "block-1",
                "title": "Deep work",
                "windowID": "focus",
                "startLocalTime": "09:00",
                "endLocalTime": "10:30",
                "detail": "Finish the scheduling flow.",
                "rationale": "This is the highest-value work."
              }
            ]
          }
        }
        """

        let envelope = try JSONDecoder().decode(PlannerEnvelope.self, from: Data(json.utf8))

        XCTAssertEqual(envelope.response.outcome, .plan)
        XCTAssertEqual(envelope.response.plannedBlocks.first?.windowID, "focus")
    }

    func testPlannerEnvelopeRejectsIncompletePayload() {
        let json = """
        {
          "response": {
            "outcome": "questions",
            "summary": "Need one more detail."
          }
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(PlannerEnvelope.self, from: Data(json.utf8))
        )
    }
}
