import XCTest
import Foundation
@testable import Database
@testable import Models

final class MatrixDataTests: XCTestCase {
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

    func testFetchMatrixDataReturnsRelatedRecords() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)

        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        let bob = Persoon(naam: "Bob", rol: "Dev", type: .klant)
        _ = try await persoonRepo.save(alice)
        _ = try await persoonRepo.save(bob)

        let act1 = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 4,
            bron: .handmatig,
            status: .bevestigd
        )
        let act2 = Activiteit(
            projectId: project.id,
            persoonId: bob.id,
            datum: Date(),
            uren: 8,
            bron: .handmatig,
            status: .bevestigd
        )
        _ = try await activiteitRepo.save(act1)
        _ = try await activiteitRepo.save(act2)

        let data = try await activiteitRepo.fetchMatrixData(projectId: project.id)
        XCTAssertEqual(data.activiteiten.count, 2)
        XCTAssertEqual(Set(data.personen.map(\.id)), Set([alice.id, bob.id]))
    }

    func testUurTotalenPerGroep() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)

        let intern = Persoon(naam: "I", rol: "PM", type: .intern)
        let klant = Persoon(naam: "K", rol: "PM", type: .klant)
        let leverancier = Persoon(
            naam: "L",
            rol: "Webbouwer",
            type: .leverancierWebbouwer
        )
        for p in [intern, klant, leverancier] {
            _ = try await persoonRepo.save(p)
        }

        let activiteiten: [Activiteit] = [
            Activiteit(projectId: project.id, persoonId: intern.id, datum: Date(), uren: 4, bron: .handmatig, status: .bevestigd),
            Activiteit(projectId: project.id, persoonId: intern.id, datum: Date(), uren: 6, bron: .handmatig, status: .bevestigd),
            Activiteit(projectId: project.id, persoonId: klant.id, datum: Date(), uren: 8, bron: .handmatig, status: .bevestigd),
            Activiteit(projectId: project.id, persoonId: leverancier.id, datum: Date(), uren: 12, bron: .handmatig, status: .bevestigd),
            // status concept — should NOT be counted
            Activiteit(projectId: project.id, persoonId: intern.id, datum: Date(), uren: 99, bron: .handmatig, status: .concept),
        ]
        for act in activiteiten {
            _ = try await activiteitRepo.save(act)
        }

        let totalen = try await projectRepo.uurTotalenPerGroep(projectId: project.id)
        XCTAssertEqual(totalen[.intern] ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(totalen[.klant] ?? 0, 8, accuracy: 0.001)
        XCTAssertEqual(totalen[.leverancier] ?? 0, 12, accuracy: 0.001)
    }

    func testCascadeDeleteProjectRemovesActiviteiten() async throws {
        let project = Project(naam: "P", klantNaam: "K", startDatum: Date())
        _ = try await projectRepo.save(project)

        let alice = Persoon(naam: "Alice", rol: "PM", type: .intern)
        _ = try await persoonRepo.save(alice)

        let act = Activiteit(
            projectId: project.id,
            persoonId: alice.id,
            datum: Date(),
            uren: 4,
            bron: .handmatig,
            status: .bevestigd
        )
        _ = try await activiteitRepo.save(act)

        try await projectRepo.delete(id: project.id)

        let remaining = try await activiteitRepo.fetch(projectId: project.id)
        XCTAssertTrue(remaining.isEmpty)
    }
}
