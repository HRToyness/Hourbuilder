import SwiftUI
import Database
import Models
import Styling

public struct ProjectFormView: View {
    @Bindable var viewModel: ProjectFormViewModel
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        appDatabase: AppDatabase,
        existing: Project? = nil,
        onSaved: @escaping () -> Void
    ) {
        let repo = ProjectRepository(writer: appDatabase.dbWriter)
        self.viewModel = ProjectFormViewModel(repository: repo, existing: existing)
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(title: "Nieuw project")

            Form {
                Section("Basis") {
                    TextField("Naam", text: $viewModel.naam)
                    TextField("Klantnaam", text: $viewModel.klantNaam)
                    DatePicker(
                        "Startdatum",
                        selection: $viewModel.startDatum,
                        displayedComponents: [.date]
                    )
                    Toggle("Heeft einddatum", isOn: $viewModel.heeftEindDatum)
                    if viewModel.heeftEindDatum {
                        DatePicker(
                            "Einddatum",
                            selection: $viewModel.eindDatum,
                            in: viewModel.startDatum...,
                            displayedComponents: [.date]
                        )
                    }
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(ProjectStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }

                Section("Facturering") {
                    TextField("Factuurnummer", text: $viewModel.factuurNummer)
                    TextField("Doel klant uren", text: $viewModel.doelTotaalKlantUren)
                    TextField("Doel intern uren", text: $viewModel.doelTotaalInternUren)
                }

                Section("Notities") {
                    TextEditor(text: $viewModel.notities)
                        .frame(minHeight: 80)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                AppPrimaryButton(
                    title: viewModel.isSaving ? "Bezig…" : "Opslaan",
                    isDisabled: !viewModel.canSave
                ) {
                    Task {
                        let ok = await viewModel.save()
                        if ok {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 560)
    }
}
