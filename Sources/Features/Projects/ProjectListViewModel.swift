import Foundation
import Observation
import GRDB
import Database
import Models

/// Houdt de observation Task buiten de actor-isolatie zodat `deinit` 'm kan
/// cancellen zonder Swift 6 concurrency error.
private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
}

@Observable
@MainActor
public final class ProjectListViewModel {
    public private(set) var projects: [Project] = []
    public private(set) var totalenById: [UUID: [PersoonGroep: Double]] = [:]
    public private(set) var isLoading = false
    public var lastErrorMessage: String?
    public var selectedProjectId: UUID?
    public var searchQuery: String = ""

    private let repository: ProjectRepository
    nonisolated private var observationTask: Task<Void, Never>? {
        get { _observationTaskBox.task }
        set { _observationTaskBox.task = newValue }
    }
    private let _observationTaskBox = TaskBox()

    public init(repository: ProjectRepository) {
        self.repository = repository
    }

    deinit {
        _observationTaskBox.task?.cancel()
    }

    public var filteredProjects: [Project] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return projects }
        return projects.filter {
            $0.naam.lowercased().contains(q)
                || $0.klantNaam.lowercased().contains(q)
        }
    }

    public func totalen(for projectId: UUID) -> [PersoonGroep: Double] {
        totalenById[projectId] ?? [:]
    }

    /// Observeert zowel projecten als bijbehorende totalen — als een activiteit
    /// of persoon verandert wordt de totalen-rij in de sidebar direct bijgewerkt.
    public func startObserving() {
        guard observationTask == nil else { return }
        let writer = repository.writer
        isLoading = true
        observationTask = Task { @MainActor [weak self] in
            do {
                let observation = ValueObservation.tracking { db -> ([Project], [UUID: [PersoonGroep: Double]]) in
                    let projects = try Project
                        .order(Project.Columns.startDatum.desc)
                        .fetchAll(db)

                    var totalen: [UUID: [PersoonGroep: Double]] = [:]
                    for project in projects {
                        let key = project.id.uuidString.uppercased()
                        let rows = try Row.fetchAll(db, sql: """
                            SELECT persoon.type AS type, SUM(activiteit.uren) AS totaal
                            FROM activiteit
                            JOIN persoon ON persoon.id = activiteit.persoonId
                            WHERE activiteit.projectId = ?
                              AND activiteit.status = ?
                            GROUP BY persoon.type
                            """, arguments: [
                                key,
                                ActiviteitStatus.bevestigd.rawValue
                            ])
                        var perGroep: [PersoonGroep: Double] = [:]
                        for row in rows {
                            guard let typeRaw: String = row["type"],
                                  let type = PersoonType(rawValue: typeRaw) else { continue }
                            let totaal: Double = row["totaal"] ?? 0
                            perGroep[type.groep, default: 0] += totaal
                        }
                        totalen[project.id] = perGroep
                    }
                    return (projects, totalen)
                }
                for try await (items, totalen) in observation.values(in: writer) {
                    guard let self else { return }
                    self.projects = items
                    self.totalenById = totalen
                    self.isLoading = false
                    if let selected = self.selectedProjectId,
                       !items.contains(where: { $0.id == selected }) {
                        self.selectedProjectId = nil
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

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            projects = try await repository.fetchAll()
            if let selected = selectedProjectId,
               !projects.contains(where: { $0.id == selected }) {
                selectedProjectId = nil
            }
        } catch {
            lastErrorMessage = "Kon projecten niet laden: \(error.localizedDescription)"
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
        } catch {
            lastErrorMessage = "Verwijderen mislukt: \(error.localizedDescription)"
        }
    }
}
