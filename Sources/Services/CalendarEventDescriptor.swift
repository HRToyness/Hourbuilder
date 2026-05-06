import Foundation

/// Value-type weergave van een agenda-event. Bewust losgekoppeld van EventKit
/// zodat de mapping- en import-logica getest kan worden zonder een echte
/// `EKEventStore`.
public struct CalendarEventDescriptor: Sendable, Hashable, Identifiable {
    public var id: String {
        if let occurrenceDate {
            return "\(eventIdentifier ?? "no-id")_\(occurrenceDate.timeIntervalSince1970)"
        }
        return eventIdentifier ?? "\(startDate.timeIntervalSince1970)_\(title ?? "")"
    }

    public let eventIdentifier: String?
    public let occurrenceDate: Date?
    public let title: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let isCancelled: Bool
    public let attendeeEmails: [String]
    public let calendarTitle: String?

    public init(
        eventIdentifier: String?,
        occurrenceDate: Date?,
        title: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isCancelled: Bool,
        attendeeEmails: [String],
        calendarTitle: String?
    ) {
        self.eventIdentifier = eventIdentifier
        self.occurrenceDate = occurrenceDate
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.isCancelled = isCancelled
        self.attendeeEmails = attendeeEmails
        self.calendarTitle = calendarTitle
    }

    public var durationHours: Double {
        max(0, endDate.timeIntervalSince(startDate) / 3600.0)
    }

    /// Stabiele dedupe sleutel die ook recurring events onderscheidt.
    public var dedupReference: String? {
        guard let eventIdentifier else { return nil }
        if let occurrenceDate {
            return "\(eventIdentifier)_\(Int(occurrenceDate.timeIntervalSince1970))"
        }
        return eventIdentifier
    }
}

public struct CalendarDescriptor: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let allowsModifications: Bool

    public init(id: String, title: String, allowsModifications: Bool) {
        self.id = id
        self.title = title
        self.allowsModifications = allowsModifications
    }
}

public enum CalendarAccessState: Sendable, Equatable {
    case notDetermined
    case granted
    case writeOnly
    case denied
    case restricted
}

public struct CalendarEventQuery: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let calendarIds: [String]?
    public let titleContains: String?

    public init(
        startDate: Date,
        endDate: Date,
        calendarIds: [String]? = nil,
        titleContains: String? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.calendarIds = calendarIds
        self.titleContains = titleContains
    }
}

public protocol CalendarServiceProtocol: Sendable {
    var currentAccess: CalendarAccessState { get }
    func requestAccess() async throws -> Bool
    func availableCalendars() -> [CalendarDescriptor]
    func fetchEvents(query: CalendarEventQuery) -> [CalendarEventDescriptor]
}
