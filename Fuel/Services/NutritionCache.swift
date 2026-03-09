import Foundation

final class NutritionCache: @unchecked Sendable {
    static let shared = NutritionCache()

    private var memoryCache: [String: CacheEntry] = [:]
    private let maxMemoryEntries = 80
    private let maxDiskBytes = 2 * 1024 * 1024 // 2MB max disk cache
    private let ttl: TimeInterval = 24 * 60 * 60 // 24 hours
    private let queue = DispatchQueue(label: "com.fuel.nutritioncache", attributes: .concurrent)

    private init() {
        loadDiskCache()
    }

    // MARK: - Public API

    func get(for query: String) -> NutritionAnalysis? {
        let key = normalizeKey(query)
        var result: NutritionAnalysis?
        queue.sync {
            guard let entry = memoryCache[key] else { return }
            if Date().timeIntervalSince(entry.timestamp) > ttl {
                return
            }
            result = try? JSONDecoder().decode(NutritionAnalysis.self, from: entry.jsonData)
        }
        return result
    }

    func set(_ analysis: NutritionAnalysis, for query: String, rawJSON: Data? = nil) {
        let key = normalizeKey(query)
        guard let jsonData = rawJSON ?? (try? reencodeAnalysis(analysis)) else { return }
        let entry = CacheEntry(jsonData: jsonData, timestamp: Date())
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.memoryCache[key] = entry
            if self.memoryCache.count > self.maxMemoryEntries {
                self.evictOldest()
            }
            self.persistToDisk()
        }
    }

    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAll()
            self?.clearDiskCache()
        }
    }

    // MARK: - Key Normalization

    private func normalizeKey(_ query: String) -> String {
        query.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: - Re-encode (mirror the JSON structure Claude returns)

    private func reencodeAnalysis(_ a: NutritionAnalysis) throws -> Data {
        var dict: [String: Any] = [
            "meal_name": a.mealName,
            "total_calories": a.totalCalories,
            "protein_g": a.proteinG,
            "carbs_g": a.carbsG,
            "fat_g": a.fatG,
            "confidence": a.confidence
        ]
        if let v = a.fiberG { dict["fiber_g"] = v }
        if let v = a.sugarG { dict["sugar_g"] = v }
        if let v = a.sodiumMg { dict["sodium_mg"] = v }
        if let v = a.servingAssumed { dict["serving_assumed"] = v }
        if let v = a.confidenceReason { dict["confidence_reason"] = v }
        if let v = a.warnings { dict["warnings"] = v }
        if let v = a.healthInsight { dict["health_insight"] = v }
        if let v = a.scalingNote { dict["scaling_note"] = v }
        if let r = a.calorieRange {
            dict["calorie_range"] = ["low": r.low, "high": r.high]
        }

        let items: [[String: Any]] = a.items.map { item in
            var d: [String: Any] = [
                "item": item.item,
                "quantity": item.quantity,
                "calories": item.calories,
                "protein": item.protein,
                "carbs": item.carbs,
                "fat": item.fat
            ]
            if let n = item.note { d["note"] = n }
            return d
        }
        dict["items"] = items

        return try JSONSerialization.data(withJSONObject: dict)
    }

    // MARK: - Eviction

    private func evictOldest() {
        let sorted = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = sorted.prefix(memoryCache.count - maxMemoryEntries + 10)
        for (key, _) in toRemove {
            memoryCache.removeValue(forKey: key)
        }
    }

    // MARK: - Disk Persistence

    private var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("fuel_nutrition_cache.json")
    }

    private func persistToDisk() {
        let now = Date()
        let validEntries = memoryCache.filter { now.timeIntervalSince($0.value.timestamp) <= ttl }

        var diskArray: [[String: Any]] = []
        for (key, entry) in validEntries {
            if let json = try? JSONSerialization.jsonObject(with: entry.jsonData) {
                diskArray.append([
                    "key": key,
                    "timestamp": entry.timestamp.timeIntervalSince1970,
                    "analysis": json
                ])
            }
        }

        // Trim oldest entries until under disk size limit
        var toWrite = diskArray
        while true {
            guard let data = try? JSONSerialization.data(withJSONObject: toWrite) else { break }
            if data.count <= maxDiskBytes || toWrite.isEmpty {
                try? data.write(to: cacheFileURL, options: .atomic)
                break
            }
            toWrite.removeFirst()
        }
    }

    private func loadDiskCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        let now = Date()
        for entry in array {
            guard let key = entry["key"] as? String,
                  let ts = entry["timestamp"] as? TimeInterval,
                  let analysis = entry["analysis"] else { continue }

            let timestamp = Date(timeIntervalSince1970: ts)
            if now.timeIntervalSince(timestamp) > ttl { continue }

            if let jsonData = try? JSONSerialization.data(withJSONObject: analysis) {
                memoryCache[key] = CacheEntry(jsonData: jsonData, timestamp: timestamp)
            }
        }
    }

    private func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}

// MARK: - Cache Entry (stores raw JSON to avoid Encodable issues)

private struct CacheEntry {
    let jsonData: Data
    let timestamp: Date
}
