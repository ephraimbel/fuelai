import Foundation

/// Local cache for foods fetched from USDA and Open Food Facts APIs.
/// Persists to disk as JSON. Grows over time as users search for new foods.
/// Cached foods are merged into the RAG index for instant future lookups.
final class FoodAPICache: @unchecked Sendable {
    static let shared = FoodAPICache()

    private var cachedFoods: [String: FoodItem] = [:] // keyed by normalized name
    private var barcodeIndex: [String: String] = [:]   // barcode → normalized name
    private let queue = DispatchQueue(label: "com.fuel.foodapicache", attributes: .concurrent)
    private let maxItems = 5000

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    /// All cached foods as an array (for RAG index building).
    var allFoods: [FoodItem] {
        queue.sync { Array(cachedFoods.values) }
    }

    /// Number of cached items.
    var count: Int {
        queue.sync { cachedFoods.count }
    }

    /// Look up a cached food by name.
    func get(name: String) -> FoodItem? {
        let key = normalize(name)
        return queue.sync { cachedFoods[key] }
    }

    /// Look up a cached food by barcode.
    func getByBarcode(_ barcode: String) -> FoodItem? {
        queue.sync {
            guard let key = barcodeIndex[barcode] else { return nil }
            return cachedFoods[key]
        }
    }

    /// Add a food to the cache. Deduplicates by normalized name.
    func add(_ food: FoodItem, barcode: String? = nil) {
        let key = normalize(food.name)
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.cachedFoods[key] = food
            if let barcode {
                self.barcodeIndex[barcode] = key
            }
            if self.cachedFoods.count > self.maxItems {
                self.evictOldest()
            }
            self.persistToDisk()
            // Invalidate RAG index inside barrier so index rebuilds see the new food
            NutritionRAG.shared.invalidateCache()
        }
    }

    /// Add multiple foods at once.
    func addAll(_ foods: [FoodItem]) {
        guard !foods.isEmpty else { return }
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            for food in foods {
                let key = self.normalize(food.name)
                self.cachedFoods[key] = food
            }
            if self.cachedFoods.count > self.maxItems {
                self.evictOldest()
            }
            self.persistToDisk()
            NutritionRAG.shared.invalidateCache()
        }
    }

    // MARK: - Normalization

    private func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Eviction (remove oldest by dropping from the dictionary — simple FIFO approximation)

    private func evictOldest() {
        let excess = cachedFoods.count - maxItems + 100
        guard excess > 0 else { return }
        let keysToRemove = Array(cachedFoods.keys.prefix(excess))
        for key in keysToRemove {
            cachedFoods.removeValue(forKey: key)
        }
        // Also clean up barcode index
        let validKeys = Set(cachedFoods.keys)
        barcodeIndex = barcodeIndex.filter { validKeys.contains($0.value) }
    }

    // MARK: - Disk Persistence

    private var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("fuel_food_api_cache.json")
    }

    private var barcodeFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("fuel_barcode_index.json")
    }

    private func persistToDisk() {
        let encoder = JSONEncoder()
        // Save foods
        if let data = try? encoder.encode(Array(cachedFoods.values)) {
            try? data.write(to: cacheFileURL, options: .atomic)
        }
        // Save barcode index
        if let data = try? encoder.encode(barcodeIndex) {
            try? data.write(to: barcodeFileURL, options: .atomic)
        }
    }

    private func loadFromDisk() {
        let decoder = JSONDecoder()
        // Load foods
        if let data = try? Data(contentsOf: cacheFileURL),
           let foods = try? decoder.decode([FoodItem].self, from: data) {
            for food in foods {
                cachedFoods[normalize(food.name)] = food
            }
        }
        // Load barcode index
        if let data = try? Data(contentsOf: barcodeFileURL),
           let index = try? decoder.decode([String: String].self, from: data) {
            barcodeIndex = index
        }
    }
}
