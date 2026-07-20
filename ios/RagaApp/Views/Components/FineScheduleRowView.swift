import SwiftUI

struct FineScheduleRowView: View {
    let entry: FineScheduleEntry

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.offense)
                    .font(.subheadline.bold())
                if entry.isVariable, let description = entry.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let amountCents = entry.amountCents {
                Text((Double(amountCents) / 100).formatted(.currency(code: "USD")))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color("AccentColor"))
            } else {
                Text("Varies")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
