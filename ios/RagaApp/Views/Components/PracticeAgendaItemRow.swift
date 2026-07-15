import SwiftUI

struct PracticeAgendaItemRow: View {
    let item: PracticeAgendaItemModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text("+\(item.startOffsetMin)m")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                Text("\(item.durationMin)m")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: 52, height: 44)
            .background(Color("AccentColor"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.subheadline.bold())
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
