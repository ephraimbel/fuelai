import Foundation
import Supabase

final class RemoteFoodSync: @unchecked Sendable {
    static let shared = RemoteFoodSync()
    private init() {}

    private let bucket = "food-database"
    private let remotePath = "foods_v1.json"
    private let cacheFileName = "remote_foods_v1.json"
    private let etagKey = "RemoteFoodSync.etag"

    // MARK: - Public

    func sync(supabase: SupabaseClient) async {
        do {
            let (data, changed) = try await download(supabase: supabase)
            if let data, changed {
                cache(data)
                let items = try decode(data)
                mergeIfNeeded(items)
            }
        } catch {
            // Download failed -- fall back to local cache
            loadCachedIfNeeded()
        }
    }

    // MARK: - Download

    private func download(supabase: SupabaseClient) async throws -> (Data?, Bool) {
        let storedEtag = UserDefaults.standard.string(forKey: etagKey)

        let data = try await supabase.storage
            .from(bucket)
            .download(path: remotePath)

        // Compute a simple hash to detect changes (Supabase Storage download
        // doesn't expose ETag headers directly through the Swift SDK, so we
        // hash the payload instead).
        let newEtag = computeHash(data)
        if let storedEtag, storedEtag == newEtag {
            return (nil, false)
        }
        UserDefaults.standard.set(newEtag, forKey: etagKey)
        return (data, true)
    }

    // MARK: - Decode

    private func decode(_ data: Data) throws -> [FoodItem] {
        let decoder = JSONDecoder()
        return try decoder.decode([FoodItem].self, from: data)
    }

    // MARK: - Cache

    private var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent(cacheFileName)
    }

    private func cache(_ data: Data) {
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCachedIfNeeded() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        guard let data = try? Data(contentsOf: cacheURL),
              let items = try? decode(data) else { return }
        mergeIfNeeded(items)
    }

    // MARK: - Merge

    private func mergeIfNeeded(_ items: [FoodItem]) {
        guard !items.isEmpty else { return }
        FoodDatabase.shared.merge(remote: items)
        NutritionRAG.shared.invalidateCache()
    }

    // MARK: - Hash

    private func computeHash(_ data: Data) -> String {
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash)
    }
}
