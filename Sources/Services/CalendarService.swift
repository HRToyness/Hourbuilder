import Foundation
import os
#if canImport(EventKit)
import EventKit

private let log = Logger(subsystem: "nl.toynessit.urenreconstructie", category: "calendar")

/// EventKit-gebaseerde implementatie. Tests gebruiken een stub die alleen aan
/// `CalendarServiceProtocol` voldoet.
public final class CalendarService: CalendarServiceProtocol, @unchecked Sendable {
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public var currentAccess: CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .writeOnly: return .writeOnly
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    public func requestAccess() async throws -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            log.error("calendar requestAccess threw: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func availableCalendars() -> [CalendarDescriptor] {
        store.calendars(for: .event)
            .map { cal in
                CalendarDescriptor(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    allowsModifications: cal.allowsContentModifications
                )
            }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }

    public func fetchEvents(query: CalendarEventQuery) -> [CalendarEventDescriptor] {
        let calendars: [EKCalendar]?
        if let ids = query.calendarIds {
            let idSet = Set(ids)
            calendars = store.calendars(for: .event).filter { idSet.contains($0.calendarIdentifier) }
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(
            withStart: query.startDate,
            end: query.endDate,
            calendars: calendars
        )

        var events = store.events(matching: predicate)
        if let needle = query.titleContains?.lowercased(), !needle.isEmpty {
            events = events.filter { ($0.title ?? "").lowercased().contains(needle) }
        }
        events.sort { $0.startDate < $1.startDate }

        return events.map { ev in
            let attendees = (ev.attendees ?? []).compactMap { participant -> String? in
                let raw = participant.url.absoluteString
                if raw.lowercased().hasPrefix("mailto:") {
                    return String(raw.dropFirst("mailto:".count))
                }
                return raw
            }
            return CalendarEventDescriptor(
                eventIdentifier: ev.eventIdentifier,
                occurrenceDate: ev.occurrenceDate,
                title: ev.title,
                startDate: ev.startDate,
                endDate: ev.endDate,
                isAllDay: ev.isAllDay,
                isCancelled: ev.status == .canceled,
                attendeeEmails: attendees,
                calendarTitle: ev.calendar?.title
            )
        }
    }
}
#endif
