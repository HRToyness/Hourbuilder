import XCTest
import Foundation
import GRDB
@testable import Database
@testable import Models

final class MigrationV3BackfillTests: XCTestCase {
    /// Verifieert dat een verse in-memory DB (waar v3 dus net is gedraaid)
    /// op een leeg systeem geen members aanmaakt (geen activiteiten = geen
    /// backfill rijen).
    func testEmptyDatabaseHasNoMembers() async throws {
        let appDb = try AppDatabase.makeInMemory()
        let memberRepo = ProjectMemberRepository(writer: appDb.dbWriter)
        let count = try await appDb.dbWriter.read { db in
            try ProjectMember.fetchCount(db)
        }
        XCTAssertEqual(count, 0)
        _ = memberRepo
    }

    /// End-to-end: na het toevoegen van activiteiten moet er via de service
    /// expliciet een member zijn toegevoegd. (De backfill werkt alleen tijdens
    /// migration v3 zelf — bestaande live activiteiten in een al-gemigreerde
    /// DB triggeren niet automatisch member-creatie.)
    func testActiviteitenZonderMemberHebbenGeenLid() async throws {
        let appDb = try AppDatabase.makeInMemory()
        let projectRepo = ProjectRepository(writer: appDb.dbWriter)
        let persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        let activiteitRepo = ActiviteitRepository(writer: appDb.dbWriter)
        let memberRepo = ProjectMemberRepository(writer: appDb.dbWriter)

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

        let members = try await memberRepo.fetchMembers(projectId: project.id)
        XCTAssertTrue(members.isEmpty, "backfill draait alleen op upgrade, niet bij elke activity insert")
    }
}
