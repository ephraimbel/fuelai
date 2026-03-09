import Foundation

enum FuelError: LocalizedError {
    case authFailed(String)
    case networkError(String)
    case aiAnalysisFailed(String)
    case cameraFailed(String)
    case purchaseFailed(String)
    case databaseError(String)
    case barcodeFailed(String)
    case imageTooLarge
    case rateLimited
    case chatRateLimited

    var errorDescription: String? {
        switch self {
        case .authFailed(let msg): return "Sign in failed: \(msg)"
        case .networkError(let msg): return "Connection issue: \(msg)"
        case .aiAnalysisFailed(let msg): return "Couldn't analyze food: \(msg)"
        case .cameraFailed(let msg): return "Camera error: \(msg)"
        case .purchaseFailed(let msg): return "Purchase failed: \(msg)"
        case .databaseError(let msg): return "Data error: \(msg)"
        case .barcodeFailed(let msg): return "Barcode scan failed: \(msg)"
        case .imageTooLarge: return "Image is too large. Try taking a closer photo."
        case .rateLimited: return "You've reached your daily limit. Upgrade to Premium for unlimited scans."
        case .chatRateLimited: return "You've reached your daily chat limit. Upgrade to Premium for unlimited messages."
        }
    }
}
