import SwiftUI
import Database
import Models
import Styling

public struct SaveAsTemplateView: View {
    let sourceProject: Project
    let appDatabase: AppDatabase
    let onSaved: (ProjectTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var naam: String
    @State private var beschrijving: String = ""
    @State private var includeNotities = true
    @State private var includeDoelen = true
    @State private var isSaving = false
    @State private var error: String?

    public init(
        sourceProject: Project,
        appDatabase: AppDatabase,
        onSaved: @escaping (ProjectTemplate) -> Void
    ) {
        self.sourceProject = sourceProject
        self.appDatabase = appDatabase
        self.onSaved = onSaved
        _naam = State(initialValue: sourceProject.naam)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Opslaan als template")
                    .font(.appH1(15))
                Text("Vanuit \(sourceProject.naam)")
                    .font(.appMeta(11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.appSidebar)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.appBorder).frame(height: 0.5)
            }

            Form {
                TextField("Template naam", text: $naam)
                TextField("Beschrijving", text: $beschrijving, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Doel-uren overnemen", isOn: $includeDoelen)
                Toggle("Notities overnemen", isOn: $includeNotities)
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 4) {
                Text("Wat wordt overgenomen:")
                    .font(.appLabel(11))
                    .foregroundStyle(.secondary)
                Text("• Fases met relatieve timing (week N–M sinds projectstart)")
                    .font(.appBody(11))
                Text("• Huidige projectleden als specifieke personen")
                    .font(.appBody(11))
                Text("• Activiteiten worden NIET meegekopieerd")
                    .font(.appBody(11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            if let error {
                Text(error)
                    .font(.appBody(11))
                    .foregroundStyle(Color.pillWarningFg)
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                AppPrimaryButton(
                    title: isSaving ? "Bezig…" : "Opslaan",
                    isDisabled: naam.trimmingCharacters(in: .whitespaces).isEmpty || isSaving
                ) {
                    Task { await save() }
                }
            }
            .padding(12)
            .background(Color.appSidebar)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.appBorder).frame(height: 0.5)
            }
        }
        .frame(minWidth: 480, minHeight: 460)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let service = ProjectTemplateApplyService(writer: appDatabase.dbWriter)
        do {
            let template = try await service.saveAsTemplate(
                sourceProjectId: sourceProject.id,
                templateNaam: naam.trimmingCharacters(in: .whitespaces),
                beschrijving: beschrijving,
                includeNotities: includeNotities,
                includeDoelen: includeDoelen
            )
            onSaved(template)
            dismiss()
        } catch {
            self.error = "Opslaan mislukt: \(error.localizedDescription)"
        }
    }
}
