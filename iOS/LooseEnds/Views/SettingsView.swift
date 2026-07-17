import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showEraseConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                LooseEndsTheme.backgroundGradient.ignoresSafeArea()

                Form {
                    Section("Pro") {
                        if storeManager.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(LooseEndsTheme.lime)
                                Text("Loose Ends Pro is active")
                            }
                            Button("Restore Purchases") {
                                Task { await storeManager.restore() }
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Label("Upgrade to Pro — \(storeManager.displayPrice)/month", systemImage: "bolt.fill")
                            }
                            Button("Restore Purchases") {
                                Task { await storeManager.restore() }
                            }
                        }
                    }

                    Section("Data") {
                        Button("Erase All Captured Thoughts", role: .destructive) {
                            showEraseConfirm = true
                        }
                        Text("Everything you capture stays only on this device. Nothing is stored on a server.")
                            .font(.caption)
                            .foregroundStyle(LooseEndsTheme.mutedText)
                    }

                    Section("About") {
                        Link("Privacy Policy", destination: URL(string: "https://s0533495227.github.io/looseends/privacy.html")!)
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0")
                                .foregroundStyle(LooseEndsTheme.mutedText)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView().environmentObject(storeManager)
            }
            .confirmationDialog(
                "Erase every captured thought? This can't be undone.",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase Everything", role: .destructive) {
                    itemStore.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ItemStore())
        .environmentObject(StoreManager())
}
