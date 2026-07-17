import SwiftUI

/// The quirky feature made concrete: one direct yes/no question about one
/// specific previously-captured item, surfaced opportunistically the next
/// time the app is opened after its check-in period has elapsed.
struct CheckInSheet: View {
    let item: Item
    let onAnswer: (Bool) -> Void

    @EnvironmentObject private var itemStore: ItemStore
    @State private var question: String?
    @State private var isLoading = true

    private var fallbackQuestion: String {
        let trimmed = item.rawText.count > 60 ? String(item.rawText.prefix(60)) + "…" : item.rawText
        return "Did you take care of: \"\(trimmed)\"?"
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "flame.fill")
                .font(.system(size: 34))
                .foregroundStyle(LooseEndsTheme.lime)

            Text("Honesty check-in")
                .font(.headline)
                .foregroundStyle(LooseEndsTheme.offWhite)

            Group {
                if isLoading {
                    ProgressView().tint(LooseEndsTheme.lime)
                } else {
                    Text(question ?? fallbackQuestion)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LooseEndsTheme.offWhite)
                }
            }
            .frame(minHeight: 60)
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    onAnswer(false)
                } label: {
                    Text("No, let it go")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LooseEndsTheme.binFill, in: Capsule())
                        .foregroundStyle(LooseEndsTheme.offWhite)
                }
                Button {
                    onAnswer(true)
                } label: {
                    Text("Yes, handled it")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LooseEndsTheme.lime, in: Capsule())
                        .foregroundStyle(LooseEndsTheme.ink)
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.5 : 1)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(LooseEndsTheme.backgroundGradient.ignoresSafeArea())
        .presentationDetents([.fraction(0.42)])
        .task { await loadQuestion() }
    }

    private func loadQuestion() async {
        if let existing = item.checkInQuestion, !existing.isEmpty {
            question = existing
            isLoading = false
            return
        }
        switch await AIProxyClient.shared.checkInQuestion(for: item) {
        case .success(let text):
            question = text
            itemStore.setCheckInQuestion(itemID: item.id, question: text)
        case .failure:
            question = fallbackQuestion
            itemStore.setCheckInQuestion(itemID: item.id, question: fallbackQuestion)
        }
        isLoading = false
    }
}

#Preview {
    CheckInSheet(item: Item(rawText: "Call the dentist"), onAnswer: { _ in })
        .environmentObject(ItemStore())
}
