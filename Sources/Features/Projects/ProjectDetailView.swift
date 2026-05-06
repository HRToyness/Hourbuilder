import SwiftUI
import Database
import Models
import Services
import Styling

public struct ProjectDetailView: View {
    let projectId: UUID
    let appDatabase: AppDatabase

    @State private var project: Project?
    @State private var matrixVM: MatrixViewModel
    @State private var activiteitVM: ActiviteitListViewModel
    @State private var personenVM: PersoonListViewModel
    @State private var faseVM: FaseListViewModel
    @State private var reconstructionVM: ReconstructionViewModel
    @State private var selectedTab: Tab = .matrix
    @State private var showCalendarImportSheet = false
    @State private var showCsvImportSheet = false
    @State private var showHistorySheet = false
    @State private var showExportSheet = false

    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case matrix = "Matrix"
        case activiteiten = "Activiteiten"
        case personen = "Personen"
        case fases = "Fases"
        case reconstructie = "Reconstructie"

        var id: String { rawValue }
    }

    public init(projectId: UUID, appDatabase: AppDatabase) {
        self.projectId = projectId
        self.appDatabase = appDatabase
        let matrix = MatrixViewModel(
            projectId: projectId,
            projectRepo: ProjectRepository(writer: appDatabase.dbWriter),
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter)
        )
        let activiteit = ActiviteitListViewModel(
            projectId: projectId,
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter)
        )
        let personen = PersoonListViewModel(
            projectId: projectId,
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter),
            memberRepo: ProjectMemberRepository(writer: appDatabase.dbWriter)
        )
        let fase = FaseListViewModel(
            projectId: projectId,
            repository: FaseRepository(writer: appDatabase.dbWriter)
        )
        let reconstruction = ReconstructionViewModel(
            projectId: projectId,
            projectRepo: ProjectRepository(writer: appDatabase.dbWriter),
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter),
            faseRepo: FaseRepository(writer: appDatabase.dbWriter),
            aiServiceProvider: {
                let provider = AISettings.loadProvider()
                guard let key = try? KeychainHelper.loadAPIKey(for: provider),
                      !key.isEmpty else {
                    return nil
                }
                let model = AISettings.loadModel(for: provider)
                switch provider {
                case .claude:
                    return ClaudeService(apiKey: key, model: model)
                case .openai:
                    return OpenAIService(apiKey: key, model: model)
                }
            }
        )
        _matrixVM = State(initialValue: matrix)
        _activiteitVM = State(initialValue: activiteit)
        _personenVM = State(initialValue: personen)
        _faseVM = State(initialValue: fase)
        _reconstructionVM = State(initialValue: reconstruction)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let project {
                DetailHeader(summary: detailSummary(project: project))
            }
            tabRow
            content
        }
        .task {
            await loadProject()
            await activiteitVM.load()
            await faseVM.load()
        }
        .sheet(isPresented: $showCalendarImportSheet) {
            ImportView(viewModel: makeCalendarImportViewModel()) {
                showCalendarImportSheet = false
                Task {
                    await activiteitVM.load()
                    await matrixVM.load()
                }
            }
        }
        .sheet(isPresented: $showCsvImportSheet) {
            CsvImportView(viewModel: makeCsvImportViewModel()) {
                showCsvImportSheet = false
                Task {
                    await activiteitVM.load()
                    await matrixVM.load()
                }
            }
        }
        .sheet(isPresented: $showHistorySheet) {
            ImportHistoryView(viewModel: makeHistoryViewModel()) {
                Task {
                    await activiteitVM.load()
                    await matrixVM.load()
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView(viewModel: makeExportViewModel())
        }
    }

    // MARK: - Layout pieces

    private var tabRow: some View {
        HStack(spacing: 0) {
            SectionTabBar(selection: $selectedTab, items: tabItems)
            Spacer()
            importMenu
                .padding(.trailing, 4)
            AppIconButton("Exporteer", systemImage: "square.and.arrow.up") {
                showExportSheet = true
            }
        }
        .padding(.horizontal, 16)
        .background(Color.appSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private var importMenu: some View {
        Menu {
            Button("Apple Calendar…") { showCalendarImportSheet = true }
            Button("CSV of Excel bestand…") { showCsvImportSheet = true }
            Divider()
            Button("Historie & ongedaan maken…") { showHistorySheet = true }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12))
                Text("Importeer")
                    .font(.appBody(12))
            }
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .matrix:
            MatrixView(viewModel: matrixVM)
                .onChange(of: selectedTab) { _, _ in
                    Task { await matrixVM.load() }
                }
        case .activiteiten:
            ActiviteitListView(
                viewModel: activiteitVM,
                projectId: projectId,
                appDatabase: appDatabase
            )
            .onChange(of: selectedTab) { _, _ in
                Task { await activiteitVM.load() }
            }
        case .personen:
            PersoonListView(viewModel: personenVM, appDatabase: appDatabase)
                .onChange(of: selectedTab) { _, _ in
                    Task { await personenVM.load() }
                }
        case .fases:
            FaseListView(
                viewModel: faseVM,
                projectId: projectId,
                appDatabase: appDatabase
            )
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .fases {
                    Task { await faseVM.load() }
                }
            }
        case .reconstructie:
            ReconstructionView(
                viewModel: reconstructionVM,
                onApproved: {
                    Task {
                        await activiteitVM.load()
                        await matrixVM.load()
                    }
                },
                openSettings: {
                    if #available(macOS 14, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
            )
            .onChange(of: selectedTab) { _, newValue in
                if newValue == .reconstructie {
                    reconstructionVM.refreshAPIKeyStatus()
                    Task { await reconstructionVM.load() }
                }
            }
        }
    }

    // MARK: - Data

    private var tabItems: [SectionTabBar<Tab>.Item] {
        let personenInProject = Set(activiteitVM.activiteiten.map(\.persoonId)).count
        let pendingAi = reconstructionVM.pendingSuggestions.count
        return [
            .init(id: .matrix, label: "Matrix"),
            .init(id: .activiteiten, label: "Activiteiten", count: activiteitVM.activiteiten.count),
            .init(id: .personen, label: "Personen", count: personenInProject),
            .init(id: .fases, label: "Fases", count: faseVM.fases.count),
            .init(id: .reconstructie, label: "Reconstructie", count: pendingAi, countTone: pendingAi > 0 ? .ai : .neutral),
        ]
    }

    private func detailSummary(project: Project) -> DetailHeader.Summary {
        let personenInProject = Set(activiteitVM.activiteiten.map(\.persoonId)).count
        return DetailHeader.Summary(
            project: project,
            activiteitenCount: activiteitVM.activiteiten.count,
            personenCount: personenInProject,
            fasesCount: faseVM.fases.count
        )
    }

    private func loadProject() async {
        let repo = ProjectRepository(writer: appDatabase.dbWriter)
        project = try? await repo.fetch(id: projectId)
    }

    // MARK: - Sheet view models

    private func makeExportViewModel() -> ExportViewModel {
        ExportViewModel(
            projectId: projectId,
            projectRepo: ProjectRepository(writer: appDatabase.dbWriter),
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter),
            faseRepo: FaseRepository(writer: appDatabase.dbWriter)
        )
    }

    private func makeHistoryViewModel() -> ImportHistoryViewModel {
        ImportHistoryViewModel(
            projectId: projectId,
            importBronRepo: ImportBronRepository(writer: appDatabase.dbWriter),
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter)
        )
    }

    private func makeCalendarImportViewModel() -> ImportViewModel {
        ImportViewModel(
            projectId: projectId,
            calendarService: CalendarService(),
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter)
        )
    }

    private func makeCsvImportViewModel() -> CsvImportViewModel {
        CsvImportViewModel(
            projectId: projectId,
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter)
        )
    }
}
