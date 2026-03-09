import Foundation

struct CalorieCalculator {

    // MARK: - BMR (Mifflin-St Jeor — gold standard)

    static func calculateBMR(weightKg: Double, heightCm: Double, age: Int, sex: Sex) -> Double {
        let base = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age))
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    // MARK: - TDEE

    static func calculateTDEE(weightKg: Double, heightCm: Double, age: Int, sex: Sex, activityLevel: ActivityLevel) -> Int {
        let bmr = calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
        return Int(bmr * activityLevel.multiplier)
    }

    // MARK: - Target Calories

    static func calculateTargetCalories(weightKg: Double, heightCm: Double, age: Int, sex: Sex, activityLevel: ActivityLevel, goalType: GoalType) -> Int {
        let tdee = calculateTDEE(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex, activityLevel: activityLevel)
        let target = tdee + goalType.calorieAdjustment

        // Floor: never below BMR or 1200, whichever is higher
        let bmr = Int(calculateBMR(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex))
        return max(max(1200, bmr), target)
    }

    // MARK: - Macros (body-weight-based, evidence-backed)
    //
    // Protein: g per kg of body weight (varies by goal)
    // Fat: g per kg of body weight (minimum floor for hormonal health)
    // Carbs: remaining calories after protein + fat

    static func calculateMacros(
        targetCalories: Int,
        goalType: GoalType,
        weightKg: Double
    ) -> (protein: Int, carbs: Int, fat: Int) {

        // 1. Protein — based on body weight and goal
        let proteinPerKg: Double = {
            switch goalType {
            case .lose:     return 2.0   // high protein preserves muscle during deficit
            case .toneUp:   return 2.0   // recomposition needs high protein
            case .maintain:  return 1.6   // standard healthy maintenance
            case .gain:     return 1.8   // surplus + muscle building
            case .bulk:     return 1.8   // surplus + muscle building
            case .athlete:  return 2.0   // high demands from training
            }
        }()
        let proteinGrams = Int(weightKg * proteinPerKg)
        let proteinCals = proteinGrams * 4

        // 2. Fat — minimum floor based on body weight, then goal-adjusted
        let fatPerKg: Double = {
            switch goalType {
            case .lose:     return 0.8   // lower but still safe
            case .toneUp:   return 0.8
            case .maintain:  return 1.0   // balanced
            case .gain:     return 0.9
            case .bulk:     return 0.9
            case .athlete:  return 0.9
            }
        }()
        let fatGrams = max(Int(weightKg * fatPerKg), 40) // never below 40g
        let fatCals = fatGrams * 9

        // 3. Carbs — fill remaining calories
        let remainingCals = max(0, targetCalories - proteinCals - fatCals)
        let carbGrams = remainingCals / 4

        // Safety: if protein + fat exceed calories, scale down fat first
        if proteinCals + fatCals > targetCalories {
            let adjustedFatCals = max(40 * 9, targetCalories - proteinCals)
            let adjustedFat = adjustedFatCals / 9
            let adjustedCarbs = max(0, targetCalories - proteinCals - adjustedFatCals) / 4
            return (proteinGrams, adjustedCarbs, adjustedFat)
        }

        return (proteinGrams, carbGrams, fatGrams)
    }

    // MARK: - Diet-aware macros

    static func calculateMacros(
        targetCalories: Int,
        goalType: GoalType,
        weightKg: Double,
        dietStyle: DietStyle
    ) -> (protein: Int, carbs: Int, fat: Int) {
        switch dietStyle {
        case .standard:
            return calculateMacros(targetCalories: targetCalories, goalType: goalType, weightKg: weightKg)

        case .highProtein:
            let proteinGrams = Int(weightKg * 2.2)
            let proteinCals = proteinGrams * 4
            let fatGrams = max(Int(weightKg * 0.8), 40)
            let fatCals = fatGrams * 9
            let carbGrams = max(0, targetCalories - proteinCals - fatCals) / 4
            return (proteinGrams, carbGrams, fatGrams)

        case .keto:
            let fatCals = Int(Double(targetCalories) * 0.70)
            let proteinCals = Int(Double(targetCalories) * 0.25)
            let carbCals = targetCalories - fatCals - proteinCals
            return (proteinCals / 4, carbCals / 4, fatCals / 9)

        case .vegetarian, .vegan:
            let proteinGrams = Int(weightKg * 1.5)
            let proteinCals = proteinGrams * 4
            let fatCals = Int(Double(targetCalories) * 0.25)
            let fatGrams = fatCals / 9
            let carbGrams = max(0, targetCalories - proteinCals - fatCals) / 4
            return (proteinGrams, carbGrams, fatGrams)

        case .mediterranean:
            let fatCals = Int(Double(targetCalories) * 0.35)
            let fatGrams = fatCals / 9
            let proteinGrams = Int(weightKg * 1.6)
            let proteinCals = proteinGrams * 4
            let carbGrams = max(0, targetCalories - proteinCals - fatCals) / 4
            return (proteinGrams, carbGrams, fatGrams)
        }
    }

    // MARK: - Timeline

    static func weeksToGoal(currentKg: Double, targetKg: Double, weeklyChangeKg: Double) -> Int {
        guard weeklyChangeKg > 0 else { return 0 }
        let diff = abs(currentKg - targetKg)
        return max(1, Int(ceil(diff / weeklyChangeKg)))
    }

    static func weeklyChangeKg(calorieDeficit: Int) -> Double {
        // 7700 kcal ≈ 1 kg of body weight
        return abs(Double(calorieDeficit)) * 7.0 / 7700.0
    }

    // MARK: - Legacy (percentage-based, kept for backward compat)

    static func calculateMacros(targetCalories: Int, goalType: GoalType) -> (protein: Int, carbs: Int, fat: Int) {
        // Default to 75kg if no weight available
        return calculateMacros(targetCalories: targetCalories, goalType: goalType, weightKg: 75)
    }
}
