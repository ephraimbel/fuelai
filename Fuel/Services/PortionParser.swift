import Foundation

struct ParsedPortion: Sendable {
    let originalQuery: String
    let cleanedFoodName: String
    let quantity: Double
    let unit: String?
    let scaleFactor: Double
}

final class PortionParser: @unchecked Sendable {
    static let shared = PortionParser()
    private init() {}

    // MARK: - Unit Conversion Tables

    /// Weight units normalized to grams
    private let weightToGrams: [String: Double] = [
        "g": 1.0, "gram": 1.0, "grams": 1.0,
        "oz": 28.3495, "ounce": 28.3495, "ounces": 28.3495,
        "lb": 453.592, "lbs": 453.592, "pound": 453.592, "pounds": 453.592,
        "kg": 1000.0, "kilogram": 1000.0, "kilograms": 1000.0,
    ]

    /// Volume units normalized to ml
    private let volumeToML: [String: Double] = [
        "ml": 1.0, "milliliter": 1.0, "milliliters": 1.0,
        "cup": 236.588, "cups": 236.588,
        "tbsp": 14.787, "tablespoon": 14.787, "tablespoons": 14.787,
        "tsp": 4.929, "teaspoon": 4.929, "teaspoons": 4.929,
        "fl oz": 29.5735, "fluid ounce": 29.5735, "fluid ounces": 29.5735,
        "liter": 1000.0, "liters": 1000.0, "l": 1000.0,
    ]

    /// Count-based units (no conversion needed, just recognized)
    private let countUnits: Set<String> = [
        "each", "piece", "pieces", "slice", "slices",
        "serving", "servings",
    ]

    /// Informal quantity words mapped to numeric values
    private let informalQuantities: [String: Double] = [
        "half": 0.5, "quarter": 0.25, "third": 0.333,
        "a": 1.0, "an": 1.0, "one": 1.0,
        "couple": 2.0, "a couple": 2.0,
        "two": 2.0, "three": 3.0, "four": 4.0, "five": 5.0,
        "six": 6.0, "seven": 7.0, "eight": 8.0, "nine": 9.0, "ten": 10.0,
        "dozen": 12.0, "half dozen": 6.0,
        "few": 3.0, "a few": 3.0,
        "some": 1.5,
        "double": 2.0, "triple": 3.0,
    ]

    /// Informal size/amount words that imply a specific quantity
    private let informalUnits: [String: (quantity: Double, unit: String)] = [
        "handful": (quantity: 1.0, unit: "oz"),
        "pinch": (quantity: 0.25, unit: "tsp"),
        "dash": (quantity: 0.125, unit: "tsp"),
        "splash": (quantity: 1.0, unit: "tbsp"),
        // Container-based portions (enterprise-level accuracy)
        "bowl": (quantity: 2.0, unit: "cup"),
        "big bowl": (quantity: 3.0, unit: "cup"),
        "small bowl": (quantity: 1.5, unit: "cup"),
        "plate": (quantity: 2.0, unit: "cup"),
        "glass": (quantity: 8.0, unit: "fl oz"),
        "tall glass": (quantity: 12.0, unit: "fl oz"),
        "small glass": (quantity: 6.0, unit: "fl oz"),
        "mug": (quantity: 8.0, unit: "fl oz"),
        "bottle": (quantity: 16.9, unit: "fl oz"),
        "can": (quantity: 12.0, unit: "fl oz"),
        "scoop": (quantity: 0.5, unit: "cup"),
        "spoonful": (quantity: 1.0, unit: "tbsp"),
        "heaping spoonful": (quantity: 2.0, unit: "tbsp"),
        "fistful": (quantity: 1.0, unit: "oz"),
        "palmful": (quantity: 1.0, unit: "oz"),
    ]

    // MARK: - Public API

