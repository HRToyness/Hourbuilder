import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class InsightsViewModel {
    public private(set) var weekTotals: [WeekTotals] = []
    public private(set) var faseTotals: [FaseTotals] = []
    public private(set) var persoonTotals: [PersoonTotals] = []
    public private(set) var bevestigdCount: Int = 0
    public private(set) var conceptCount: Int = 0
    public private(set) var aiCount: Int = 0
    public private(set) var totaalUren: Double = 0
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let activiteitRepo: ActiviteitRepository

    public init(projectId: UUID, activiteitRepo: ActiviteitRepository) {
        self.projectId = projectId
        self.activiteitRepo = activiteitRepo
    }

    public func load() async {
        do {
            async let week = activiteitRepo.urenPerWeek(projectId: projectId)
            async let fase = activiteitRepo.urenPerFase(projectId: projectId)
            async let pers = activiteitRepo.urenPerPersoon(projectId: projectId)
            async let allActs = activiteitRepo.fetch(projectId: projectId)

            let (w, f, p, acts) = try await (week, fase, pers, allActs)
            weekTotals = w
            faseTotals = f
            persoonTotals = p
            bevestigdCount = acts.filter { $0.status == .bevestigd }.count
            conceptCount = acts.filter { $0.status == .concept }.count
            aiCount = acts.filter { $0.bron == .aiVoorstel }.count
            totaalUren = acts
                .filter { $0.status == .bevestigd }
                .reduce(0) { $0 + $1.uren }
        } catch {
            lastErrorMessage = "Insights laden mislukt: \(error.localizedDescription)"
        }
    }

    /// Donut: top 5 personen + "Andere" als de rest.
    public var donutPersonen: [PersoonTotals] {
        guard persoonTotals.count > 6 else { return persoonTotals }
        let top = Array(persoonTotals.prefix(5))
        let restTotaal = persoonTotals.dropFirst(5).reduce(0) { $0 + $1.totaal }
        let placeholder = Persoon(naam: "Andere", rol: "—", type: .intern)
        return top + [PersoonTotals(persoon: placeholder, totaal: restTotaal)]
    }
}
