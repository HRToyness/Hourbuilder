import SwiftUI
import Database
import Models
import Styling

public struct ActiviteitFormView: View {
    @Bindable var viewModel: ActiviteitFormViewModel
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        appDatabase: AppDatabase,
        projectId: UUID,
        existing: Activiteit? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.viewModel = ActiviteitFormViewModel(
            projectId: projectId,
            existing: existing,
            activiteitRepo: ActiviteitRepository(writer: appDatabase.dbWriter),
            persoonRepo: PersoonRepository(writer: appDatabase.dbWriter),
            faseRepo: FaseRepository(writer: appDatabase.dbWriter),
            memberRepo: ProjectMemberRepository(writer: appDatabase.dbWriter)
        )
        self.onSaved = onSaved
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(title: "Activiteit")

            Form {
                Section("Wie & wanneer") {
                    if viewModel.personen.isEmpty {
                        Text("Voeg eerst een persoon toe in het Personen tabblad.")
                            .font(.appBody())
                            .foregroundStyle(Color.appWarning)
                    } else {
                        Picker("Persoon", selection: $viewModel.persoonId) {
                            ForEach(viewModel.personen) { p in
                                Text("\(p.naam) — \(p.type.label)").tag(p.id as UUID?)
                            }
                        }
                    }
                    if !viewModel.fases.isEmpty {
                        Picker("Fase", selection: $viewModel.faseId) {
                            Text("— Geen fase —").tag(nil as UUID?)
                            ForEach(viewModel.fases) { f in
                                Text(f.naam).tag(f.id as UUID?)
                            }
                        }
                    }
                    DatePicker(
                        "Datum",
                        selection: $viewModel.datum,
                        displayedComponents: [.date]
                    )
                }

                Section("Uren") {
                    TextField("Aantal uren", text: $viewModel.urenInput)
                        .font(.appMono(13))
                    TextField("Beschrijving", text: $viewModel.beschrijving)
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(ActiviteitStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            if let err = viewModel.lastErrorMessage {
                Text(err)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                AppPrimaryButton(
                    title: viewModel.isSaving ? "Bezig…" : "Opslaan",
                    isDisabled: !viewModel.canSave
                ) {
                    Task {
                        if await viewModel.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .task { await viewModel.loadPickerOptions() }
    }
}
