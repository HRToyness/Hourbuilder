import SwiftUI
import Database
import Models
import Styling

public struct FaseListView: View {
    @Bindable var viewModel: FaseListViewModel
    let projectId: UUID
    let appDatabase: AppDatabase

    @State private var showFormSheet = false
    @State private var editing: Fase?

    public init(
        viewModel: FaseListViewModel,
        projectId: UUID,
        appDatabase: AppDatabase
    ) {
        self.viewModel = viewModel
        self.projectId = projectId
        self.appDatabase = appDatabase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppSectionHeader(
                    title: "Fases",
                    subtitle: "Indeling van het project — gebruikt voor matrix filters en PDF subtotalen."
                )
                Spacer()
                AppPrimaryButton(title: "Nieuwe fase") {
                    editing = nil
                    showFormSheet = true
                }
            }

            if viewModel.fases.isEmpty {
                Text("Nog geen fases gedefinieerd.")
                    .font(.appBody())
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                Table(viewModel.fases) {
                    TableColumn("Vlg") { fase in
                        Text("\(fase.volgorde)")
                            .font(.appMono(11))
                    }
                    .width(40)
                    TableColumn("Naam", value: \.naam)
                    TableColumn("Start") { fase in
                        Text(format(fase.startDatum))
                            .font(.appMono(11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    TableColumn("Eind") { fase in
                        Text(format(fase.eindDatum))
                            .font(.appMono(11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    TableColumn("") { fase in
                        HStack(spacing: 8) {
                            Button("Bewerk") {
                                editing = fase
                                showFormSheet = true
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.delete(id: fase.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody(12))
                    .foregroundStyle(Color.appWarning)
            }
        }
        .padding(20)
        .task { await viewModel.load() }
        .sheet(isPresented: $showFormSheet) {
            FaseFormView(
                appDatabase: appDatabase,
                projectId: projectId,
                existing: editing,
                defaultVolgorde: viewModel.nextVolgorde
            ) {
                Task { await viewModel.load() }
            }
        }
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}
