import XCTest
import Foundation
@testable import Database
@testable import Models

final class ProjectTemplateApplyServiceTests: XCTestCase {
    private var appDb: AppDatabase!
    private var templateRepo: ProjectTemplateRepository!
    private var faseRepo: TemplateFaseRepository!
    private var entryRepo: TemplatePersoonEntryRepository!
    private var memberRepo: ProjectMemberRepository!
    private var projectRepo: ProjectRepository!
    private var persoonRepo: PersoonRepository!
    private var service: ProjectTemplateApplyService!

    override func setUp() async throws {
        appDb = try AppDatabase.makeInMemory()
        templateRepo = ProjectTemplateRepository(writer: appDb.dbWriter)
        faseRepo = TemplateFaseRepository(writer: appDb.dbWriter)
        entryRepo = TemplatePersoonEntryRepository(writer: appDb.dbWriter)
        memberRepo = ProjectMemberRepository(writer: appDb.dbWriter)
        projectRepo = ProjectRepository(writer: appDb.dbWriter)
        persoonRepo = PersoonRepository(writer: appDb.dbWriter)
        service = ProjectTemplateApplyService(writer: appDb.dbWriter)
    }

    // MARK: - Fase date math

    func testStartDateForWeek1IsProjectStart() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let computed = ProjectTemplateApplyService.startDate(for: 1, projectStart: start)
        XCTAssertEqual(computed, start)
    }

    func testStartDateForWeek3() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let computed = ProjectTemplateApplyService.startDate(for: 3, projectStart: start)
        XCTAssertEqual(computed, start.addingTimeInterval(14 * 86400))
    }

    func testEndDateForWeek2() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let computed = ProjectTemplateApplyService.endDate(for: 2, projectStart: start)
        XCTAssertEqual(computed, start.addingTimeInterval(13 * 86400))
    }

    // MARK: - Apply

    func testApplyClonesFasesAndAddsMembers() async throws {
        let template = ProjectTemplate(naam: "Std webbouw", defaultDoelInternUren: 200)
        _ = try await templateRepo.save(template)

        _ = try await faseRepo.save(.init(templateId: template.id, naam: "Discovery", volgorde: 1, weekVanaf: 1, weekTotEnMet: 2))
        _ = try await faseRepo.save(.init(templateId: template.id, naam: "Build", volgorde: 2, weekVanaf: 3, weekTotEnMet: 8))

        let alice = Persoon(naam: "Alice", rol: "Lead", type: .intern)
        _ = try await persoonRepo.save(alice)
        _ = try await entryRepo.save(.specifiek(templateId: template.id, persoonId: alice.id))

        let placeholderEntry = TemplatePersoonEntry.placeholder(
            templateId: template.id,
            rol: "PM klant",
            type: .klant
        )
        _ = try await entryRepo.save(placeholderEntry)

        let bob = Persoon(naam: "Bob", rol: "PM", type: .klant)
        _ = try await persoonRepo.save(bob)

        let projectStart = Date(timeIntervalSince1970: 1_700_000_000)
        let result = try await service.apply(.init(
            templateId: template.id,
            projectNaam: "Acme launch",
            klantNaam: "Acme",
            startDatum: projectStart,
            eindDatum: nil,
            factuurNummer: "INV-1",
            placeholderResolutions: [
                placeholderEntry.id: .existing(persoonId: bob.id)
            ]
        ))

        XCTAssertEqual(result.createdFaseIds.count, 2)
        XCTAssertEqual(Set(result.memberPersoonIds), Set([alice.id, bob.id]))

        let project = try await projectRepo.fetch(id: result.projectId)
        XCTAssertEqual(project?.doelTotaalInternUren, 200)
        XCTAssertEqual(project?.factuurNummer, "INV-1")

        let members = try await memberRepo.fetchPersonen(projectId: result.projectId)
        XCTAssertEqual(Set(members.map(\.id)), Set([alice.id, bob.id]))
    }

    func testApplyCreatesNewPersoonForPlaceholder() async throws {
        let template = ProjectTemplate(naam: "T")
        _ = try await templateRepo.save(template)

        let placeholderEntry = TemplatePersoonEntry.placeholder(
            templateId: template.id,
            rol: "Webbouwer",
            type: .leverancierWebbouwer
        )
        _ = try await entryRepo.save(placeholderEntry)

        let result = try await service.apply(.init(
            templateId: template.id,
            projectNaam: "P",
            klantNaam: "K",
            startDatum: Date(),
            placeholderResolutions: [
                placeholderEntry.id: .newPersoon(
                    naam: "Charlie",
                    rol: "Webbouwer",
                    type: .leverancierWebbouwer,
                    email: "charlie@example.com"
                )
            ]
        ))

        XCTAssertEqual(result.memberPersoonIds.count, 1)
        let allPersonen = try await persoonRepo.fetchAll()
        let charlie = allPersonen.first(where: { $0.naam == "Charlie" })
        XCTAssertNotNil(charlie)
        XCTAssertEqual(charlie?.email, "charlie@example.com")
    }

    func testApplySkipResolutionLeavesNoMember() async throws {
        let template = ProjectTemplate(naam: "T")
        _ = try await templateRepo.save(template)
        let placeholderEntry = TemplatePersoonEntry.placeholder(
            templateId: template.id,
            rol: "Optioneel",
            type: .intern
        )
        _ = try await entryRepo.save(placeholderEntry)

        let result = try await service.apply(.init(
            templateId: template.id,
            projectNaam: "P",
            klantNaam: "K",
            startDatum: Date(),
            placeholderResolutions: [placeholderEntry.id: .skip]
        ))

        XCTAssertTrue(result.memberPersoonIds.isEmpty)
        let members = try await memberRepo.fetchMembers(projectId: result.projectId)
        XCTAssertTrue(members.isEmpty)
    }

    func testMissingResolutionThrows() async throws {
        let template = ProjectTemplate(naam: "T")
        _ = try await templateRepo.save(template)
        let placeholderEntry = TemplatePersoonEntry.placeholder(
            templateId: template.id,
            rol: "Required",
            type: .intern
        )
        _ = try await entryRepo.save(placeholderEntry)

        do {
            _ = try await service.apply(.init(
                templateId: template.id,
                projectNaam: "P",
                klantNaam: "K",
                startDatum: Date(),
                placeholderResolutions: [:]
            ))
            XCTFail("Expected missingResolution error")
        } catch ProjectTemplateApplyError.missingResolution(let id) {
            XCTAssertEqual(id, placeholderEntry.id)
        }
    }

    func testApplyIsAtomic() async throws {
        // Valide template setup, maar de placeholder resolution wijst naar
        // een niet-bestaande persoonId → service throwt nadat Project en Fase
        // al zijn ingevoegd in dezelfde transactie → de hele transactie moet
        // rollbacken.
        let template = ProjectTemplate(naam: "T")
        _ = try await templateRepo.save(template)
        _ = try await faseRepo.save(.init(templateId: template.id, naam: "F1", volgorde: 1, weekVanaf: 1, weekTotEnMet: 1))

        let placeholderEntry = TemplatePersoonEntry.placeholder(
            templateId: template.id,
            rol: "PM klant",
            type: .klant
        )
        _ = try await entryRepo.save(placeholderEntry)

        let bogusId = UUID()

        do {
            _ = try await service.apply(.init(
                templateId: template.id,
                projectNaam: "P",
                klantNaam: "K",
                startDatum: Date(),
                placeholderResolutions: [
                    placeholderEntry.id: .existing(persoonId: bogusId)
                ]
            ))
            XCTFail("Expected persoonNotFound")
        } catch ProjectTemplateApplyError.persoonNotFound {
            // Verwacht
        }

        let allProjects = try await projectRepo.fetchAll()
        XCTAssertTrue(allProjects.isEmpty, "Geen project mag overblijven na rollback")
    }
}
