import Foundation
import StoreKit

/// StoreKit 2 — auto-renewable subscription
/// (`com.shimondeitel.looseends.pro.monthly`). Pro is never persisted as
/// trusted truth: it is derived live from `Transaction.currentEntitlements`,
/// granted only on a `.verified` transaction with no revocation and no
/// expiration in the past.
@MainActor
final class StoreManager: ObservableObject {
    static let productID = "com.shimondeitel.looseends.pro.monthly"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false
    @Published var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    private var debugForcePro: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["LOOSEENDS_FORCE_PRO"] == "1"
        #else
        return false
        #endif
    }

    init() {
        updatesTask = listenForTransactions()
        Task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["LOOSEENDS_NO_SK"] != "1" { await loadProduct() }
            #else
            await loadProduct()
            #endif
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    var displayPrice: String { product?.displayPrice ?? "$5.99" }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            self.product = products.first
        } catch {
            self.product = nil
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            if transaction.revocationDate != nil { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            entitled = true
        }
        isPro = entitled || debugForcePro
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "Purchase couldn't be verified. Try again."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = "Purchase failed. Try again."
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = "Restore failed. Try again."
        }
        await refreshEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }
}
