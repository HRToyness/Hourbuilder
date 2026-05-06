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
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.grid.3x2")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.appTextTertiary)
            VStack(spacing: 6) {
                Text("Geen project geselecteerd")
                    .font(.appH1(16))
                    .foregroundStyle(Color.appTextPrimary)
                Text("Kies links een project of maak er een nieuw aan om de matrix te zien.")
                    .font(.appBody(12))
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
