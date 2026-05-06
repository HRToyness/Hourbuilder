import Foundation
import GRDB
import Models

public struct ProjectTemplateApplyInput: Sendable {
    public let templateId: UUID
    public let projectNaam: String
    public let klantNaam: String
    public let startDatum: Date
    public let eindDatum: Date?
    public let factuurNummer: String?
    public let placeholderResolutions: [UUID: PlaceholderResolution]

    public init(
        templateId: UUID,
        projectNaam: String,
        klantNaam: String,
        startDatum: Date,
        eindDatum: Date? = nil,
        factuurNummer: String? = nil,
        placeholderResolutions: [UUID: PlaceholderResolution] = [:]
    ) {
        self.templateId = templateId
        self.projectNaam = projectNaam
        self.klantNaam = klantNaam
        self.startDatum = startDatum
        self.eindDatum = eindDatum
        self.factuurNummer = factuurNummer
        self.placeholderResolutions = placeholderResolutions
    }
}

public enum PlaceholderResolution: Sendable, Equatable {
    case existing(persoonId: UUID)
    case newPersoon(naam: String, rol: String, type: PersoonType, email: String?)
    case skip
}

public struct ProjectTemplateApplyResult: Sendable {
    public let projectId: UUID
    public let createdFaseIds: [UUID]
    public let memberPersoonIds: [UUID]
}

public enum ProjectTemplateApplyError: Error, LocalizedError, Equatable {
    case templateNotFound(UUID)
    case missingResolution(entryId: UUID)
    case persoonNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            return "Template niet gevonden: \(id.uuidString)."
        case .missingResolution(let id):
            return "Placeholder zonder keuze: \(id.uuidString)."
        case .persoonNotFound(let id):
            return "Persoon niet gevonden: \(id.uuidString)."
        }
    }
}

