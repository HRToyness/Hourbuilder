import Foundation
import Observation
import Database
import Models
import Services

@Observable
@MainActor
public final class ReconstructionViewModel {
    public struct PendingSuggestion: Identifiable, Sendable {
        public let id: UUID
        public let suggestion: ActivitySuggestion
        public let persoon: Persoon
        public let proposedDate: Date
    }

    public struct GapInfo: Sendable, Identifiable {
        public var id: PersoonGroep { groep }
        public let groep: PersoonGroep
        public let bekend: Double
        public let doel: Double?
        public var verschil: Double? {
            doel.map { $0 - bekend }
        }
    }

    public private(set) var project: Project?
    public private(set) var personen: [Persoon] = []
    public private(set) var fases: [Fase] = []
    public private(set) var bekendeActiviteiten: [Activiteit] = []

    public private(set) var totalenPerGroep: [PersoonGroep: Double] = [:]
    public private(set) var gaps: [GapInfo] = []

    public private(set) var pendingSuggestions: [PendingSuggestion] = []
    public private(set) var isCallingAI = false
    public private(set) var hasAPIKey = false
    public private(set) var activeProvider: AIProvider = .claude
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let projectRepo: ProjectRepository
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository
    private let faseRepo: FaseRepository
    private let aiServiceProvider: @Sendable () -> AISuggestionService?
    private let anonymization = AnonymizationService()

    public init(
        projectId: UUID,
        projectRepo: ProjectRepository,
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository,
        faseRepo: FaseRepository,
        aiServiceProvider: @escaping @Sendable () -> AISuggestionService?
    ) {
        self.projectId = projectId
        self.projectRepo = projectRepo
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
        self.faseRepo = faseRepo
        self.aiServiceProvider = aiServiceProvider
    }

    public func load() async {
        do {
            async let projectFetch = projectRepo.fetch(id: projectId)
            async let activiteitenFetch = activiteitRepo.fetch(projectId: projectId)
            async let personenFetch = persoonRepo.fetchAll()
            async let faseFetch = faseRepo.fetch(projectId: projectId)

            let (loadedProject, loadedAct, loadedPers, loadedFase) = try await (
                projectFetch,
                activiteitenFetch,
                personenFetch,
                faseFetch
            )

            self.project = loadedProject
            self.bekendeActiviteiten = loadedAct
            self.personen = loadedPers
            self.fases = loadedFase
            recompute()
        } catch {
            lastErrorMessage = "Reconstructie laden mislukt: \(error.localizedDescription)"
        }
        refreshAPIKeyStatus()
    }

    public func refreshAPIKeyStatus() {
        let provider = AISettings.loadProvider()
        activeProvider = provider
        hasAPIKey = KeychainHelper.hasAPIKey(for: provider)
    }

    private func recompute() {
        let persoonById = Dictionary(uniqueKeysWithValues: personen.map { ($0.id, $0) })
        var perGroep: [PersoonGroep: Double] = [:]
        for activity in bekendeActiviteiten where activity.status == .bevestigd {
            if let persoon = persoonById[activity.persoonId] {
                perGroep[persoon.type.groep, default: 0] += activity.uren
            }
        }
        totalenPerGroep = perGroep
        gaps = [
            GapInfo(groep: .klant, bekend: perGroep[.klant] ?? 0, doel: project?.doelTotaalKlantUren),
            GapInfo(groep: .intern, bekend: perGroep[.intern] ?? 0, doel: project?.doelTotaalInternUren),
            GapInfo(groep: .leverancier, bekend: perGroep[.leverancier] ?? 0, doel: nil),
        ]
    }

    public func generateSuggestions() async {
        guard let aiService = aiServiceProvider() else {
            lastErrorMessage = "Geen API sleutel ingesteld. Open instellingen om er één toe te voegen."
            return
        }
        guard let project else { return }

        isCallingAI = true
        defer { isCallingAI = false }
        anonymization.reset()

        let payload = buildPayload(project: project)

        do {
            let suggestions = try await aiService.suggestActivities(payload: payload)
            pendingSuggestions = suggestions.compactMap { suggestion in
                guard let persoonId = anonymization.resolve(anon: suggestion.anonPersoon),
                      let persoon = personen.first(where: { $0.id == persoonId }) else {
                    return nil
                }
                let date = projectDate(for: suggestion.week, project: project)
                return PendingSuggestion(
                    id: UUID(),
                    suggestion: suggestion,
                    persoon: persoon,
                    proposedDate: date
                )
            }
        } catch {
            lastErrorMessage = "AI aanroep mislukt: \(error.localizedDescription)"
        }
    }

