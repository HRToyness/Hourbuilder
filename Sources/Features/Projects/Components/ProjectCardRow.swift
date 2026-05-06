import SwiftUI
import Models
import Styling

struct ProjectCardRow: View {
    let project: Project
    /// Totalen worden per project async geladen door de parent — als ze er nog
    /// niet zijn, tonen we de meta-rij zonder cijfers.
    let internUren: Double?
    let klantUren: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(project.naam)
                    .font(.appH2(13))
                    .lineLimit(1)
                Spacer()
                AppStatusBadge(
                    label: project.status.label,
                    tone: StatusBridge.badgeTone(for: project.status)
                )
            }
            Text(project.klantNaam)
                .font(.appMeta(11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                if let internUren {
                    metaPair(
                        value: internUren,
                        target: project.doelTotaalInternUren,
                        label: "intern"
                    )
                }
                if internUren != nil && klantUren != nil {
                    Text("·").foregroundStyle(.tertiary)
                }
                if let klantUren {
                    metaPair(
                        value: klantUren,
                        target: project.doelTotaalKlantUren,
                        label: "klant"
                    )
                }
            }

            if let target = project.doelTotaalInternUren, target > 0,
               let internUren {
                ProgressBar(
                    value: internUren / target,
                    fill: internUren > target ? Color.pillWarningFg : Color.appPrimary,
                    track: Color.appBorder.opacity(0.6)
                )
                .frame(height: 3)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func metaPair(value: Double, target: Double?, label: String) -> some View {
        HStack(spacing: 2) {
            Text(formatHours(value))
                .font(.appNumberSmall(11))
            if let target {
                Text("/\(formatHours(target)) \(label)")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
            } else {
                Text("u \(label)")
                    .font(.appMeta(10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatHours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f.string(from: value as NSNumber) ?? "\(Int(value))"
    }
}
