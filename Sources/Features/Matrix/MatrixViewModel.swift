import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class MatrixViewModel {
    public struct CellKey: Hashable, Sendable {
        public let persoonId: UUID
        public let weekId: String
    }

    public struct Totals: Sendable {
        public var perGroep: [PersoonGroep: Double] = [:]
        public var doelKlant: Double?
        public var doelIntern: Double?

        public var afwijkingKlant: Double? {
            guard let doelKlant else { return nil }
            return (perGroep[.klant] ?? 0) - doelKlant
        }

        public var afwijkingIntern: Double? {
            guard let doelIntern else { return nil }
            return (perGroep[.intern] ?? 0) - doelIntern
        }
    }

    public private(set) var project: Project?
    public private(set) var personen: [Persoon] = []
    public private(set) var fases: [Fase] = []
    public private(set) var weken: [WeekBucket] = []
    public private(set) var cellen: [CellKey: [Activiteit]] = [:]
    public private(set) var totalenPerWeek: [String: Double] = [:]
    public private(set) var totals = Totals()
    public private(set) var isLoading = false
    public var lastErrorMessage: String?

    public var filterPersoonGroep: PersoonGroep? {
        didSet { recomputeFromCache() }
    }

    public var filterBron: ActiviteitBron? {
        didSet { recomputeFromCache() }
    }

    public var filterFaseId: UUID? {
        didSet { recomputeFromCache() }
    }

    private var alleActiviteiten: [Activiteit] = []
    private let projectId: UUID
    private let projectRepo: ProjectRepository
    private let activiteitRepo: ActiviteitRepository

    public init(
        projectId: UUID,
        projectRepo: ProjectRepository,
        activiteitRepo: ActiviteitRepository
    ) {
        self.projectId = projectId
        self.projectRepo = projectRepo
        self.activiteitRepo = activiteitRepo
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let projectFetch = projectRepo.fetch(id: projectId)
            async let matrixFetch = activiteitRepo.fetchMatrixData(projectId: projectId)
            let (loadedProject, matrixData) = try await (projectFetch, matrixFetch)

            self.project = loadedProject
            self.personen = matrixData.personen
            self.fases = matrixData.fases
            self.alleActiviteiten = matrixData.activiteiten
            self.weken = computeWeeks(project: loadedProject, activities: matrixData.activiteiten)
            recomputeFromCache()
        } catch {
            lastErrorMessage = "Matrix laden mislukt: \(error.localizedDescription)"
        }
    }

    private func recomputeFromCache() {
        let filtered = alleActiviteiten.filter { activity in
            if let groep = filterPersoonGroep,
               let persoon = personen.first(where: { $0.id == activity.persoonId }),
               persoon.type.groep != groep {
                return false
            }
            if let bron = filterBron, activity.bron != bron {
                return false
            }
            if let faseId = filterFaseId, activity.faseId != faseId {
                return false
            }
            return true
        }

        var nieuweCellen: [CellKey: [Activiteit]] = [:]
        var weekTot: [String: Double] = [:]
        var perGroep: [PersoonGroep: Double] = [:]

        let persoonById = Dictionary(uniqueKeysWithValues: personen.map { ($0.id, $0) })

        for activity in filtered {
            let bucket = WeekBucketing.bucket(for: activity.datum)
            let weekId = "\(bucket.year)-W\(bucket.week)"
            let key = CellKey(persoonId: activity.persoonId, weekId: weekId)
            nieuweCellen[key, default: []].append(activity)

            if activity.status == .bevestigd {
                weekTot[weekId, default: 0] += activity.uren
                if let persoon = persoonById[activity.persoonId] {
                    perGroep[persoon.type.groep, default: 0] += activity.uren
                }
            }
        }

        self.cellen = nieuweCellen
        self.totalenPerWeek = weekTot
        self.totals = Totals(
            perGroep: perGroep,
            doelKlant: project?.doelTotaalKlantUren,
            doelIntern: project?.doelTotaalInternUren
        )
    }

    private func computeWeeks(project: Project?, activities: [Activiteit]) -> [WeekBucket] {
        let start = project?.startDatum ?? activities.map(\.datum).min() ?? Date()
        let activityMax = activities.map(\.datum).max()
        let candidateEnds: [Date] = [
            project?.eindDatum,
            activityMax,
            Date()
        ].compactMap { $0 }
        let end = candidateEnds.max() ?? start
        return WeekBucketing.weeks(from: start, to: end)
    }

    public func cellVariant(persoonId: UUID, weekId: String) -> MatrixCellState {
        let key = CellKey(persoonId: persoonId, weekId: weekId)
        let activiteiten = cellen[key] ?? []
        let uren = activiteiten
            .filter { $0.status != .afgewezen }
            .reduce(0) { $0 + $1.uren }
        return MatrixCellState(
            uren: uren,
            activiteiten: activiteiten
        )
    }
}

public struct MatrixCellState: Sendable {
    public let uren: Double
    public let activiteiten: [Activiteit]
}
