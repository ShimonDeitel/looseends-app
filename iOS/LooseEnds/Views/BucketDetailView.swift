import SwiftUI

/// Everything filed in one bucket: raw text, whatever fields were
/// extracted, when it was captured, and how its honesty check-in went.
struct BucketDetailView: View {
    let bucket: Bucket
    @EnvironmentObject private var itemStore: ItemStore
    @Environment(\.dismiss) private var dismiss

    private var items: [Item] {
        itemStore.items(in: bucket).sorted { $0.createdAt > $1.createdAt }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                LooseEndsTheme.backgroundGradient.ignoresSafeArea()

                if items.isEmpty {
                    Text("Nothing filed here yet.")
                        .foregroundStyle(LooseEndsTheme.mutedText)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                row(for: item)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(bucket.shortLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func row(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.rawText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LooseEndsTheme.offWhite)

            if item.extractedItemName != nil || item.extractedPersonName != nil || item.extractedDate != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if let name = item.extractedItemName {
                        detailLine(icon: "tag", text: name)
                    }
                    if let person = item.extractedPersonName {
                        detailLine(icon: "person", text: person)
                    }
                    if let date = item.extractedDate {
                        detailLine(icon: "clock", text: Self.dateFormatter.string(from: date))
                    }
                }
            }

            HStack {
                Text(Self.dateFormatter.string(from: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(LooseEndsTheme.mutedText)
                Spacer()
                checkInBadge(for: item)
            }
        }
        .padding(14)
        .looseEndsPanel(cornerRadius: 16)
    }

    private func detailLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(LooseEndsTheme.lime)
    }

    @ViewBuilder
    private func checkInBadge(for item: Item) -> some View {
        switch item.checkInStatus {
        case .none:
            EmptyView()
        case .asked:
            Text("Check-in pending")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LooseEndsTheme.mutedText)
        case .answeredYes:
            Label("Closed", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(LooseEndsTheme.lime)
        case .answeredNo:
            Label("Let go", systemImage: "circle.dashed")
                .font(.caption2.weight(.bold))
                .foregroundStyle(LooseEndsTheme.mutedText)
        }
    }
}

#Preview {
    BucketDetailView(bucket: .reminder)
        .environmentObject(ItemStore())
}
