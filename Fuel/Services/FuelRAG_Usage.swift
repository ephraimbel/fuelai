import Foundation
import UIKit

// ============================================================================
// FuelRAG_Usage.swift — Documentation & Usage Examples
// This file is for reference only. Safe to delete after reading.
// ============================================================================

/*
 ┌──────────────────────────────────────────────────────────────────────┐
 │                     FUEL RAG PIPELINE FLOW                         │
 │                                                                     │
 │  User Input                                                         │
 │  (text / photo)                                                     │
 │       │                                                             │
 │       ▼                                                             │
 │  ┌──────────────┐     ┌──────────────────┐     ┌────────────────┐  │
 │  │ NutritionRAG │────▶│  FoodDatabase    │────▶│ 501+ FoodItems │  │
 │  │  .retrieve() │     │  .shared.foods   │     │ with aliases,  │  │
 │  │  .score()    │     │                  │     │ macros, notes  │  │
 │  └──────┬───────┘     └──────────────────┘     └────────────────┘  │
 │         │                                                           │
 │         ▼                                                           │
 │  ┌──────────────┐     Top-K scored results                         │
 │  │ .buildContext│────▶ Formatted nutrition reference text           │
 │  └──────┬───────┘                                                   │
 │         │                                                           │
 │         ▼                                                           │
 │  ┌────────────────────┐                                            │
 │  │ClaudeNutrition     │  System prompt includes:                   │
 │  │Service             │  - Role & rules                            │
 │  │  .analyze()        │  - RAG context (injected)                  │
 │  │                    │  - Vision instructions (if image)          │
 │  │  POST to Claude API│  - JSON response schema                   │
 │  └──────┬─────────────┘                                            │
 │         │                                                           │
 │         ▼                                                           │
 │  ┌──────────────┐                                                  │
 │  │ NutritionAna │  Parsed JSON response with:                      │
 │  │ lysis struct │  calories, macros, items, confidence,            │
 │  │              │  warnings, health insight, calorie range         │
 │  └──────────────┘                                                  │
 └──────────────────────────────────────────────────────────────────────┘


 ═══════════════════════════════════════════════════════════════════════
  SETUP
 ═══════════════════════════════════════════════════════════════════════

 1. Set your API key at launch (NEVER hardcode in production):

    // In your AppDelegate or @main App init:
    ClaudeNutritionService.shared.apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""

    // Or load from Keychain / secure storage:
    ClaudeNutritionService.shared.apiKey = KeychainHelper.get("anthropic_api_key") ?? ""


 ═══════════════════════════════════════════════════════════════════════
  EXAMPLE 1: Simple Text Analysis
 ═══════════════════════════════════════════════════════════════════════

    Task {
        do {
            let analysis = try await ClaudeNutritionService.shared.analyze(
                description: "Chipotle chicken burrito bowl with rice, black beans, mild salsa, cheese, and guacamole"
            )
            print("Meal: \(analysis.mealName)")
            print("Calories: \(analysis.totalCalories)")
            print("Protein: \(analysis.proteinG)g | Carbs: \(analysis.carbsG)g | Fat: \(analysis.fatG)g")
            print("Confidence: \(analysis.confidence)")
            print("Range: \(analysis.calorieRange.low) - \(analysis.calorieRange.high) cal")
            for item in analysis.items {
                print("  - \(item.item): \(item.calories) cal (\(item.note))")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }


 ═══════════════════════════════════════════════════════════════════════
  EXAMPLE 2: Vision-Only Analysis
 ═══════════════════════════════════════════════════════════════════════

    // From camera or photo library:
    func analyzePhoto(_ image: UIImage) {
        Task {
            do {
                let analysis = try await ClaudeNutritionService.shared.analyze(image: image)
                print("Detected: \(analysis.mealName) — \(analysis.totalCalories) cal")
                if !analysis.warnings.isEmpty {
                    print("Warnings: \(analysis.warnings.joined(separator: ", "))")
                }
            } catch {
                print("Vision analysis failed: \(error.localizedDescription)")
            }
        }
    }


 ═══════════════════════════════════════════════════════════════════════
  EXAMPLE 3: Vision + Description (Highest Accuracy)
 ═══════════════════════════════════════════════════════════════════════

    // Combining image with user-provided description for maximum accuracy:
    func analyzeWithContext(_ image: UIImage, description: String) {
        Task {
            do {
                let analysis = try await ClaudeNutritionService.shared.analyze(
                    image: image,
                    description: description // e.g. "homemade chicken stir fry with brown rice"
                )
                print("\(analysis.mealName): \(analysis.totalCalories) cal")
                print("Serving assumed: \(analysis.servingAssumed)")
                print("Health insight: \(analysis.healthInsight)")
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }


 ═══════════════════════════════════════════════════════════════════════
  EXAMPLE 4: SwiftUI ViewModel Pattern
 ═══════════════════════════════════════════════════════════════════════

    @MainActor
    class NutritionViewModel: ObservableObject {
        @Published var analysis: NutritionAnalysis?
        @Published var isLoading = false
        @Published var errorMessage: String?

        func analyzeText(_ description: String) {
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    analysis = try await ClaudeNutritionService.shared.analyze(description: description)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }

        func analyzeImage(_ image: UIImage) {
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    analysis = try await ClaudeNutritionService.shared.analyze(image: image)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }


 ═══════════════════════════════════════════════════════════════════════
  EXAMPLE 5: Direct RAG Inspection (Debugging / Testing)
 ═══════════════════════════════════════════════════════════════════════

    // Inspect what the RAG retrieves before sending to Claude:
    let results = NutritionRAG.shared.retrieve(query: "chipotle bowl with chicken")
    for (i, result) in results.prefix(5).enumerated() {
        print("\(i+1). \(result.food.name) — Score: \(result.score)")
        print("   Matched: \(result.matchedTerms.joined(separator: ", "))")
        print("   Cal: \(result.food.calories) | P: \(result.food.protein)g")
    }

    // Print full context string that gets injected into the prompt:
    let context = NutritionRAG.shared.contextForQuery("big mac and fries")
    print(context)


 ═══════════════════════════════════════════════════════════════════════
  DATABASE EXPANSION GUIDE
 ═══════════════════════════════════════════════════════════════════════

 To add a new food item, follow this exact pattern in FoodDatabase.swift:

    FoodItem(
        name: "Item Display Name",           // Title case, canonical name
        aliases: [                           // 6-10 aliases covering:
            "common name",                   //   - casual/slang names
            "brand name",                    //   - brand names (McDonald's, etc.)
            "misspelling",                   //   - common misspellings
            "cooking method variant",        //   - "grilled X", "baked X", "fried X"
            "cuisine descriptor",            //   - "chinese X", "thai X"
            "abbreviation"                   //   - "PB", "OJ", "CFA"
        ],
        serving: "1 cup cooked",             // Human-readable serving description
        servingGrams: 240,                   // Gram weight matching serving
        calories: 200,                       // USDA FoodData Central value
        protein: 10.0,
        carbs: 30.0,
        fat: 5.0,
        fiber: 2.0,
        sugar: 1.0,
        sodium: 300,                         // In milligrams
        category: .grain,                    // FoodCategory enum value
        subCategory: "rice",                 // Specific type within category
        tags: ["whole-grain", "asian"],       // Searchable tags
        notes: "Scaling info, cooking variations, restaurant vs home differences",
        confidence: .high                    // .high = USDA single ingredient
    )                                        // .medium = known recipes/restaurants
                                             // .low = highly variable dishes


 ═══════════════════════════════════════════════════════════════════════
  ACCURACY TIER EXPLANATION
 ═══════════════════════════════════════════════════════════════════════

 Confidence Levels:
 - .high   → USDA FoodData Central single-ingredient items (chicken breast,
              banana, olive oil). Accuracy within ±5%.
 - .medium → Known recipes with standardized preparation (restaurant menu items
              with published nutrition, well-known dishes). ±10-15%.
 - .low    → Highly variable dishes (homemade recipes, "grandma's casserole",
              dishes that vary wildly by restaurant). ±20-30%.

 The RAG scoring algorithm applies confidence multipliers:
 - .high   × 1.00 (no penalty)
 - .medium × 0.95 (slight penalty to prefer USDA data)
 - .low    × 0.85 (significant penalty)

 This means when a query matches both a USDA item and a variable restaurant
 dish, the USDA item will rank higher, giving Claude better reference data.
*/
