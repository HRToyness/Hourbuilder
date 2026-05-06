import Foundation
import Observation
import GRDB
import Database
import Models

private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}

@Observable
@MainActor
public final class PortfolioViewModel {
    public private(set) var summary: PortfolioSummary?
    public private(set) var isLoading = false
    public var lastErrorMessage: String?

    private let writer: any DatabaseWriter
    private let projectRepo: ProjectRepository
    nonisolated private var observationTask: Task<Void, Never>? {
        get { _observationTaskBox.task }
        set { _observationTaskBox.task = newValue }
    }
    private let _observationTaskBox = TaskBox()

    public init(projectRepo: ProjectRepository) {
        self.projectRepo = projectRepo
        self.writer = projectRepo.writer
    }

    deinit {
        _observationTaskBox.task?.cancel()
    }

    public func startObserving() {
        guard observationTask == nil else { return }
        let writer = self.writer
        let projectRepo = self.projectRepo
        isLoading = true
        observationTask = Task { @MainActor [weak self] in
            do {
                // Tick-observation: re-fire bij elke wijziging in project,
                // activiteit of persoon. Die count-waardes zelf gebruiken we
                // niet, alleen als trigger voor de duurdere summary fetch.
                let observation = ValueObservation.tracking { db -> [Int] in
                    let p = try Project.fetchCount(db)
                    let a = try Activiteit.fetchCount(db)
                    let per = try Persoon.fetchCount(db)
                    return [p, a, per]
                }
                for try await _ in observation.values(in: writer) {
                    guard let self else { return }
                    do {
                        let summary = try await projectRepo.fetchPortfolioSummary()
                        self.summary = summary
                        self.isLoading = false
                    } catch {
                        self.lastErrorMessage = "Portfolio laden mislukt: \(error.localizedDescription)"
                    }
                }
            } catch is CancellationError {
                // verwacht
            } catch {
                self?.isLoading = false
                self?.lastErrorMessage = "Observatie mislukt: \(error.localizedDescription)"
            }
        }
    }

    public func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }
}
