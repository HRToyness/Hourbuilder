---
name: eventkit-calendar-import
description: How to read events from Apple Calendar via EventKit and turn them into Activiteit records. Read before working on calendar imports, permission flows, person-by-email matching, or anything involving EventKit. Covers the macOS 14+ permission model, predicates, calendar selection, and de-duplication on re-import.
---

# EventKit Calendar Import

EventKit gives the app access to local Apple Calendar data without OAuth. This is one of the main reasons we built native instead of web. macOS 14+ has stricter permissions than older versions — handle the flow correctly or your import silently returns nothing.

## Info.plist requirements

Add the usage description, otherwise macOS throws on first access:

```xml
<key>NSCalendarsUsageDescription</key>
<string>UrenReconstructie leest agenda-afspraken om je urenregistratie te reconstrueren. Data blijft lokaal op je Mac.</string>
```

The string is shown to the user verbatim in the permission prompt. Keep it honest and reassuring — it's the user's first impression of the privacy story.

## Permission flow (macOS 14+)

In macOS 14, Apple split calendar access into "write-only" and "full". You need **full access** to read events.

```swift
// Services/CalendarService.swift
import EventKit

final class CalendarService {
    private let store = EKEventStore()

    enum AccessState {
        case granted, denied, notDetermined, restricted
    }

    var currentAccess: AccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .writeOnly: return .denied  // we need read, treat as denied
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }
}
```

Always check `currentAccess` before requesting — `requestFullAccessToEvents` only prompts on first call. After denial, the user must go to System Settings → Privacy & Security → Calendars to re-enable. Surface that path clearly in the UI when access is denied.

## Listing available calendars

```swift
extension CalendarService {
    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
            .filter { $0.allowsContentModifications || true } // include read-only calendars too
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
}
```

Include all calendars, not just writable ones — the user might want to import from a shared work calendar that's read-only.

## Fetching events

EventKit uses predicates. Date range is required; calendars and search are optional but recommended.

```swift
extension CalendarService {
    struct EventQuery {
        let startDate: Date
        let endDate: Date
        let calendars: [EKCalendar]?  // nil = all
        let titleContains: String?    // case-insensitive substring filter
    }

    func fetchEvents(_ query: EventQuery) -> [EKEvent] {
        let predicate = store.predicateForEvents(
            withStart: query.startDate,
            end: query.endDate,
            calendars: query.calendars
        )
        var events = store.events(matching: predicate)

        if let needle = query.titleContains?.lowercased(), !needle.isEmpty {
            events = events.filter { ($0.title ?? "").lowercased().contains(needle) }
        }

        return events.sorted { $0.startDate < $1.startDate }
    }
}
```

`store.events(matching:)` is synchronous and can be slow for large windows — fine for a wizard flow on a background task, not fine for tight UI loops. Wrap calls in `Task.detached(priority: .userInitiated)` if needed.

## Mapping to Activiteit

Events become **proposed** activities, not confirmed ones. Status is `.concept` until the user reviews.

```swift
struct EventMappingService {
    let anonymizationService: AnonymizationService  // for sanitizing titles before storage
    let personLookup: (String) -> Persoon?  // resolve email to known Persoon

    func map(event: EKEvent, projectId: UUID, faseId: UUID?) -> Activiteit {
        let durationHours = event.endDate.timeIntervalSince(event.startDate) / 3600.0

        // Try to match a person by attendee email
        let attendeeEmails = (event.attendees ?? []).compactMap { $0.url.absoluteString
            .replacingOccurrences(of: "mailto:", with: "")
        }
        let matchedPerson = attendeeEmails.lazy.compactMap { personLookup($0) }.first

        // Sanitize title — never store free-text identifiers carelessly
        let sanitizedTitle = anonymizationService.sanitize(event.title ?? "Onbekend")

        return Activiteit(
            id: UUID(),
            projectId: projectId,
            faseId: faseId,
            persoonId: matchedPerson?.id ?? UUID(),  // or nil — see note
            datum: event.startDate,
            uren: durationHours,
            beschrijving: sanitizedTitle,
            bron: .agenda,
            bronReferentie: event.eventIdentifier,
            status: .concept,
            bewijs: "Agenda-afspraak \(event.startDate.formatted())"
        )
    }
}
```

**Note on missing person matches**: rather than creating an activity with a placeholder UUID, surface unmatched events to the user in the import wizard for explicit person assignment. Don't silently invent persons.

## De-duplication on re-import

EventKit's `event.eventIdentifier` is stable per calendar event (until the event is deleted). Use it as the de-dup key.

```swift
func importEvents(_ events: [EKEvent], projectId: UUID) async throws -> ImportResult {
    var inserted = 0
    var skipped = 0

    try await db.write { db in
        for event in events {
            guard let eventId = event.eventIdentifier else { continue }

            let exists = try Activiteit
                .filter(Column("projectId") == projectId.uuidString)
                .filter(Column("bronReferentie") == eventId)
                .fetchOne(db) != nil

            if exists { skipped += 1; continue }

            var activiteit = mapper.map(event: event, projectId: projectId, faseId: nil)
            try activiteit.insert(db)
            inserted += 1
        }
    }

    return ImportResult(inserted: inserted, skipped: skipped)
}
```

Show the skipped count to the user — they want to know "I imported again and got 3 new events, 47 already there".

## Handling recurring events

EventKit returns each occurrence of a recurring event as a separate `EKEvent` with the same `eventIdentifier`. To distinguish occurrences, use `event.occurrenceDate` combined with the identifier:

```swift
let dedupKey = "\(event.eventIdentifier ?? "")_\(event.occurrenceDate?.timeIntervalSince1970 ?? 0)"
```

Use this composite as `bronReferentie` for recurring imports.

## Edge cases

- **All-day events**: `event.isAllDay == true`. Either skip them or treat as 8 hours (configurable). Default to skipping with a flag in the import preview.
- **Cancelled events**: filter with `event.status != .canceled`.
- **Events with zero duration**: skip — they're usually reminders, not work.
- **Events spanning midnight**: split into two days, or attribute fully to the start date. Default to start date.
- **Time zones**: `EKEvent.startDate` is already in the user's local time zone. Don't convert.

## What to never do

- Call `requestFullAccessToEvents` on every app launch — only when the user actually triggers import
- Store the entire `EKEvent` object — extract what you need into your own model
- Modify or delete events in the user's calendar (we never write back)
- Send raw event titles to the Claude API — sanitize first via `AnonymizationService.sanitize`
- Cache the list of `EKEvent` objects across calendar database changes — they become invalid

## Testing

EventKit doesn't have a built-in mock. Define a protocol and inject a stub:

```swift
protocol CalendarServiceProtocol {
    var currentAccess: CalendarService.AccessState { get }
    func requestAccess() async throws -> Bool
    func availableCalendars() -> [EKCalendar]
    func fetchEvents(_ query: CalendarService.EventQuery) -> [EKEvent]
}
```

For unit tests of the mapping service, build `EKEvent` instances using `EKEventStore` against an in-memory store, or test the mapping logic with your own value type fixtures and a small adapter.
