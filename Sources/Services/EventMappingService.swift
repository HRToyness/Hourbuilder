import Foundation
import Models

/// Mapt een agenda-event naar een (concept) `Activiteit`. Persoon wordt niet
/// uitgezocht in de service zelf — de aanroeper geeft een `personLookup`
/// closure mee zodat de regie bij de UI ligt (aansluitend bij het
/// uitgangspunt: "Don't silently invent persons").
public struct EventMappingService: Sendable {
    public enum SkipReason: Sendable, Equatable {
        case allDay
        case cancelled
        case zeroDuration
    }

    public init() {}

    public func skipReason(for descriptor: CalendarEventDescriptor) -> SkipReason? {
        if descriptor.isAllDay { return .allDay }
        if descriptor.isCancelled { return .cancelled }
        if descriptor.durationHours <= 0 { return .zeroDuration }
        return nil
    }

    public func matchPersoon(
        in descriptor: CalendarEventDescriptor,
        from personen: [Persoon]
    ) -> Persoon? {
        let emails = descriptor.attendeeEmails.map { $0.lowercased() }
        guard !emails.isEmpty else { return nil }
        // Bij dubbele emails: behoud de eerste — beter dan crashen, en de UI
        // kan een waarschuwing tonen.
        let byEmail = Dictionary(
            personen.compactMap { p -> (String, Persoon)? in
                guard let email = p.email?.lowercased(), !email.isEmpty else { return nil }
                return (email, p)
            },
            uniquingKeysWith: { first, _ in first }
        )
        for email in emails {
            if let match = byEmail[email] {
                return match
            }
        }
        return nil
    }

    /// Genereert een concept activiteit uit een descriptor. `persoonId` moet
    /// al gekozen zijn door de aanroeper (handmatig of via `matchPersoon`).
    public func map(
        descriptor: CalendarEventDescriptor,
        projectId: UUID,
        faseId: UUID? = nil,
        persoonId: UUID
    ) -> Activiteit {
        let trimmedTitle = descriptor.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let beschrijving: String = {
            if let trimmedTitle, !trimmedTitle.isEmpty { return trimmedTitle }
            return "Agenda-afspraak"
        }()

        let datumFormatter = DateFormatter()
        datumFormatter.locale = Locale(identifier: "nl_NL")
        datumFormatter.dateFormat = "d MMM yyyy HH:mm"
        let bewijs = "Agenda-afspraak op \(datumFormatter.string(from: descriptor.startDate))"
            + (descriptor.calendarTitle.map { " (\($0))" } ?? "")

        return Activiteit(
            projectId: projectId,
            faseId: faseId,
            persoonId: persoonId,
            datum: descriptor.startDate,
            uren: descriptor.durationHours,
            beschrijving: beschrijving,
            bron: .agenda,
            bronReferentie: descriptor.dedupReference,
            status: .concept,
            bewijs: bewijs
        )
    }
}
