import XCTest
import Foundation
@testable import Database
@testable import Models

final class RunImportAndUndoTests: XCTestCase {
    private var appDb: AppDatabase!
    private var projectRepo: ProjectRepository!
    private var persoonRepo: PersoonRepository!
    private var activiteitRepo: ActiviteitRepository!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        projectRepo = ProjectRepository(writer: appDb.dbWriter)
        persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        activiteitRepo = ActiviteitRepository(writer: appDb.dbWriter)
    }

    func testRunImportCreatesImportBronAndStampsActiviteiten() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let candidate = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 4,
            bron: .agenda,
            bronReferentie: "evt-1",
            status: .concept
        )

        let summary = try await activiteitRepo.runImport(
            projectId: project.id,
            bronType: .calendarSync,
            bestandsnaam: nil,
            candidates: [candidate]
        )

        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(summary.skipped, 0)
        XCTAssertEqual(summary.importBron.rijenAantal, 1)
        XCTAssertEqual(summary.importBron.type, .calendarSync)

        let stored = try await activiteitRepo.fetch(projectId: project.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.importBronId, summary.importBron.id)
    }

    func testUndoImportRemovesActiviteitenAndImportBron() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let candidate1 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 1,
            bron: .agenda,
            bronReferentie: "evt-1",
            status: .concept
        )
        let candidate2 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 2,
            bron: .agenda,
            bronReferentie: "evt-2",
            status: .concept
        )
        let summary = try await activiteitRepo.runImport(
            projectId: project.id,
            bronType: .calendarSync,
            bestandsnaam: nil,
            candidates: [candidate1, candidate2]
        )

        // Voeg ook een handmatige activiteit toe — die mag NIET verwijderd worden door undo.
        let manueel = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 8,
            bron: .handmatig,
            status: .bevestigd
        )
        _ = try await activiteitRepo.save(manueel)

        let removed = try await activiteitRepo.undoImport(importBronId: summary.importBron.id)
        XCTAssertEqual(removed, 2)

        let stored = try await activiteitRepo.fetch(projectId: project.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, manueel.id)
    }

    func testUndoImportLeavesUnrelatedImportsAlone() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)
        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let s1 = try await activiteitRepo.runImport(
            projectId: project.id,
            bronType: .calendarSync,
            bestandsnaam: nil,
            candidates: [
                Activiteit(projectId: project.id, persoonId: alice.id, datum: Date(), uren: 1, bron: .agenda, bronReferentie: "x1", status: .concept)
            ]
        )
        _ = try await activiteitRepo.runImport(
            projectId: project.id,
            bronType: .csv,
            bestandsnaam: "later.csv",
            candidates: [
                Activiteit(projectId: project.id, persoonId: alice.id, datum: Date(), uren: 2, bron: .importCsv, bronReferentie: "later.csv:2", status: .concept)
            ]
        )

        let removed = try await activiteitRepo.undoImport(importBronId: s1.importBron.id)
        XCTAssertEqual(removed, 1)

        let remaining = try await activiteitRepo.fetch(projectId: project.id)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.bron, .importCsv)
    }
}
