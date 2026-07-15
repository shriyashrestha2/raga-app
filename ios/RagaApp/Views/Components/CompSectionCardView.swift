import SwiftUI

/// Renders whichever Competition Dashboard section the caller hands it —
/// Finance shows a budget-vs-spent progress bar, Production shows
/// music/costume status, Logistics shows travel/lodging notes. Inline edit
/// controls only render when `isEditable` is true (the viewer's own
/// editable section, or Captain viewing any section). The card never
/// renders a locked/placeholder state for sections the viewer can't see —
/// callers simply don't instantiate this view for those, since the decoded
/// `CompetitionItem` won't even have that section's data.
struct CompSectionCardView: View {
    enum Kind {
        case finance(CompFinanceSectionModel)
        case production(CompProductionSectionModel)
        case logistics(CompLogisticsSectionModel)

        var title: String {
            switch self {
            case .finance: return "Finance"
            case .production: return "Production"
            case .logistics: return "Logistics"
            }
        }

        var icon: String {
            switch self {
            case .finance: return "dollarsign.circle.fill"
            case .production: return "video.fill"
            case .logistics: return "shippingbox.fill"
            }
        }
    }

    let kind: Kind
    let isEditable: Bool
    var onSaveFinance: ((_ budgetCents: Int, _ spentCents: Int, _ notes: String?) -> Void)?
    var onSaveProduction: ((_ musicStatus: String?, _ costumeStatus: String?, _ notes: String?) -> Void)?
    var onSaveLogistics: ((_ travelPlan: String?, _ lodging: String?, _ transportationNotes: String?) -> Void)?

    init(
        kind: Kind,
        isEditable: Bool,
        onSaveFinance: ((_ budgetCents: Int, _ spentCents: Int, _ notes: String?) -> Void)? = nil,
        onSaveProduction: ((_ musicStatus: String?, _ costumeStatus: String?, _ notes: String?) -> Void)? = nil,
        onSaveLogistics: ((_ travelPlan: String?, _ lodging: String?, _ transportationNotes: String?) -> Void)? = nil
    ) {
        self.kind = kind
        self.isEditable = isEditable
        self.onSaveFinance = onSaveFinance
        self.onSaveProduction = onSaveProduction
        self.onSaveLogistics = onSaveLogistics
    }

    @State private var isEditing = false

    @State private var budgetText = ""
    @State private var spentText = ""
    @State private var financeNotes = ""

    @State private var musicStatus = ""
    @State private var costumeStatus = ""
    @State private var productionNotes = ""

    @State private var travelPlan = ""
    @State private var lodging = ""
    @State private var transportationNotes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if isEditing {
                editContent
                saveCancelRow
            } else {
                readOnlyContent
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
        .onAppear(perform: seedEditState)
    }

    private var header: some View {
        HStack {
            Label(kind.title, systemImage: kind.icon)
                .font(.subheadline.bold())
                .foregroundStyle(Color("AccentColor"))
            Spacer()
            if isEditable && !isEditing {
                Button("Edit") {
                    seedEditState()
                    isEditing = true
                }
                .font(.caption.bold())
                .buttonStyle(.borderless)
                .tint(Color("AccentColor"))
            }
        }
    }

    // MARK: - Read-only