/// Orkestratie van "template → nieuw project". Eén transactie zodat een
/// halverwege gefaalde apply niets achterlaat.
public struct ProjectTemplateApplyService: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func apply(
        _ input: ProjectTemplateApplyInput
    ) async throws -> ProjectTemplateApplyResult {
        try await writer.write { db in
            try Self.performApply(input, db: db)
        }
    }

    static func performApply(
        _ input: ProjectTemplateApplyInput,
        db: GRDB.Database
    ) throws -> ProjectTemplateApplyResult {
        // 1. Template + child rows ophalen
        guard var _ = try ProjectTemplate.fetchOne(
            db,
            key: input.templateId.uuidString.uppercased()
        ) else {
            throw ProjectTemplateApplyError.templateNotFound(input.templateId)
        }

        let templateKey = input.templateId.uuidString.uppercased()
        let fases = try TemplateFase
            .filter(TemplateFase.Columns.templateId == templateKey)
            .order(TemplateFase.Columns.volgorde)
            .fetchAll(db)
        let entries = try TemplatePersoonEntry
            .filter(TemplatePersoonEntry.Columns.templateId == templateKey)
            .fetchAll(db)

        // 2. Validate dat elke placeholder een resolution heeft
        for entry in entries where entry.mode == .placeholder {
            if input.placeholderResolutions[entry.id] == nil {
                throw ProjectTemplateApplyError.missingResolution(entryId: entry.id)
            }
        }

        // 3. Project insert
        let template = try ProjectTemplate.fetchOne(
            db,
            key: input.templateId.uuidString.uppercased()
        )!  // already verified existence
        var project = Project(
            naam: input.projectNaam,
            klantNaam: input.klantNaam,
            startDatum: input.startDatum,
            eindDatum: input.eindDatum,
            status: .lopend,
            factuurNummer: input.factuurNummer,
            doelTotaalKlantUren: template.defaultDoelKlantUren,
            doelTotaalInternUren: template.defaultDoelInternUren,
            notities: template.defaultNotities
        )
        try project.insert(db)

        // 4. Fases met absolute datums
        var createdFaseIds: [UUID] = []
        for tf in fases {
            var fase = Fase(
                projectId: project.id,
                naam: tf.naam,
                volgorde: tf.volgorde,
                startDatum: startDate(for: tf.weekVanaf, projectStart: input.startDatum),
                eindDatum: endDate(for: tf.weekTotEnMet, projectStart: input.startDatum)
            )
            try fase.insert(db)
            createdFaseIds.append(fase.id)
        }

        // 5. Members (via specifieke entries en resolved placeholders)
        var memberPersoonIds: [UUID] = []
        for entry in entries {
            switch entry.mode {
            case .specifiek:
                guard let pid = entry.persoonId else { continue }
                guard try Persoon.fetchOne(db, key: pid.uuidString.uppercased()) != nil else {
                    throw ProjectTemplateApplyError.persoonNotFound(pid)
                }
                try addMemberIfMissing(projectId: project.id, persoonId: pid, db: db)
                memberPersoonIds.append(pid)
            case .placeholder:
                let resolution = input.placeholderResolutions[entry.id]!
                switch resolution {
                case .existing(let pid):
                    guard try Persoon.fetchOne(db, key: pid.uuidString.uppercased()) != nil else {
                        throw ProjectTemplateApplyError.persoonNotFound(pid)
                    }
                    try addMemberIfMissing(projectId: project.id, persoonId: pid, db: db)
                    memberPersoonIds.append(pid)
                case .newPersoon(let naam, let rol, let type, let email):
                    var p = Persoon(naam: naam, rol: rol, type: type, email: email)
                    try p.insert(db)
                    try addMemberIfMissing(projectId: project.id, persoonId: p.id, db: db)
                    memberPersoonIds.append(p.id)
                case .skip:
                    continue
                }
            }
        }

        return ProjectTemplateApplyResult(
            projectId: project.id,
            createdFaseIds: createdFaseIds,
            memberPersoonIds: memberPersoonIds
        )
    }

    // MARK: - Helpers

    private static func addMemberIfMissing(
        projectId: UUID,
        persoonId: UUID,
        db: GRDB.Database
    ) throws {
        let projectKey = projectId.uuidString.uppercased()
        let persoonKey = persoonId.uuidString.uppercased()
        let exists = try ProjectMember
            .filter(ProjectMember.Columns.projectId == projectKey)
            .filter(ProjectMember.Columns.persoonId == persoonKey)
            .fetchCount(db) > 0
        if exists { return }
        var member = ProjectMember(projectId: projectId, persoonId: persoonId)
        try member.insert(db)
    }

    public static func startDate(for weekVanaf: Int?, projectStart: Date) -> Date? {
        guard let week = weekVanaf, week >= 1 else { return nil }
        return projectStart.addingTimeInterval(TimeInterval((week - 1) * 86400 * 7))
    }

    public static func endDate(for weekTotEnMet: Int?, projectStart: Date) -> Date? {
        guard let week = weekTotEnMet, week >= 1 else { return nil }
        return projectStart.addingTimeInterval(TimeInterval(week * 86400 * 7 - 86400))
    }

    /// Inverse: gegeven een datum + projectStart, welke week is dat (1-based)?
    public static func week(for date: Date, projectStart: Date) -> Int {
        let secondsPerWeek: TimeInterval = 86400 * 7
        let diff = date.timeIntervalSince(projectStart)
        let week = Int(floor(diff / secondsPerWeek)) + 1
        return max(1, week)
    }

    // MARK: - Reverse: Opslaan als template

    public func saveAsTemplate(
        sourceProjectId: UUID,
        templateNaam: String,
        beschrijving: String,
        includeNotities: Bool,
        includeDoelen: Bool
    ) async throws -> ProjectTemplate {
        try await writer.write { db in
            try Self.performSaveAsTemplate(
                sourceProjectId: sourceProjectId,
                templateNaam: templateNaam,
                beschrijving: beschrijving,
                includeNotities: includeNotities,
                includeDoelen: includeDoelen,
                db: db
            )
        }
    }

    static func performSaveAsTemplate(
        sourceProjectId: UUID,
        templateNaam: String,
        beschrijving: String,
        includeNotities: Bool,
        includeDoelen: Bool,
        db: GRDB.Database
    ) throws -> ProjectTemplate {
        let projectKey = sourceProjectId.uuidString.uppercased()
        guard let project = try Project.fetchOne(db, key: projectKey) else {
            throw ProjectTemplateApplyError.templateNotFound(sourceProjectId)
        }

        var template = ProjectTemplate(
            naam: templateNaam,
            beschrijving: beschrijving,
            defaultDoelKlantUren: includeDoelen ? project.doelTotaalKlantUren : nil,
            defaultDoelInternUren: includeDoelen ? project.doelTotaalInternUren : nil,
            defaultNotities: includeNotities ? project.notities : ""
        )
        try template.insert(db)

        // Fases → TemplateFase met relatieve timing
        let fases = try Fase
            .filter(Fase.Columns.projectId == projectKey)
            .order(Fase.Columns.volgorde)
            .fetchAll(db)
        for fase in fases {
            var tf = TemplateFase(
                templateId: template.id,
                naam: fase.naam,
                volgorde: fase.volgorde,
                weekVanaf: fase.startDatum.map { week(for: $0, projectStart: project.startDatum) },
                weekTotEnMet: fase.eindDatum.map { week(for: $0, projectStart: project.startDatum) }
            )
            try tf.insert(db)
        }

        // Members → TemplatePersoonEntry specifiek
        let memberRows = try Row.fetchAll(db, sql: """
            SELECT persoonId FROM projectMember WHERE projectId = ?
            """, arguments: [projectKey])
        for row in memberRows {
            guard let persoonIdStr: String = row["persoonId"],
                  let pid = UUID(uuidString: persoonIdStr) else { continue }
            var entry = TemplatePersoonEntry.specifiek(
                templateId: template.id,
                persoonId: pid
            )
            try entry.insert(db)
        }

        return template
    }
}
