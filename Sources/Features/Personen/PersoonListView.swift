import SwiftUI
import Database
import Models
import Styling

public struct PersoonListView: View {
    @Bindable var viewModel: PersoonListViewModel
    let appDatabase: AppDatabase

    @State private var showFormSheet = false

    public init(viewModel: PersoonListViewModel, appDatabase: AppDatabase) {
        self.viewModel = viewModel
        self.appDatabase = appDatabase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if viewModel.members.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .background(Color.appBackground)
        .task { await viewModel.load() }
        .sheet(isPresented: $showFormSheet) {
            PersoonFormView(appDatabase: appDatabase, existing: nil) {
                Task { await viewModel.load() }
            }
        }
    }

    private var header: some View {
        HStack {
            AppSectionHeader(
                title: "Personen op dit project",
                subtitle: "Leden zien terug in de matrix, ook met 0 uren."
            )
            Spacer()
            Menu {
                Button("Nieuwe persoon aanmaken…") {
                    showFormSheet = true
                }
                if !viewModel.nonMembers.isEmpty {
                    Divider()
                    Section("Bestaande toevoegen") {
                        ForEach(viewModel.nonMembers) { p in
                            Button("\(p.naam) — \(p.type.label)") {
                                Task { await viewModel.addExistingMember(persoonId: p.id) }
                            }
                        }
                    }
                }
            } label: {
                Text("+ Persoon")
                    .font(.appLabel(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Geen personen op dit project")
                .font(.appH2(13))
            Text("Voeg een bestaande persoon toe of maak een nieuwe aan via + Persoon.")
                .font(.appBody(11))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var table: some View {
        Table(viewModel.members) {
            TableColumn("") { p in
                AvatarBadge(name: p.naam, size: 22)
            }
            .width(32)
            TableColumn("Naam") { p in
                Text(p.naam).font(.appH2(12))
            }
            TableColumn("Rol") { p in
                Text(p.rol)
                    .font(.appBody(12))
                    .foregroundStyle(.secondary)
            }
            TableColumn("Type") { p in
                AppStatusBadge(
                    label: p.type.label,
                    tone: StatusBridge.badgeTone(for: p.type)
                )
            }
            .width(min: 120, ideal: 150)
            TableColumn("Email") { p in
                Text(p.email ?? "—")
                    .font(.appBody(12))
                    .foregroundStyle(p.email == nil ? Color.appTextTertiary : .secondary)
            }
            TableColumn("") { p in
                Button(role: .destructive) {
                    Task { await viewModel.removeMember(persoonId: p.id) }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Verwijder als lid (persoon blijft globaal bestaan)")
            }
            .width(50)
        }
    }
}
