import SwiftUI

/// Hosts the capture screen plus the chrome around it: the honesty-streak
/// badge, settings, and the opportunistic check-in queue that surfaces on
/// every app open (and every foreground) for Pro users.
struct RootView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showHonesty = false
    @State private var pendingCheckIns: [Item] = []

    private var currentCheckInBinding: Binding<Item?> {
        Binding<Item?>(
            get: { pendingCheckIns.first },
            set: { newValue in
                if newValue == nil, !pendingCheckIns.isEmpty {
                    pendingCheckIns.removeFirst()
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            CaptureView()
                .navigationTitle("Loose Ends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(LooseEndsTheme.charcoal, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: handleStreakTap) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("\(itemStore.honestyStats.currentStreak)")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(LooseEndsTheme.lime)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(LooseEndsTheme.offWhite)
                        }
                    }
                }
        }
        .tint(LooseEndsTheme.lime)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(itemStore).environmentObject(storeManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(storeManager)
        }
        .sheet(isPresented: $showHonesty) {
            HonestyView().environmentObject(itemStore)
        }
        .sheet(item: currentCheckInBinding) { item in
            CheckInSheet(item: item) { handled in
                itemStore.answerCheckIn(itemID: item.id, handled: handled)
                if !pendingCheckIns.isEmpty { pendingCheckIns.removeFirst() }
            }
            .environmentObject(itemStore)
        }
        .onAppear { refreshCheckIns() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshCheckIns() }
        }
    }

    private func handleStreakTap() {
        if storeManager.isPro {
            showHonesty = true
        } else {
            showPaywall = true
        }
    }

    private func refreshCheckIns() {
        guard storeManager.isPro else { return }
        guard pendingCheckIns.isEmpty else { return }
        let due = itemStore.dueCheckIns()
        guard !due.isEmpty else { return }
        pendingCheckIns = due
        for item in due {
            itemStore.markCheckInAsked(itemID: item.id)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(ItemStore())
        .environmentObject(StoreManager())
}
