import SwiftUI
import Database
import Features
import Models
import Styling

struct RootView: View {
    let appDatabase: AppDatabase
    let initError: String?

    @State private var listViewModel: ProjectListViewModel
    @State private var templateListVM: TemplateListViewModel
    @State private var portfolioVM: PortfolioViewModel

    init(appDatabase: AppDatabase, initError: String?) {
        self.appDatabase = appDatabase
        self.initError = initError
        _listViewModel = State(initialValue: ProjectListViewModel(
            repository: ProjectRepository(writer: appDatabase.dbWriter)
        ))
        _templateListVM = State(initialValue: TemplateListViewModel(
            templateRepo: ProjectTemplateRepository(writer: appDatabase.dbWriter),
            faseRepo: TemplateFaseRepository(writer: appDatabase.dbWriter),
            entryRepo: TemplatePersoonEntryRepository(writer: appDatabase.dbWriter)
        ))
        _portfolioVM = State(initialValue: PortfolioViewModel(
            projectRepo: ProjectRepository(writer: appDatabase.dbWriter)
        ))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 400)
        } detail: {
            detail
        }
        .background(Color.appBackground)
        .alert(
            "Database",
            isPresented: .init(
                get: { initError != nil },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(initError ?? "")
        }
    }

    private var sidebar: some View {
        ProjectListView(
            viewModel: listViewModel,
            templateListVM: templateListVM,
            appDatabase: appDatabase
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let projectId = listViewModel.selectedProjectId {
            ProjectDetailView(projectId: projectId, appDatabase: appDatabase)
                .id(projectId)
        } else {
            PortfolioView(viewModel: portfolioVM) { projectId in
                listViewModel.selectedProjectId = projectId
            }
        }
    }
}
