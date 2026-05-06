import SwiftUI
import Database
import Models
import Styling

public struct ProjectListView: View {
    @Bindable var viewModel: ProjectListViewModel
    @Bindable var templateListVM: TemplateListViewModel
    let appDatabase: AppDatabase

    @State private var showNewProjectSheet = false
    @State private var editingTemplate: ProjectTemplate?
    @State private var applyingTemplate: ProjectTemplate?
    @State private var savingAsTemplate: Project?

    public init(
        viewModel: ProjectListViewModel,
        templateListVM: TemplateListViewModel,
        appDatabase: AppDatabase
    ) {
        self.viewModel = viewModel
        self.templateListVM = templateListVM
        self.appDatabase = appDatabase
    }

    public var body: some View {
        List(selection: $viewModel.selectedProjectId) {
            templatesSection
            projectenSection
        }
        .listStyle(.sidebar)
        .searchable(text: $viewModel.searchQuery, placement: .sidebar, prompt: "Zoek projecten…")
        .navigationTitle("UrenReconstructie")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Leeg project…") { showNewProjectSheet = true }
                    if !templateListVM.templates.isEmpty {
                        Divider()
                        Section("Vanaf template") {
                            ForEach(templateListVM.templates) { template in
                                Button(template.naam) { applyingTemplate = template }
                            }
                        }
                    }
                } label: {
                    Label("Nieuw project", systemImage: "plus")
                }
            }
        }
        .task {
            viewModel.startObserving()
            await templateListVM.load()
        }
        .sheet(isPresented: $showNewProjectSheet) {
            ProjectFormView(appDatabase: appDatabase) {}
        }
        .sheet(item: $editingTemplate) { template in
            templateEditorSheet(for: template)
        }
        .sheet(item: $applyingTemplate) { template in
            templateApplySheet(for: template)
        }
        .sheet(item: $savingAsTemplate) { project in
            SaveAsTemplateView(
                sourceProject: project,
                appDatabase: appDatabase
            ) { template in
                Task {
                    await templateListVM.load()
                    editingTemplate = template
                }
            }
        }
        .alert(
            "Fout",
            isPresented: .init(
                get: { viewModel.lastErrorMessage != nil },
                set: { if !$0 { viewModel.lastErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.lastErrorMessage ?? "")
        }
    }

    // MARK: - Templates section

    @ViewBuilder
    private var templatesSection: some View {
        Section {
            if templateListVM.templates.isEmpty {
                Text("Geen templates")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(templateListVM.templates) { template in
                    Button {
                        editingTemplate = template
                    } label: {
                        templateRow(template)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Verwijderen", role: .destructive) {
                            Task { await templateListVM.delete(id: template.id) }
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
        } header: {
            HStack {
                Text("Templates")
                Spacer()
                Button {
                    Task { await createNewTemplate() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func templateRow(_ template: ProjectTemplate) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(template.naam)
                .font(.appH2(12))
            HStack(spacing: 6) {
                let fases = templateListVM.faseCountById[template.id] ?? 0
                let pers = templateListVM.persoonCountById[template.id] ?? 0
                Text("\(fases) fase\(fases == 1 ? "" : "s")")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text("\(pers) persoon\(pers == 1 ? "" : "en")")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    // MARK: - Projecten section

    @ViewBuilder
    private var projectenSection: some View {
        Section("Projecten") {
            if viewModel.filteredProjects.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.filteredProjects) { project in
                    ProjectCardRow(
                        project: project,
                        internUren: viewModel.totalen(for: project.id)[.intern],
                        klantUren: viewModel.totalen(for: project.id)[.klant]
                    )
                    .tag(project.id)
                    .contextMenu {
                        Button("Opslaan als template…") {
                            savingAsTemplate = project
                        }
                        Divider()
                        Button("Verwijderen", role: .destructive) {
                            Task { await viewModel.delete(id: project.id) }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.searchQuery.isEmpty ? "Geen projecten" : "Geen resultaten")
                .font(.appH2(13))
            Text(viewModel.searchQuery.isEmpty
                ? "Maak een nieuw project aan via de + knop."
                : "Geen project gevonden voor '\(viewModel.searchQuery)'.")
                .font(.appBody(11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func createNewTemplate() async {
        let template = ProjectTemplate(naam: "Nieuwe template")
        do {
            let saved = try await ProjectTemplateRepository(writer: appDatabase.dbWriter)
                .save(template)
            await templateListVM.load()
            editingTemplate = saved
        } catch {
            templateListVM.lastErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func templateEditorSheet(for template: ProjectTemplate) -> some View {
        let vm = TemplateEditorViewModel(
            template: template,
            templateRepo: ProjectTemplateRepository(writer: appDatabase.dbWriter),
            faseRepo: TemplateFaseRepository(writer: appDatabase.dbWriter),
            entryRepo: TemplatePersoonEntryRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter)
        )
        TemplateEditorView(viewModel: vm) {
            Task { await templateListVM.load() }
        }
    }

    @ViewBuilder
    private func templateApplySheet(for template: ProjectTemplate) -> some View {
        let vm = TemplateApplyWizardViewModel(
            template: template,
            faseRepo: TemplateFaseRepository(writer: appDatabase.dbWriter),
            entryRepo: TemplatePersoonEntryRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter),
            applyService: ProjectTemplateApplyService(writer: appDatabase.dbWriter)
        )
        TemplateApplyWizardView(viewModel: vm) { newProjectId in
            viewModel.selectedProjectId = newProjectId
        }
    }
}

extension ProjectTemplate: @retroactive Identifiable {}
