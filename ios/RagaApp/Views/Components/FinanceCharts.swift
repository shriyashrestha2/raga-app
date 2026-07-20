import SwiftUI
import Charts

struct FundingSlice: Identifiable {
    let id = UUID()
    let source: String
    let amountCents: Int
}

/// Pie chart breaking down fundraising totals by source. First (and only,
/// so far) use of Swift Charts in the app — matches the app's existing card
/// chrome so it reads as part of the same design system.
struct FundingBreakdownChart: View {
    let slices: [FundingSlice]

    private let palette: [Color] = [Color("AccentColor"), .blue, .green, .orange, .purple, .pink, .teal, .yellow]

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.amountCents),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Source", slice.source))
            .cornerRadius(4)
        }
        .chartForegroundStyleScale(range: palette)
        .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
        .frame(height: 240)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}

struct FineOffenseSlice: Identifiable {
    let id = UUID()
    let offense: String
    let count: Int
}

/// Horizontal bar chart of fine counts per offense type — horizontal reads
/// better than vertical here since offense labels can be long.
struct FinesByOffenseChart: View {
    let slices: [FineOffenseSlice]

    var body: some View {
        Chart(slices) { slice in
            BarMark(
                x: .value("Fines", slice.count),
                y: .value("Offense", slice.offense)
            )
            .foregroundStyle(Color("AccentColor"))
            .cornerRadius(4)
        }
        .frame(height: CGFloat(slices.count) * 34 + 20)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
    }
}
