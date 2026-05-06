import Foundation
import Observation
import Database
import Models
import Services

@Observable
@MainActor
public final class ExportViewModel {
    public var partij: PersoonGroep?
    public private(set) var pdfData: Data?
    public private(set) var csvText: String?
    public var lastErrorMessage: String?

    public private(set) var project: Project?
    private var personen: [Persoon] = []
    private var fases: [Fase] = []
    private var activiteiten: [Activiteit] = []

    private let projectId: UUID
    private let projectRepo: ProjectRepository
    private let activiteitRepo: ActiviteitRepository
    private let persoonRepo: PersoonRepository
    private let faseRepo: FaseRepository
    private let exportService: ExportService

    public init(
        projectId: UUID,
        projectRepo: ProjectRepository,
        activiteitRepo: ActiviteitRepository,
        persoonRepo: PersoonRepository,
        faseRepo: FaseRepository,
        exportService: ExportService = ExportService()
    ) {
        self.projectId = projectId
        self.projectRepo = projectRepo
        self.activiteitRepo = activiteitRepo
        self.persoonRepo = persoonRepo
        self.faseRepo = faseRepo
        self.exportService = exportService
    }

    public func load() async {
        do {
            async let projectFetch = projectRepo.fetch(id: projectId)
            async let activiteitFetch = activiteitRepo.fetch(projectId: projectId)
            async let persoonFetch = persoonRepo.fetchAll()
            async let faseFetch = faseRepo.fetch(projectId: projectId)
            let (loadedProject, loadedAct, loadedPers, loadedFase) = try await (
                projectFetch,
                activiteitFetch,
                persoonFetch,
                faseFetch
            )
            self.project = loadedProject
            self.activiteiten = loadedAct
            self.personen = loadedPers
            self.fases = loadedFase
        } catch {
            lastErrorMessage = "Laden mislukt: \(error.localizedDescription)"
        }
    }

    public func generatePDF() {
        guard let project else { return }
        let input = ExportInput(
            project: project,
            activiteiten: activiteiten,
            personen: personen,
            fases: fases,
            partij: partij
        )
        do {
            self.pdfData = try exportService.generatePDFData(input)
        } catch {
            lastErrorMessage = "PDF genereren mislukt: \(error.localizedDescription)"
        }
    }

    public func generateCSV() {
        guard let project else { return }
        let input = ExportInput(
            project: project,
            activiteiten: activiteiten,
            personen: personen,
            fases: fases,
            partij: partij
        )
        let bom = "\u{FEFF}"
        self.csvText = bom + exportService.generateCSV(input)
    }

    public func clearGenerated() {
        pdfData = nil
        csvText = nil
    }

    public var defaultFilenamePDF: String {
        let safeName = (project?.naam ?? "project")
            .replacingOccurrences(of: "/", with: "-")
        let suffix = partij.map { "_\($0.rawValue)" } ?? ""
        return "Urenoverzicht_\(safeName)\(suffix).pdf"
    }

    public var defaultFilenameCSV: String {
        let safeName = (project?.naam ?? "project")
            .replacingOccurrences(of: "/", with: "-")
        let suffix = partij.map { "_\($0.rawValue)" } ?? ""
        return "Urenoverzicht_\(safeName)\(suffix).csv"
    }
}
