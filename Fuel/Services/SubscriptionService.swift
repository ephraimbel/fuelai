import StoreKit

@Observable
final class SubscriptionService {
    var isPremium = false
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []

    private let productIDs: Set<String> = [
        Constants.weeklyProductID,
        Constants.discountedWeeklyProductID,
        Constants.yearlyProductID
    ]

    init() {
        #if DEBUG
        isPremium = true
        #endif
        Task { await observeTransactions() }
    }

    func loadProducts() async throws {
        products = try await Product.products(for: productIDs)
            .sorted { $0.price < $1.price }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw FuelError.purchaseFailed("Verification failed")
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }
        let finalPurchased = purchased
        await MainActor.run {
            purchasedProductIDs = finalPurchased
            #if DEBUG
            isPremium = true
            #else
            isPremium = !finalPurchased.isEmpty
            #endif
        }
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await updatePurchasedProducts()
            }
        }
    }
}
