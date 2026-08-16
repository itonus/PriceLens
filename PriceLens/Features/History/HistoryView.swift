import SwiftUI
import SwiftData

/// Local scan history. Tap re-runs the search; swipe deletes; toolbar clears all.
struct HistoryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let onRerun: (SearchSession) -> Void

    @State private var records: [ScanHistoryRecord] = []
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyState(systemImage: "clock",
                               title: settings.localized("history.empty"),
                               message: settings.localized("history.empty.hint"))
                } else {
                    List {
                        ForEach(records, id: \.id) { record in
                            row(record)
                                .contentShape(Rectangle())
                                .onTapGesture { rerun(record) }
                                .accessibilityElement(children: .combine)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(settings.localized("history.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.localized("action.close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(settings.localized("history.clear")) { showClearConfirmation = true }
                        .disabled(records.isEmpty)
                        .accessibilityIdentifier("clearHistoryButton")
                }
            }
            .confirmationDialog(settings.localized("history.clear.confirm"),
                                isPresented: $showClearConfirmation,
                                titleVisibility: .visible) {
                Button(settings.localized("history.clear"), role: .destructive) {
                    container.historyRepository.clearAll()
                    reload()
                }
                Button(settings.localized("action.cancel"), role: .cancel) {}
            }
        }
        .onAppear(perform: reload)
    }

    private func row(_ record: ScanHistoryRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.query)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: Tokens.Spacing.xs) {
                    if let storePrice = record.storePrice {
                        Text(MoneyFormatter.string(storePrice, locale: settings.activeLocale))
                    }
                    if let best = record.bestPrice {
                        Text("→ \(MoneyFormatter.string(best, locale: settings.activeLocale))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let raw = record.decisionRawValue,
               let recommendation = PurchaseRecommendation(rawValue: raw) {
                DecisionBadge(recommendation: recommendation)
                    .font(.caption)
                    .scaleEffect(0.85)
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("historyRow")
    }

    private func rerun(_ record: ScanHistoryRecord) {
        onRerun(ResultsViewModel.session(for: record))
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            container.historyRepository.delete(records[index])
        }
        reload()
    }

    private func reload() {
        records = container.historyRepository.fetchAll()
    }
}
