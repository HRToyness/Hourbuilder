import SwiftUI
import Database
import Models
import Styling

public struct ActiviteitListView: View {
    @Bindable var viewModel: ActiviteitListViewModel
    let projectId: UUID
    let appDatabase: AppDatabase

    @State private var showFormSheet = false
    @State private var editing: Activiteit?
    @State private var selection = Set<UUID>()

    public init(
        viewModel: ActiviteitListViewModel,
        projectId: UUID,
        appDatabase: AppDatabase
    ) {
        self.viewModel = viewModel
        self.projectId = projectId
        self.appDatabase = appDatabase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            if viewModel.activiteiten.isEmpty {
                Text("Nog geen activiteiten ingevoerd.")
                    .font(.appBody())
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(20)
            } else {
                bulkActionBar
                table
            }
        }
        .background(Color.appBackground)
        .task { await viewModel.load() }
        .sheet(isPresented: $showFormSheet) {
            ActiviteitFormView(
                appDatabase: appDatabase,
                projectId: projectId,
                existing: editing
            ) {
                Task { await viewModel.load() }
            }
        }
    }

    // MARK: - Pieces

    private var headerBar: some View {
        HStack {
            AppSectionHeader(
                title: "Activiteiten",
                subtitle: "Alle uren voor dit project — handmatig + geïmporteerd"
            )
            Spacer()
            AppPrimaryButton(title: "+ Nieuw") {
                editing = nil
                showFormSheet = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var bulkActionBar: some View {
        HStack(spacing: 8) {
            Text(selection.isEmpty
                ? "Selecteer rijen voor bulk-acties"
                : "\(selection.count) geselecteerd")
                .font(.appLabel(11))
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            AppPrimaryButton(
                title: selection.isEmpty ? "Bevestig" : "Bevestig (\(selection.count))",
                isDisabled: selection.isEmpty
            ) {
                applyBulk(.bevestigd)
            }
            AppSecondaryButton(title: "Wijs af", isDisabled: selection.isEmpty) {
                applyBulk(.afgewezen)
            }
            AppSecondaryButton(title: "Naar concept", isDisabled: selection.isEmpty) {
                applyBulk(.concept)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.appSidebar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
        }
    }

    private var table: some View {
        Table(viewModel.activiteiten, selection: $selection) {
            TableColumn("Datum") { a in
                Text(format(a.datum))
                    .font(.appNumberSmall(11))
                    .foregroundStyle(Color.appTextPrimary)
            }
            .width(min: 90, ideal: 100)
            TableColumn("Persoon") { a in
                if let persoon = viewModel.personenById[a.persoonId] {
                    HStack(spacing: 6) {
                        AvatarBadge(name: persoon.naam, size: 18)
                        Text(persoon.naam)
                            .font(.appBody(12))
                    }
                } else {
                    Text(viewModel.persoonNaam(for: a))
                        .font(.appBody(12))
                }
            }
            TableColumn("Uren") { a in
                Text(formatHours(a.uren))
                    .font(.appNumberSmall(11))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 50, ideal: 60)
            TableColumn("Beschrijving") { a in
                Text(a.beschrijving.isEmpty ? "—" : a.beschrijving)
                    .lineLimit(1)
                    .font(.appBody(12))
                    .foregroundStyle(a.beschrijving.isEmpty ? Color.appTextTertiary : Color.appTextPrimary)
            }
            TableColumn("Status") { a in
                AppStatusBadge(
                    label: a.status.label,
                    tone: StatusBridge.badgeTone(for: a.status)
                )
            }
            .width(min: 80, ideal: 90)
            TableColumn("Bron") { a in
                AppStatusBadge(
                    label: a.bron.label,
                    tone: StatusBridge.badgeTone(for: a.bron)
                )
            }
            .width(min: 90, ideal: 110)
            TableColumn("") { a in
                HStack(spacing: 6) {
                    Button {
                        editing = a
                        showFormSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        Task { await viewModel.delete(id: a.id) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .width(50)
        }
    }

    // MARK: - Actions

    private func applyBulk(_ status: ActiviteitStatus) {
        let toUpdate = selection
        Task {
            await viewModel.bulkSetStatus(status, ids: toUpdate)
            await MainActor.run { selection.removeAll() }
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "d MMM yy"
        return formatter.string(from: date)
    }

    private func formatHours(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.decimalSeparator = ","
        return formatter.string(from: value as NSNumber) ?? "\(value)"
    }
}
