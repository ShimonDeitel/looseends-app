import SwiftUI

@main
struct LooseEndsApp: App {
    @StateObject private var itemStore = ItemStore()
    @StateObject private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(itemStore)
                .environmentObject(storeManager)
                .preferredColorScheme(.dark)
        }
    }
}
