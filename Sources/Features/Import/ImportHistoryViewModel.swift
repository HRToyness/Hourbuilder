import Foundation
import Observation
import Database
import Models

@Observable
@MainActor
public final class ImportHistoryViewModel {
    public private(set) var history: [ImportBron] = []
    public private(set) var lastUndoCount: Int?
    public var lastErrorMessage: String?

    private let projectId: UUID
    private let importBronRepo: ImportBronRepository
    private let activiteitRepo: ActiviteitRepository

    public init(
        projectId: UUID,
        importBronRepo: ImportBronRepository,
        activiteitRepo: ActiviteitRepository
    ) {
        self.projectId = projectId
        self.importBronRepo = importBronRepo
        self.activiteitRepo = activiteitRepo
    }

    public func load() async {
        do {
            history = try await importBronRepo.fetch(projectId: projectId)
        } catch {
            lastErrorMessage = "Historie laden mislukt: \(error.localizedDescription)"
        }
    }

    public func undo(_ bron: ImportBron) async {
        do {
            let count = try await activiteitRepo.undoImport(importBronId: bron.id)
            lastUndoCount = count
            await load()
        } catch {
            lastErrorMessage = "Ongedaan maken mislukt: \(error.localizedDescription)"
        }
    }
}
