import Foundation
import Observation
import Database
import Models
import Services

@Observable
@MainActor
public final class ImportViewModel {
    public private(set) var calendars: [CalendarDescriptor] = []
    public var selectedCalendarIds: Set<String> = []
    public var startDatum: Date
    public var eindDatum: Date
    public var titleFilter: String = ""
    public var skipAllDay: Bool = true

    public private(set) var personen: [Persoon] = []
    public private(set) var rows: [ImportRow] = []

    public private(set) var accessState: CalendarAccessState
    public var lastErrorMessage: String?
    public private(set) var lastImportResult: ImportResult?
    public private(set) var isFetching = false
    public private(set) var isImporting = false

    private let projectId: UUID
    private let calendarService: any CalendarServiceProtocol
    private let mapping: EventMappingService
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository

    public init(
        projectId: UUID,
        calendarService: any CalendarServiceProtocol,
        mapping: EventMappingService = EventMappingService(),
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository,
        defaultRange: (start: Date, end: Date)? = nil
    ) {
        self.projectId = projectId
        self.calendarService = calendarService
        self.mapping = mapping
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
        self.accessState = calendarService.currentAccess

        let now = Date()
        let calendar = Calendar(identifier: .iso8601)
        let defaultStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        self.startDatum = defaultRange?.start ?? defaultStart
        self.eindDatum = defaultRange?.end ?? now
    }

    public func refreshAccess() {
        accessState = calendarService.currentAccess
    }

    public func requestAccess() async {
        do {
            _ = try await calendarService.requestAccess()
            refreshAccess()
            await loadInitialData()
        } catch {
            lastErrorMessage = "Toegang vragen mislukt: \(error.localizedDescription)"
        }
    }

    public func loadInitialData() async {
        refreshAccess()
        guard accessState == .granted else { return }

        do {
            personen = try await persoonRepo.fetchAll()
        } catch {
            lastErrorMessage = "Personen laden mislukt: \(error.localizedDescription)"
        }
        calendars = calendarService.availableCalendars()
        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(calendars.map(\.id))
        }
    }

    public func toggleCalendar(_ id: String) {
        if selectedCalendarIds.contains(id) {
            selectedCalendarIds.remove(id)
        } else {
            selectedCalendarIds.insert(id)
        }
    }

    public func fetchPreview() async {
        guard accessState == .granted else { return }
        isFetching = true
        defer { isFetching = false }

        let query = CalendarEventQuery(
            startDate: startDatum,
            endDate: eindDatum,
            calendarIds: selectedCalendarIds.isEmpty ? nil : Array(selectedCalendarIds),
            titleContains: titleFilter.isEmpty ? nil : titleFilter
        )

        let descriptors = calendarService.fetchEvents(query: query)

        rows = descriptors.map { descriptor in
            let skip = mapping.skipReason(for: descriptor)
            let auto = mapping.matchPersoon(in: descriptor, from: personen)?.id
            let include = (skip == nil) && (auto != nil)
            return ImportRow(
                descriptor: descriptor,
                persoonId: auto,
                include: include,
                skipReason: skip
            )
        }
    }

    public func setInclude(_ rowId: String, _ value: Bool) {
        guard let idx = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[idx].include = value
    }

    public func setPersoon(_ rowId: String, _ persoonId: UUID?) {
        guard let idx = rows.firstIndex(where: { $0.id == rowId }) else { return }
        rows[idx].persoonId = persoonId
        if persoonId != nil, rows[idx].skipReason == nil {
            rows[idx].include = true
        }
    }

    public var includableRows: [ImportRow] {
        rows.filter { $0.include && $0.persoonId != nil && $0.skipReason == nil }
    }

    public var unmatchedCount: Int {
        rows.filter { $0.skipReason == nil && $0.persoonId == nil }.count
    }

    public var skippedCount: Int {
        rows.filter { $0.skipReason != nil }.count
    }

    public func runImport() async -> Bool {
        let toImport = includableRows
        guard !toImport.isEmpty else { return false }

        isImporting = true
        defer { isImporting = false }

        let activiteiten = toImport.compactMap { row -> Activiteit? in
            guard let persoonId = row.persoonId else { return nil }
            return mapping.map(
                descriptor: row.descriptor,
                projectId: projectId,
                faseId: nil,
                persoonId: persoonId
            )
        }

        do {
            let summary = try await activiteitRepo.runImport(
                projectId: projectId,
                bronType: .calendarSync,
                bestandsnaam: nil,
                candidates: activiteiten
            )
            self.lastImportResult = ImportResult(
                inserted: summary.inserted,
                skipped: summary.skipped
            )
            return true
        } catch {
            lastErrorMessage = "Import mislukt: \(error.localizedDescription)"
            return false
        }
    }
}
