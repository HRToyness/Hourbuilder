import XCTest
@testable import Services
@testable import Models

final class EventMappingServiceTests: XCTestCase {
    private let mapping = EventMappingService()

    private func descriptor(
        title: String? = "Sprint planning",
        start: Date = Date(timeIntervalSince1970: 1_700_000_000),
        durationHours: Double = 1,
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        attendees: [String] = [],
        identifier: String? = "evt-1",
        occurrence: Date? = nil
    ) -> CalendarEventDescriptor {
        CalendarEventDescriptor(
            eventIdentifier: identifier,
            occurrenceDate: occurrence,
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(durationHours * 3600),
            isAllDay: isAllDay,
            isCancelled: isCancelled,
            attendeeEmails: attendees,
            calendarTitle: "Werk"
        )
    }

    func testSkipReasonAllDay() {
        XCTAssertEqual(mapping.skipReason(for: descriptor(isAllDay: true)), .allDay)
    }

    func testSkipReasonCancelled() {
        XCTAssertEqual(mapping.skipReason(for: descriptor(isCancelled: true)), .cancelled)
    }

    func testSkipReasonZeroDuration() {
        XCTAssertEqual(mapping.skipReason(for: descriptor(durationHours: 0)), .zeroDuration)
    }

    func testSkipReasonValidEventReturnsNil() {
        XCTAssertNil(mapping.skipReason(for: descriptor(durationHours: 1)))
    }

    func testMatchPersoonByExactEmail() {
        let alice = Persoon(naam: "Alice", rol: "Dev", type: .intern, email: "alice@acme.nl")
        let bob = Persoon(naam: "Bob", rol: "PM", type: .klant, email: "bob@klant.com")

        let descriptor = descriptor(attendees: ["bob@klant.com"])
        XCTAssertEqual(
            mapping.matchPersoon(in: descriptor, from: [alice, bob])?.id,
            bob.id
        )
    }

    func testMatchPersoonCaseInsensitive() {
        let alice = Persoon(naam: "Alice", rol: "Dev", type: .intern, email: "alice@acme.nl")
        let descriptor = descriptor(attendees: ["ALICE@ACME.NL"])
        XCTAssertEqual(
            mapping.matchPersoon(in: descriptor, from: [alice])?.id,
            alice.id
        )
    }

    func testMatchPersoonNoMatchReturnsNil() {
        let alice = Persoon(naam: "Alice", rol: "Dev", type: .intern, email: "alice@acme.nl")
        let descriptor = descriptor(attendees: ["unknown@elsewhere.com"])
        XCTAssertNil(mapping.matchPersoon(in: descriptor, from: [alice]))
    }

    func testMatchPersoonDoesNotCrashOnDuplicateEmails() {
        // Twee personen met dezelfde email mag niet crashen — Dictionary
        // moet uniqueKeysWithValues *niet* gebruiken.
        let aliceA = Persoon(naam: "Alice (intern)", rol: "Dev", type: .intern, email: "alice@acme.nl")
        let aliceB = Persoon(naam: "Alice (klant)", rol: "PM", type: .klant, email: "alice@acme.nl")
        let descriptor = descriptor(attendees: ["alice@acme.nl"])
        let match = mapping.matchPersoon(in: descriptor, from: [aliceA, aliceB])
        // Eerste match wint — implementatie-detail, maar moet stabiel zijn.
        XCTAssertEqual(match?.id, aliceA.id)
    }

    func testMapDescriptorProducesConceptAgendaActivity() {
        let projectId = UUID()
        let persoonId = UUID()
        let event = descriptor(durationHours: 2)
        let activity = mapping.map(
            descriptor: event,
            projectId: projectId,
            persoonId: persoonId
        )
        XCTAssertEqual(activity.projectId, projectId)
        XCTAssertEqual(activity.persoonId, persoonId)
        XCTAssertEqual(activity.uren, 2, accuracy: 0.001)
        XCTAssertEqual(activity.bron, .agenda)
        XCTAssertEqual(activity.status, .concept)
        XCTAssertEqual(activity.bronReferentie, "evt-1")
        XCTAssertTrue(activity.beschrijving.contains("Sprint"))
        XCTAssertTrue(activity.bewijs?.contains("Werk") ?? false)
    }

    func testDedupReferenceUniquePerOccurrence() {
        let baseStart = Date(timeIntervalSince1970: 1_700_000_000)
        let occ1 = baseStart.addingTimeInterval(86400)
        let occ2 = baseStart.addingTimeInterval(86400 * 2)

        let d1 = descriptor(start: baseStart, identifier: "rec-1", occurrence: occ1)
        let d2 = descriptor(start: baseStart, identifier: "rec-1", occurrence: occ2)
        XCTAssertNotEqual(d1.dedupReference, d2.dedupReference)
    }
}