    public func approve(_ pending: PendingSuggestion) async {
        let activity = Activiteit(
            projectId: projectId,
            faseId: nil,
            persoonId: pending.persoon.id,
            datum: pending.proposedDate,
            uren: pending.suggestion.uren,
            beschrijving: pending.suggestion.categorie,
            bron: .aiVoorstel,
            bronReferentie: nil,
            status: .bevestigd,
            bewijs: pending.suggestion.onderbouwing
        )
        do {
            _ = try await activiteitRepo.save(activity)
            pendingSuggestions.removeAll { $0.id == pending.id }
            await load()
        } catch {
            lastErrorMessage = "Goedkeuren mislukt: \(error.localizedDescription)"
        }
    }

    public func reject(_ pending: PendingSuggestion) {
        pendingSuggestions.removeAll { $0.id == pending.id }
    }

    public func clearAllSuggestions() {
        pendingSuggestions.removeAll()
    }

    // MARK: - Helpers

    private func buildPayload(project: Project) -> AnonymizedReconstructionPayload {
        let weken = max(1, weeksBetween(project.startDatum, project.eindDatum ?? Date()))

        let bekend = bekendeActiviteiten
            .filter { $0.status == .bevestigd }
            .compactMap { activity -> AnonymizedActiviteit? in
                guard let persoon = personen.first(where: { $0.id == activity.persoonId }) else {
                    return nil
                }
                let anon = anonymization.anonymize(persoon: persoon)
                let week = weekIndex(of: activity.datum, projectStart: project.startDatum)
                return AnonymizedActiviteit(
                    week: week,
                    rol: anon,
                    uren: activity.uren,
                    categorie: bronCategory(activity.bron)
                )
            }

        // Verzeker alle personen voor stabiele anonimisering — ook degenen
        // zonder bekende uren krijgen al een mapping zodat de AI ze kan
        // benoemen in voorstellen.
        for persoon in personen {
            _ = anonymization.anonymize(persoon: persoon)
        }

        // Stuur generieke rol-types ("intern_dev", "klant_pm") naar de AI in
        // plaats van per-persoon anon-IDs ("intern_dev_1", "intern_dev_2") —
        // dat geeft bruikbaardere prompt-context.
        let rolTypen = Set(personen.map { anonymization.roleType(for: $0) }).sorted()

        return AnonymizedReconstructionPayload(
            projectContext: .init(
                duurWeken: weken,
                fases: fases.map { sanitizedFaseLabel($0.naam) },
                rolTypen: Array(rolTypen)
            ),
            bekendeActiviteiten: bekend,
            doelTotalen: .init(
                klant: project.doelTotaalKlantUren,
                intern: project.doelTotaalInternUren
            ),
            vraag: "Stel realistische activiteiten voor om de gaten te vullen, met onderbouwing per voorstel."
        )
    }

    private func weeksBetween(_ a: Date, _ b: Date) -> Int {
        let interval = b.timeIntervalSince(a)
        return max(1, Int(ceil(interval / (7 * 24 * 3600))))
    }

    private func weekIndex(of date: Date, projectStart: Date) -> Int {
        let interval = date.timeIntervalSince(projectStart)
        return max(1, Int(floor(interval / (7 * 24 * 3600))) + 1)
    }

    private func projectDate(for weekIndex: Int, project: Project) -> Date {
        // Land mid-week zodat AI-suggesties niet allemaal op project-start-DOW
        // blijven plakken. Offset+2 dagen, daarna zo nodig doorschuiven naar
        // de eerstvolgende werkdag.
        let dayOffset = max(0, weekIndex - 1) * 7 + 2
        let candidate = project.startDatum.addingTimeInterval(TimeInterval(dayOffset) * 24 * 3600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // maandag
        let weekday = calendar.component(.weekday, from: candidate)
        // weekday: 1 = zondag, 7 = zaterdag.
        let shift: Int
        switch weekday {
        case 7: shift = 2  // za → ma
        case 1: shift = 1  // zo → ma
        default: shift = 0
        }
        return calendar.date(byAdding: .day, value: shift, to: candidate) ?? candidate
    }

    private func bronCategory(_ bron: ActiviteitBron) -> String {
        switch bron {
        case .agenda: return "meeting"
        case .handmatig: return "handmatig"
        case .importCsv, .importXlsx: return "extern"
        case .aiVoorstel: return "ai"
        }
    }

    private func sanitizedFaseLabel(_ raw: String) -> String {
        // Fase namen zijn meestal generiek (analyse / bouw / oplevering),
        // maar het kan dat klantspecifieke termen erin sluipen — sanitize.
        anonymization.sanitize(raw)
    }
}
