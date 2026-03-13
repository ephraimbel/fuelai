import Foundation

enum WaterMeasurement: String, CaseIterable, Identifiable {
    case small      // 8 oz cup
    case medium     // 12 oz
    case tall       // 16 oz / 500ml standard bottle
    case large      // 24 oz
    case extraLarge // 32 oz / ~1L

    var id: String { rawValue }

    var mlAmount: Int {
        switch self {
        case .small:      return 237   // 8 fl oz
        case .medium:     return 355   // 12 fl oz
        case .tall:       return 473   // 16 fl oz
        case .large:      return 710   // 24 fl oz
        case .extraLarge: return 946   // 32 fl oz
        }
    }

    var displayName: String {
        switch self {
        case .small:      return "Cup"
        case .medium:     return "Mug"
        case .tall:       return "Bottle"
        case .large:      return "Large"
        case .extraLarge: return "XL"
        }
    }

    var icon: String {
        switch self {
        case .small:      return "drop.fill"
        case .medium:     return "mug.fill"
        case .tall:       return "waterbottle.fill"
        case .large:      return "waterbottle.fill"
        case .extraLarge: return "drop.circle.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .small:      return "8oz"
        case .medium:     return "12oz"
        case .tall:       return "16oz"
        case .large:      return "24oz"
        case .extraLarge: return "32oz"
        }
    }

    func displayAmount(unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .metric: return "\(mlAmount)ml"
        case .imperial:
            let oz = Double(mlAmount) / 29.5735
            return "\(Int(round(oz)))oz"
        }
    }
}
