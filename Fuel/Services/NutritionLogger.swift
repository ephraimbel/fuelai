import Foundation
import Supabase

actor NutritionLogger {
    static let shared = NutritionLogger()
    private var supabase: SupabaseClient?
    private var pendingLogs: [NutritionLog] = []
    private let maxBatchSize = 10

    // Local accuracy metrics (persisted for analytics)
    private let metricsKey = "fuel_accuracy_metrics"

    private init() {}

    func configure(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func log(
        queryType: QueryType,
        query: String,
        ragTopScore: Double?,
        ragMatchCount: Int,
        resultCalories: Int,
        resultConfidence: String,
        responseTimeMs: Int,
        wasOffline: Bool = false,
        wasCached: Bool = false,
        ragCorrected: Bool = false,
        correctionAmount: Int = 0
    ) {
        let entry = NutritionLog(
            queryType: queryType.rawValue,
            query: query.prefix(200).description,
            ragTopScore: ragTopScore,
            ragMatchCount: ragMatchCount,
            resultCalories: resultCalories,
            resultConfidence: resultConfidence,
            responseTimeMs: responseTimeMs,
            wasOffline: wasOffline,
            wasCached: wasCached,
            ragCorrected: ragCorrected,
            correctionAmount: correctionAmount,
            timestamp: Date()
        )

        pendingLogs.append(entry)
        updateLocalMetrics(entry)

        if pendingLogs.count >= maxBatchSize {
            Task { await flush() }
        }
    }

    func flush() async {
        guard let supabase, !pendingLogs.isEmpty else { return }
        let batch = pendingLogs
        pendingLogs.removeAll()

        do {
            try await supabase.from("nutrition_logs")
                .insert(batch)
                .execute()
        } catch {
            // Re-queue on failure (drop if too many)
            if pendingLogs.count < 50 {
                pendingLogs.append(contentsOf: batch)
            }
        }
    }

    // MARK: - Local Accuracy Metrics

    private func updateLocalMetrics(_ entry: NutritionLog) {
        var metrics = loadMetrics()
        metrics.totalScans += 1
        if entry.ragCorrected { metrics.ragCorrections += 1 }
        if entry.wasOffline { metrics.offlineFallbacks += 1 }
        if entry.wasCached { metrics.cacheHits += 1 }
        metrics.totalResponseTimeMs += entry.responseTimeMs

        // Track confidence distribution
        let conf = entry.resultConfidence.lowercased()
        if conf.contains("high") || conf.contains("exact") || conf.contains("label") {
            metrics.highConfidenceCount += 1
        } else if conf.contains("low") || conf.contains("rough") || conf.contains("fallback") {
            metrics.lowConfidenceCount += 1
        } else {
            metrics.mediumConfidenceCount += 1
        }

        saveMetrics(metrics)
    }

    /// Get current accuracy metrics for display/debugging.
    nonisolated func currentMetrics() -> AccuracyMetrics {
        loadMetrics()
    }

    private nonisolated func loadMetrics() -> AccuracyMetrics {
        guard let data = UserDefaults.standard.data(forKey: metricsKey),
              let metrics = try? JSONDecoder().decode(AccuracyMetrics.self, from: data) else {
            return AccuracyMetrics()
        }
        return metrics
    }

    private func saveMetrics(_ metrics: AccuracyMetrics) {
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: metricsKey)
        }
    }

    enum QueryType: String {
        case text
        case photo
        case barcode
    }
}

struct AccuracyMetrics: Codable {
    var totalScans: Int = 0
    var ragCorrections: Int = 0
    var offlineFallbacks: Int = 0
    var cacheHits: Int = 0
    var totalResponseTimeMs: Int = 0
    var highConfidenceCount: Int = 0
    var mediumConfidenceCount: Int = 0
    var lowConfidenceCount: Int = 0

    var avgResponseTimeMs: Int { totalScans > 0 ? totalResponseTimeMs / totalScans : 0 }
    var highConfidenceRate: Double { totalScans > 0 ? Double(highConfidenceCount) / Double(totalScans) : 0 }
    var ragCorrectionRate: Double { totalScans > 0 ? Double(ragCorrections) / Double(totalScans) : 0 }
}

struct NutritionLog: Encodable {
    let queryType: String
    let query: String
    let ragTopScore: Double?
    let ragMatchCount: Int
    let resultCalories: Int
    let resultConfidence: String
    let responseTimeMs: Int
    let wasOffline: Bool
    let wasCached: Bool
    let ragCorrected: Bool
    let correctionAmount: Int
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case queryType = "query_type"
        case query
        case ragTopScore = "rag_top_score"
        case ragMatchCount = "rag_match_count"
        case resultCalories = "result_calories"
        case resultConfidence = "result_confidence"
        case responseTimeMs = "response_time_ms"
        case wasOffline = "was_offline"
        case wasCached = "was_cached"
        case ragCorrected = "rag_corrected"
        case correctionAmount = "correction_amount"
        case timestamp
    }
}
