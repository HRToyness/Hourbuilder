import Foundation
@testable import Services

/// In-memory stub voor `CalendarServiceProtocol` zodat tests niet aan
/// EventKit hoeven te tikken.
public final class StubCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    public var stubAccess: CalendarAccessState = .granted
    public var stubCalendars: [CalendarDescriptor] = []
    public var stubEvents: [CalendarEventDescriptor] = []
    public var receivedQueries: [CalendarEventQuery] = []

    public init() {}

    public var currentAccess: CalendarAccessState { stubAccess }

    public func requestAccess() async throws -> Bool {
        stubAccess = .granted
        return true
    }

    public func availableCalendars() -> [CalendarDescriptor] {
        stubCalendars
    }

    public func fetchEvents(query: CalendarEventQuery) -> [CalendarEventDescriptor] {
        receivedQueries.append(query)
        return stubEvents.filter { ev in
            ev.startDate >= query.startDate && ev.startDate <= query.endDate
        }
    }
}
