import SwiftUI
import Database
import Models
import Styling

public struct PersoonFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var naam: String
    @State private var rol: String
    @State private var type: PersoonType
    @State private var email: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository: PersoonRepository
    private let editingId: UUID?
    private let onSaved: () -> Void

    public init(
        appDatabase: AppDatabase,
        existing: Persoon? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.repository = PersoonRepository(writer: appDatabase.dbWriter)
        self.editingId = existing?.id
        self.onSaved = onSaved
        _naam = State(initialValue: existing?.naam ?? "")
        _rol = State(initialValue: existing?.rol ?? "")
        _type = State(initialValue: existing?.type ?? .intern)
        _email = State(initialValue: existing?.email ?? "")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppSectionHeader(title: editingId == nil ? "Nieuwe persoon" : "Persoon bewerken")

            Form {
                TextField("Naam", text: $naam)
                TextField("Rol (bv. PM, developer)", text: $rol)
                Picker("Type", selection: $type) {
                    ForEach(PersoonType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                TextField("Email (optioneel)", text: $email)
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.appBody())
                    .foregroundStyle(Color.appWarning)
            }

            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                AppPrimaryButton(
                    title: isSaving ? "Bezig…" : "Opslaan",
                    isDisabled: !canSave
                ) {
                    Task { await saveTapped() }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
    }

    private var canSave: Bool {
        !naam.trimmingCharacters(in: .whitespaces).isEmpty
        && !rol.trimmingCharacters(in: .whitespaces).isEmpty
        && !isSaving
    }

    private func saveTapped() async {
        isSaving = true
        defer { isSaving = false }

        let persoon = Persoon(
            id: editingId ?? UUID(),
            naam: naam.trimmingCharacters(in: .whitespaces),
            rol: rol.trimmingCharacters(in: .whitespaces),
            type: type,
            email: email.trimmingCharacters(in: .whitespaces).isEmpty ? nil : email
        )
        do {
            _ = try await repository.save(persoon)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Opslaan mislukt: \(error.localizedDescription)"
        }
    }
}
