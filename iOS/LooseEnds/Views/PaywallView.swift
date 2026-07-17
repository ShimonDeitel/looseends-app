import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, detail: String)] = [
        ("sparkles", "AI auto-triage", "Every capture is sorted into the right bucket automatically — no manual filing, ever."),
        ("flame.fill", "Proactive check-ins", "Loose Ends asks whether you actually handled it, at the right moment."),
        ("chart.bar.fill", "Honesty streak", "One honest number: loops actually closed versus let quietly die.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LooseEndsTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(LooseEndsTheme.lime)
                            Text("Loose Ends Pro")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(LooseEndsTheme.offWhite)
                            Text("Stop filing your own thoughts. Let it sort itself, and get called on whether you actually did it.")
                                .font(.footnote)
                                .foregroundStyle(LooseEndsTheme.mutedText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        VStack(spacing: 14) {
                            ForEach(features, id: \.title) { feature in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: feature.icon)
                                        .font(.title3)
                                        .foregroundStyle(LooseEndsTheme.lime)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(LooseEndsTheme.offWhite)
                                        Text(feature.detail)
                                            .font(.caption)
                                            .foregroundStyle(LooseEndsTheme.mutedText)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .looseEndsPanel()

                        VStack(spacing: 10) {
                            Button {
                                Task {
                                    let success = await storeManager.purchase()
                                    if success { dismiss() }
                                }
                            } label: {
                                HStack {
                                    if storeManager.purchaseInFlight {
                                        ProgressView().tint(LooseEndsTheme.ink)
                                    } else {
                                        Text("Subscribe — \(storeManager.displayPrice)/month")
                                            .font(.headline)
                                    }
                                }
                                .foregroundStyle(LooseEndsTheme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LooseEndsTheme.lime, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(storeManager.purchaseInFlight)

                            Button("Restore Purchases") {
                                Task { await storeManager.restore() }
                            }
                            .font(.footnote)
                            .foregroundStyle(LooseEndsTheme.mutedText)

                            if let error = storeManager.lastErrorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Text("Auto-renews monthly. Cancel anytime in Settings.")
                                .font(.caption2)
                                .foregroundStyle(LooseEndsTheme.mutedText.opacity(0.7))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Go Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: storeManager.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