    @ViewBuilder
    private var readOnlyContent: some View {
        switch kind {
        case .finance(let finance):
            financeReadOnly(finance)
        case .production(let production):
            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Music", value: production.musicStatus)
                infoRow(label: "Costumes", value: production.costumeStatus)
                if let notes = production.notes, !notes.isEmpty {
                    infoRow(label: "Notes", value: notes)
                }
            }
        case .logistics(let logistics):
            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Travel", value: logistics.travelPlan)
                infoRow(label: "Lodging", value: logistics.lodging)
                if let notes = logistics.transportationNotes, !notes.isEmpty {
                    infoRow(label: "Transportation", value: notes)
                }
            }
        }
    }

    private func financeReadOnly(_ finance: CompFinanceSectionModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(formatCents(finance.spentCents)) spent")
                    .font(.caption.bold())
                    .foregroundStyle(Color("AccentColor"))
                Spacer()
                Text("of \(formatCents(finance.budgetCents)) budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: budgetFraction(finance))
                .tint(finance.spentCents > finance.budgetCents ? .red : Color("AccentColor"))
            if let notes = finance.notes, !notes.isEmpty {
                infoRow(label: "Notes", value: notes)
            }
        }
    }

    private func infoRow(label: String, value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text((value?.isEmpty == false) ? value! : "Not set")
                .font(.caption)
                .foregroundStyle(value?.isEmpty == false ? .primary : .secondary)
        }
    }

    private func budgetFraction(_ finance: CompFinanceSectionModel) -> Double {
        guard finance.budgetCents > 0 else { return 0 }
        return min(Double(finance.spentCents) / Double(finance.budgetCents), 1.0)
    }

    private func formatCents(_ cents: Int) -> String {
        let dollars = Double(cents) / 100
        return dollars.formatted(.currency(code: "USD"))
    }

    // MARK: - Edit

    @ViewBuilder
    private var editContent: some View {
        switch kind {
        case .finance:
            VStack(alignment: .leading, spacing: 8) {
                labeledField(label: "Budget ($)", text: $budgetText, keyboard: .decimalPad)
                labeledField(label: "Spent ($)", text: $spentText, keyboard: .decimalPad)
                labeledField(label: "Notes", text: $financeNotes)
            }
        case .production:
            VStack(alignment: .leading, spacing: 8) {
                labeledField(label: "Music", text: $musicStatus)
                labeledField(label: "Costumes", text: $costumeStatus)
                labeledField(label: "Notes", text: $productionNotes)
            }
        case .logistics:
            VStack(alignment: .leading, spacing: 8) {
                labeledField(label: "Travel", text: $travelPlan)
                labeledField(label: "Lodging", text: $lodging)
                labeledField(label: "Transportation", text: $transportationNotes)
            }
        }
    }

    private func labeledField(label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private var saveCancelRow: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                isEditing = false
                seedEditState()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Save") {
                save()
                isEditing = false
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AccentColor"))
            .controlSize(.small)
        }
    }

    private func save() {
        switch kind {
        case .finance:
            let budgetCents = Int((Double(budgetText) ?? 0) * 100)
            let spentCents = Int((Double(spentText) ?? 0) * 100)
            let notes = financeNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            onSaveFinance?(budgetCents, spentCents, notes.isEmpty ? nil : notes)
        case .production:
            let music = musicStatus.trimmingCharacters(in: .whitespacesAndNewlines)
            let costume = costumeStatus.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = productionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            onSaveProduction?(music.isEmpty ? nil : music, costume.isEmpty ? nil : costume, notes.isEmpty ? nil : notes)
        case .logistics:
            let travel = travelPlan.trimmingCharacters(in: .whitespacesAndNewlines)
            let lodgingValue = lodging.trimmingCharacters(in: .whitespacesAndNewlines)
            let transportation = transportationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            onSaveLogistics?(travel.isEmpty ? nil : travel, lodgingValue.isEmpty ? nil : lodgingValue, transportation.isEmpty ? nil : transportation)
        }
    }

    private func seedEditState() {
        switch kind {
        case .finance(let finance):
            budgetText = finance.budgetCents > 0 ? String(format: "%.2f", Double(finance.budgetCents) / 100) : ""
            spentText = finance.spentCents > 0 ? String(format: "%.2f", Double(finance.spentCents) / 100) : ""
            financeNotes = finance.notes ?? ""
        case .production(let production):
            musicStatus = production.musicStatus ?? ""
            costumeStatus = production.costumeStatus ?? ""
            productionNotes = production.notes ?? ""
        case .logistics(let logistics):
            travelPlan = logistics.travelPlan ?? ""
            lodging = logistics.lodging ?? ""
            transportationNotes = logistics.transportationNotes ?? ""
        }
    }
}