    /// Parse a natural language food description into structured portion data.
    /// - Parameters:
    ///   - query: The user's input, e.g. "2 cups of rice" or "half a sandwich"
    ///   - standardServing: Optional standard serving description to compute scaleFactor, e.g. "1 cup" or "170g"
    /// - Returns: A ParsedPortion with extracted quantity, unit, cleaned food name, and scale factor
    func parse(_ query: String, standardServing: String? = nil) -> ParsedPortion {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var quantity: Double = 1.0
        var unit: String? = nil
        var remaining = trimmed

        // Step 1: Try to extract an informal unit like "handful of nuts"
        for (word, info) in informalUnits {
            if remaining.contains(word) {
                quantity = info.quantity
                unit = info.unit
                remaining = remaining.replacingOccurrences(of: word, with: "")
                    .replacingOccurrences(of: " of ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Step 2: If no informal unit was found, try to parse numeric quantity + unit
        if unit == nil {
            let parsed = extractQuantityAndUnit(from: remaining)
            quantity = parsed.quantity
            unit = parsed.unit
            remaining = parsed.remaining
        }

        // Step 3: Clean up the food name
        let cleanedFoodName = cleanFoodName(remaining)

        // Step 4: Compute scale factor
        let scaleFactor = computeScaleFactor(
            quantity: quantity,
            unit: unit,
            standardServing: standardServing
        )

        return ParsedPortion(
            originalQuery: query,
            cleanedFoodName: cleanedFoodName,
            quantity: quantity,
            unit: unit,
            scaleFactor: scaleFactor
        )
    }

    /// Build a human-readable portion hint string from a ParsedPortion
    func portionHint(from parsed: ParsedPortion) -> String {
        var parts: [String] = []

        if parsed.quantity != 1.0 || parsed.unit != nil {
            if parsed.quantity == Double(Int(parsed.quantity)) {
                parts.append("\(Int(parsed.quantity))")
            } else {
                parts.append(String(format: "%.2g", parsed.quantity))
            }
            if let u = parsed.unit {
                parts.append(u)
            }
        }

        if parsed.scaleFactor != 1.0 {
            parts.append("(scale factor: \(String(format: "%.2f", parsed.scaleFactor))x standard serving)")
        }

        return parts.isEmpty ? "" : "Portion: " + parts.joined(separator: " ")
    }

    // MARK: - Internal Parsing

    private struct ExtractedQuantity {
        let quantity: Double
        let unit: String?
        let remaining: String
    }

    private func extractQuantityAndUnit(from text: String) -> ExtractedQuantity {
        var working = text
        var quantity: Double = 1.0
        var unit: String? = nil

        // Pattern: "a couple eggs", "a few slices", "half a sandwich"
        for (word, value) in informalQuantities {
            // Match word boundaries: check if the text starts with or contains the informal word
            if working.hasPrefix(word + " ") || working.hasPrefix(word + " a ") {
                quantity = value
                working = working
                    .replacingOccurrences(of: word + " a ", with: "")
                    .replacingOccurrences(of: word + " ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Pattern: numeric value at the start, e.g. "2 cups", "300g", "1.5 servings"
        let numericPattern = #"^(\d+\.?\d*)\s*"#
        if let match = working.range(of: numericPattern, options: .regularExpression) {
            let numStr = String(working[match]).trimmingCharacters(in: .whitespaces)
            if let num = Double(numStr) {
                quantity = num
                working = String(working[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Pattern: unit attached to number, e.g. "300g" → already extracted 300, remaining starts with "g"
        // or unit as next word, e.g. "cups of rice"
        let unitResult = extractUnit(from: working)
        if let detectedUnit = unitResult.unit {
            unit = detectedUnit
            working = unitResult.remaining
        }

        // Remove leading "of " after unit extraction
        if working.hasPrefix("of ") {
            working = String(working.dropFirst(3))
        }

        return ExtractedQuantity(
            quantity: quantity,
            unit: unit,
            remaining: working.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private struct UnitResult {
        let unit: String?
        let remaining: String
    }

    private func extractUnit(from text: String) -> UnitResult {
        let working = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check "fl oz" first (two-word unit)
        for twoWordUnit in ["fl oz", "fluid ounce", "fluid ounces"] {
            if working.hasPrefix(twoWordUnit) {
                let rest = String(working.dropFirst(twoWordUnit.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return UnitResult(unit: "fl oz", remaining: rest)
            }
        }

        // Check single-word units
        let allUnits = Array(weightToGrams.keys) + Array(volumeToML.keys) + Array(countUnits)
        let sortedUnits = allUnits.sorted { $0.count > $1.count } // longest match first

        for unitName in sortedUnits {
            if working.hasPrefix(unitName + " ") || working.hasPrefix(unitName + "s ") || working == unitName || working == unitName + "s" {
                let prefixLen = working.hasPrefix(unitName + "s") ? unitName.count + 1 : unitName.count
                let rest = String(working.dropFirst(prefixLen))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Normalize to canonical unit name
                let canonical = canonicalUnit(unitName)
                return UnitResult(unit: canonical, remaining: rest)
            }
        }

        return UnitResult(unit: nil, remaining: working)
    }

    private func canonicalUnit(_ unit: String) -> String {
        // Normalize to shortest common form
        if weightToGrams[unit] != nil {
            switch unit {
            case "gram", "grams": return "g"
            case "ounce", "ounces": return "oz"
            case "pound", "pounds", "lbs": return "lb"
            case "kilogram", "kilograms": return "kg"
            default: return unit
            }
        }
        if volumeToML[unit] != nil {
            switch unit {
            case "cups": return "cup"
            case "tablespoon", "tablespoons": return "tbsp"
            case "teaspoon", "teaspoons": return "tsp"
            case "fluid ounce", "fluid ounces": return "fl oz"
            case "milliliter", "milliliters": return "ml"
            case "liters": return "liter"
            default: return unit
            }
        }
        if countUnits.contains(unit) {
            switch unit {
            case "pieces": return "piece"
            case "slices": return "slice"
            case "servings": return "serving"
            default: return unit
            }
        }
        return unit
    }

    // MARK: - Food Name Cleaning

    private func cleanFoodName(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading articles
        let prefixes = ["a ", "an ", "the ", "some "]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }

        // Remove leading "of "
        if cleaned.hasPrefix("of ") {
            cleaned = String(cleaned.dropFirst(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Scale Factor Computation

    private func computeScaleFactor(quantity: Double, unit: String?, standardServing: String?) -> Double {
        guard let standard = standardServing else {
            // No standard serving to compare against — use quantity as scale
            return max(quantity, 0.01)
        }

        // Parse the standard serving string to get its quantity and unit
        let stdParsed = extractQuantityAndUnit(from: standard.lowercased())
        let stdQty = stdParsed.quantity
        let stdUnit = stdParsed.unit

        guard stdQty > 0 else { return max(quantity, 1.0) }

        guard let queryUnit = unit, let servUnit = stdUnit else {
            // If either has no unit, just ratio the quantities
            return quantity / stdQty
        }

        // Same unit — simple ratio
        let canonicalQuery = canonicalUnit(queryUnit)
        let canonicalStd = canonicalUnit(servUnit)
        if canonicalQuery == canonicalStd {
            return quantity / stdQty
        }

        // Convert both to the same base (grams or ml) if possible
        if let queryGrams = convertToGrams(quantity: quantity, unit: canonicalQuery),
           let stdGrams = convertToGrams(quantity: stdQty, unit: canonicalStd),
           stdGrams > 0 {
            return queryGrams / stdGrams
        }

        if let queryML = convertToML(quantity: quantity, unit: canonicalQuery),
           let stdML = convertToML(quantity: stdQty, unit: canonicalStd),
           stdML > 0 {
            return queryML / stdML
        }

        // Units are incompatible — fall back to quantity ratio
        return quantity / stdQty
    }

    private func convertToGrams(quantity: Double, unit: String) -> Double? {
        // Check canonical and common forms
        let allForms = [unit, unit + "s"]
        for form in allForms {
            if let factor = weightToGrams[form] {
                return quantity * factor
            }
        }
        return nil
    }

    private func convertToML(quantity: Double, unit: String) -> Double? {
        let allForms = [unit, unit + "s"]
        for form in allForms {
            if let factor = volumeToML[form] {
                return quantity * factor
            }
        }
        return nil
    }
}
