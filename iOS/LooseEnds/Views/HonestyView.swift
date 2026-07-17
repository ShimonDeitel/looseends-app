import SwiftUI

/// The honesty streak, shown as plainly as possible: no badges, no levels,
/// no confetti — just the number and what it's made of.
struct HonestyView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @Environment(\.dismiss) private var dismiss

    private var stats: HonestyStats { itemStore.honestyStats }

    var body: some View {
        NavigationStack {
            ZStack {
                LooseEndsTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("\(stats.currentStreak)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundStyle(LooseEndsTheme.lime)
                        Text("current streak")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LooseEndsTheme.mutedText)
                    }

                    HStack(spacing: 32) {
                        statColumn(value: stats.totalClosed, label: "closed")
                        statColumn(value: stats.totalLetGo, label: "let go")
                    }

                    Text("No badges, no levels — just an honest count of loops you actually closed versus ones you let quietly die.")
                        .font(.caption)
                        .foregroundStyle(LooseEndsTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Honesty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(LooseEndsTheme.offWhite)
            Text(label)
                .font(.caption)
                .foregroundStyle(LooseEndsTheme.mutedText)
        }
        .frame(minWidth: 70)
    }
}

#Preview {
    HonestyView()
        .environmentObject(ItemStore())
}
