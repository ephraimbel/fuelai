import Foundation
import CryptoKit

final class PhotoScanCache: @unchecked Sendable {
    static let shared = PhotoScanCache()

    private var cache: [String: CachedResult] = [:]
    private let queue = DispatchQueue(label: "fuel.photoscancache")
    private let maxEntries = 50
    private let ttl: TimeInterval = 3600 // 1 hour

    private struct CachedResult {
        let analysis: FoodAnalysis
        let timestamp: Date
    }

    private init() {}

    func get(hash: String) -> FoodAnalysis? {
        queue.sync {
            guard let entry = cache[hash] else { return nil }
            if Date().timeIntervalSince(entry.timestamp) > ttl {
                cache.removeValue(forKey: hash)
                return nil
            }
            return entry.analysis
        }
    }

    func set(_ analysis: FoodAnalysis, hash: String) {
        queue.async { [self] in
            // Evict oldest if at capacity
            if cache.count >= maxEntries {
                let oldest = cache.min { $0.value.timestamp < $1.value.timestamp }
                if let key = oldest?.key { cache.removeValue(forKey: key) }
            }
            cache[hash] = CachedResult(analysis: analysis, timestamp: Date())
        }
    }
}

extension Data {
    /// Fast hash for image data caching. Uses first+last 4KB + size for speed.
    var fuelHash: String {
        let size = self.count
        let sampleSize = Swift.min(4096, size)
        var sample = Data()
        sample.append(self.prefix(sampleSize))
        if size > sampleSize * 2 {
            sample.append(self.suffix(sampleSize))
        }
        var sizeValue = size
        sample.append(Data(bytes: &sizeValue, count: MemoryLayout<Int>.size))
        let digest = SHA256.hash(data: sample)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
