import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const OPENFOODS_BASE = "https://world.openfoodfacts.org/api/v2/product"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function jsonResponse(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function errorResponse(userMessage: string, status = 400) {
  return jsonResponse({ error: userMessage }, status)
}

const ANALYSIS_JSON_FORMAT = `{"display_name":"string","items":[{"id":"uuid-v4","name":"string","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"fiber":0.0,"sugar":0.0,"serving_size":"string","estimated_grams":0.0,"measurement_unit":"string","measurement_amount":0.0,"confidence":0.00}],"total_calories":0,"total_protein":0.0,"total_carbs":0.0,"total_fat":0.0,"fiber_g":0.0,"sugar_g":0.0,"sodium_mg":0.0,"cholesterol_mg":0.0,"saturated_fat_g":0.0,"health_score":7,"health_score_reason":"string"}`

const PHOTO_ANALYSIS_PROMPT = `You are a USDA-certified clinical nutritionist with expert visual food assessment skills. Analyze this food photo with precision.

MEAL NAMING — CRITICAL:
- display_name MUST be a descriptive, specific title that identifies the dish (e.g. "Grilled Chicken Caesar Salad", "Chicken Teriyaki Rice Bowl", "Pepperoni Pizza Slice", "Açaí Bowl with Granola").
- NEVER use vague names like "Food", "Meal", "Plate", "Bowl". Be as specific as the food allows.
- If it's a recognizable dish, use its proper name. If it's a combination, describe the main components (e.g. "Steak with Mashed Potatoes & Asparagus").

INGREDIENT ITEMIZATION — CRITICAL:
- List EVERY visible ingredient as a SEPARATE item. A "Chicken Salad Bowl" must list: grilled chicken breast, romaine lettuce, spinach, cherry tomatoes, red onion, cucumber, croutons, Caesar dressing, etc.
- A burger must list: beef patty, bun (top + bottom), lettuce, tomato, onion, cheese, pickles, ketchup, mayo, etc.
- A bowl of pasta must list: pasta, sauce, cheese, any protein, any vegetables separately.
- Sauces, dressings, oils, and condiments are ALWAYS separate items — never skip them.
- Drinks visible in the photo are separate items.

MEASUREMENT PROTOCOL — CRITICAL:
- estimated_grams: weight in grams for each item (use visual references below).
- measurement_unit: the most natural unit for this food type:
  * Meats/proteins: "oz" (e.g. 4 oz chicken breast)
  * Grains/rice/pasta: "cup" (e.g. 1 cup cooked rice)
  * Vegetables/salad greens: "cup" (e.g. 2 cups mixed greens)
  * Sauces/dressings/oils: "tbsp" (e.g. 2 tbsp ranch dressing)
  * Bread/tortilla/bun: "piece" or "slice" (e.g. 1 slice bread)
  * Fruits: "piece", "cup", or "medium" (e.g. 1 medium banana)
  * Cheese: "oz" or "slice" (e.g. 1 slice cheddar)
  * Eggs: "large" (e.g. 2 large eggs)
  * Beverages: "fl oz" (e.g. 12 fl oz soda)
  * Nuts/seeds: "oz" (e.g. 1 oz almonds)
  * Butter/cream cheese: "tbsp" (e.g. 1 tbsp butter)
- measurement_amount: the numeric amount in that unit (e.g. 4.0 for "4 oz", 1.5 for "1.5 cups").

WEIGHT ESTIMATION (estimate grams FIRST, then derive calories):
- Standard dinner plate = 10-11" (25-28cm). Use plate size to gauge portions.
- Palm of hand ≈ 3-4oz (85-113g) cooked meat. Deck of cards ≈ 3oz.
- Fist ≈ 1 cup (240ml) — ~200g cooked rice/pasta, ~150g vegetables.
- Thumb tip ≈ 1 tsp (5ml), whole thumb ≈ 1 tbsp (15ml).

COUNTING PROTOCOL:
1. Count EVERY discrete item individually. 3 chicken strips = "3 chicken strips", not "chicken strips".
2. Look for overlapping/hidden items. Scan left-to-right, top-to-bottom.
3. When uncertain between N and N+1 items, choose N+1 (overcounting > undercounting).

USDA CALORIE ANCHORS:
Chicken breast grilled (4oz/113g): 187cal 35P 0C 4F | Salmon (4oz): 234cal 25P 0C 14F
White rice cooked (1 cup/186g): 206cal 4P 45C 0.4F | Pasta cooked (1 cup/140g): 220cal 8P 43C 1.3F
Mixed salad greens (2 cups): 15cal 1P 2C 0.2F | Broccoli (1 cup/91g): 31cal 3P 6C 0.3F
Pizza slice large cheese: 285cal 12P 36C 10F | French fries medium (117g): 365cal 4P 44C 19F
Olive oil (1 tbsp): 119cal 0P 0C 14F | Butter (1 tbsp): 100cal 0P 0C 12F
Ranch dressing (2 tbsp): 130cal 0P 2C 13F | Caesar dressing (2 tbsp): 150cal 1P 1C 16F

COOKING METHOD ADJUSTMENTS:
- Golden/crispy → fried (+30-50% cal, +5-15g fat per item)
- Glistening/shiny → oiled or buttered (+40-120 cal per visible tbsp)
- Creamy/white sauce → cream-based (150-200 cal per ¼ cup)

COMPOUND FOODS:
- If contents of a wrapped food (burrito, wrap, dumpling) are not visible, assume standard recipe and list probable components separately.
  * Burrito: 12" flour tortilla + 4oz protein + 1 cup rice + 0.5 cup beans + cheese + salsa ≈ 650 cal
  * Sandwich: 2 bread slices + 3oz deli meat + cheese + lettuce + condiments ≈ 400 cal
- If multiple identical items (3 cookies, 2 tacos), list as ONE item with measurement_amount reflecting count.

DEFAULT PORTIONS (when no size reference is visible):
- Protein: 4 oz (113g) cooked
- Cooked grains (rice/pasta): 1 cup (186-200g)
- Vegetables: 1 cup (150g)
- Salad greens: 2 cups (80g)
- Sauce/dressing: 2 tbsp (30g)
- Beverage: 12 fl oz (355ml)

ESTIMATION ORDER:
1. FIRST identify if restaurant or home-cooked. Restaurant = 1.5-2× home portions.
2. THEN estimate grams/amounts using visual references above.
3. THEN derive calories from USDA anchors.
4. FINALLY add 5-10% buffer for hidden oils/cooking fats.

ACCURACY RULES:
1. Validate: P×4 + C×4 + F×9 should ≈ total_calories (±15%). If off, adjust carbs to close the gap.
2. health_score = 1-10 (10=very healthy). health_score_reason = one sentence why.
3. Include fiber and sugar per item. Include total fiber_g, sugar_g, sodium_mg, cholesterol_mg, saturated_fat_g.
4. confidence: a float from 0.0 (very uncertain) to 1.0 (very certain). Use 0.85+ only when food is clearly identifiable.

NON-FOOD IMAGES:
If the image does NOT contain food (random objects, pets, people, text), respond with:
{"display_name":"Not a food item","items":[],"total_calories":0,"total_protein":0,"total_carbs":0,"total_fat":0,"fiber_g":0,"sugar_g":0,"sodium_mg":0,"cholesterol_mg":0,"saturated_fat_g":0,"health_score":null,"health_score_reason":null}

RESPOND ONLY IN THIS JSON FORMAT: ${ANALYSIS_JSON_FORMAT}`

const TEXT_ANALYSIS_PROMPT = `You are a USDA-certified clinical nutritionist. Estimate nutrition for the described food with precision.

SCOPE — ABSOLUTELY CRITICAL:
- ONLY analyze the food items the user explicitly described. Do NOT add sides, drinks, or extras unless the user mentioned them.
- If the user says "In-N-Out burger", analyze ONLY the burger — do NOT add fries, soda, or a shake.
- If the user says "chicken salad", analyze ONLY the chicken salad — do NOT add bread, a drink, or dessert.
- If the user says "burger and fries", THEN include both the burger and fries.
- The user's description is the COMPLETE list of what to analyze. Never assume they had more than what they said.

MEAL NAMING — CRITICAL:
- display_name MUST be descriptive and specific (e.g. "Grilled Chicken Caesar Salad", "In-N-Out Double-Double Burger", "Chipotle Chicken Burrito Bowl").
- NEVER use vague names like "Food", "Meal", "Dish". Be as specific as the food allows.

INGREDIENT ITEMIZATION — CRITICAL:
- List EVERY component OF THE DESCRIBED FOOD as a SEPARATE item. Users must be able to remove/adjust any ingredient.
- A "chicken burrito" must list: flour tortilla, seasoned chicken, cilantro lime rice, black beans, cheese, pico de gallo, sour cream, guacamole.
- A "Big Mac" must list: beef patties (2), special sauce, lettuce, American cheese (2 slices), pickles, onions, sesame seed bun.
- A "chicken salad bowl" must list: grilled chicken breast, romaine lettuce, spinach, cherry tomatoes, cucumber, red onion, croutons, dressing.
- Sauces, dressings, oils, condiments that are PART of the described dish are ALWAYS separate items — never skip them.
- Only include drinks if the user explicitly mentioned a drink.

RESTAURANT & BRAND RECOGNITION — CRITICAL:
- If the user mentions a restaurant or brand (Chipotle, McDonald's, Starbucks, In-N-Out, Chick-fil-A, etc.), use that restaurant's ACTUAL published nutrition data and standard recipe.
- Match the restaurant's real menu item names and portions.
- Still itemize into separate ingredients so users can customize (remove cheese, no mayo, etc.).

MEASUREMENT PROTOCOL:
- estimated_grams: weight in grams for each item.
- measurement_unit: the most natural unit for this food type:
  * Meats/proteins: "oz" (e.g. 4 oz chicken breast)
  * Grains/rice/pasta: "cup" (e.g. 1 cup cooked rice)
  * Vegetables/salad greens: "cup" (e.g. 2 cups mixed greens)
  * Sauces/dressings/oils: "tbsp" (e.g. 2 tbsp ranch dressing)
  * Bread/tortilla/bun: "piece" or "slice" (e.g. 1 slice bread)
  * Cheese: "oz" or "slice" (e.g. 1 slice cheddar)
  * Eggs: "large" (e.g. 2 large eggs)
  * Beverages: "fl oz" (e.g. 12 fl oz soda)
  * Nuts/seeds: "oz" (e.g. 1 oz almonds)
  * Butter/cream cheese: "tbsp" (e.g. 1 tbsp butter)
- measurement_amount: numeric amount in that unit.

COMPOUND FOODS: If a dish has sub-components (burrito, sandwich, bowl, burger), ALWAYS list each component separately. Use standard recipes when contents aren't specified:
- Burrito: flour tortilla + protein + rice + beans + cheese + salsa + sour cream
- Burger: bun + patty + lettuce + tomato + onion + pickles + cheese + condiments
- Sandwich: bread + protein + cheese + veggies + condiments
- Salad bowl: greens + protein + toppings + dressing
- Pasta dish: pasta + sauce + protein + cheese

DEFAULT PORTIONS: Protein: 4oz (113g), Grains: 1 cup cooked, Vegetables: 1 cup, Salad greens: 2 cups, Sauce/dressing: 2 tbsp, Drinks: 12 fl oz, Cheese: 1 oz.

USDA CALORIE ANCHORS:
Chicken breast grilled (4oz/113g): 187cal 35P 0C 4F | Salmon (4oz): 234cal 25P 0C 14F
White rice cooked (1 cup/186g): 206cal 4P 45C 0.4F | Pasta cooked (1 cup/140g): 220cal 8P 43C 1.3F
Mixed salad greens (2 cups): 15cal 1P 2C 0.2F | Broccoli (1 cup/91g): 31cal 3P 6C 0.3F
Olive oil (1 tbsp): 119cal 0P 0C 14F | Ranch dressing (2 tbsp): 130cal 0P 2C 13F

ACCURACY RULES:
1. Use specified quantity exactly, or assume standard serving.
2. Restaurant/brands = published data where available.
3. Account for cooking oils/butter/sauces (add as separate items).
4. Validate: P×4 + C×4 + F×9 ≈ total_calories (±15%). If off, adjust carbs.
5. health_score = 1-10 (10=very healthy). health_score_reason = one sentence why.
6. Include fiber and sugar per item. Include total fiber_g, sugar_g, sodium_mg, cholesterol_mg, saturated_fat_g.
7. confidence: float 0.0-1.0. Use 0.85+ only when food is well-known or brand-specific.

RESPOND ONLY IN THIS JSON FORMAT: ${ANALYSIS_JSON_FORMAT}`

// Max base64 image size: ~2.7MB (client compresses to 1.5MB JPEG → ~2MB base64, with headroom)
const MAX_IMAGE_SIZE = 2.7 * 1024 * 1024
const MAX_QUERY_LENGTH = 500

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Auth REQUIRED — verify via Supabase (signature-verified, not just decoded)
    const authHeader = req.headers.get("Authorization")
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return errorResponse("Authentication required", 401)
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return errorResponse("Authentication required. Please sign in.", 401)
    }

    console.log("Authenticated request from user:", user.id)

    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")
    if (!ANTHROPIC_API_KEY) {
      return errorResponse("Service temporarily unavailable", 503)
    }

    let body: any
    try {
      body = await req.json()
    } catch {
      return errorResponse("Invalid request body")
    }
    const { image, query, barcode, request_type } = body

    if (request_type === "barcode" && barcode) {
      // Validate barcode format: 8-15 digits only
      const safeBarcode = String(barcode).replace(/\D/g, "")
      if (safeBarcode.length < 8 || safeBarcode.length > 15) {
        return errorResponse("Invalid barcode format")
      }
      return await handleBarcode(safeBarcode, ANTHROPIC_API_KEY)
    }

    if (request_type === "photo" && image) {
      if (typeof image !== "string" || image.length > MAX_IMAGE_SIZE) {
        return errorResponse("Image too large. Please use a smaller photo.")
      }
      return await handlePhoto(image, ANTHROPIC_API_KEY)
    }

    if (request_type === "text" && query) {
      const safeQuery = typeof query === "string" ? query.trim().slice(0, MAX_QUERY_LENGTH) : ""
      if (!safeQuery) {
        return errorResponse("Please describe the food you'd like to log.")
      }
      return await handleText(safeQuery, ANTHROPIC_API_KEY)
    }

    return errorResponse("Invalid request. Please provide an image, text, or barcode.")
  } catch (error) {
    console.error("analyze-food error:", error)
    return errorResponse("Food analysis failed. Please try again.", 500)
  }
})

// Valid measurement units — normalize typos and variations to canonical form
const VALID_UNITS = new Set(["oz", "cup", "tbsp", "tsp", "piece", "slice", "g", "ml", "fl oz", "large", "medium", "small"])
const UNIT_ALIASES: Record<string, string> = {
  "ounce": "oz", "ounces": "oz", "ozs": "oz",
  "cups": "cup", "tablespoon": "tbsp", "tablespoons": "tbsp",
  "teaspoon": "tsp", "teaspoons": "tsp",
  "pieces": "piece", "slices": "slice", "pc": "piece", "pcs": "piece",
  "gram": "g", "grams": "g", "milliliter": "ml", "milliliters": "ml",
  "fluid oz": "fl oz", "fluid ounce": "fl oz", "fl ounce": "fl oz",
  "whole": "piece", "each": "piece", "serving": "piece",
}

function normalizeMeasurementUnit(raw: string | undefined): string {
  if (!raw || typeof raw !== "string") return "g"
  const lower = raw.trim().toLowerCase()
  if (VALID_UNITS.has(lower)) return lower
  if (UNIT_ALIASES[lower]) return UNIT_ALIASES[lower]
  return "g" // unknown → fall back to grams
}

function validateAndFixResponse(parsed: any): any {
  if (!parsed.items || !Array.isArray(parsed.items)) {
    throw new Error("Invalid AI response structure")
  }
  if (parsed.items.length === 0 && (parsed.total_calories || 0) === 0) {
    throw new Error("AI could not identify any food items from the input")
  }

  parsed.items = parsed.items.map((item: any) => {
    const cal = Number(item.calories) || 0
    const p = Number(item.protein) || 0
    const c = Number(item.carbs) || 0
    const f = Number(item.fat) || 0
    const conf = Number(item.confidence) || 0.7
    const fib = Number(item.fiber) || 0
    const sug = Number(item.sugar) || 0
    const eg = Number(item.estimated_grams) || 0
    const ma = Number(item.measurement_amount) || 1.0
    return {
      id: item.id && isValidUUID(item.id) ? item.id : crypto.randomUUID(),
      name: typeof item.name === "string" ? item.name.slice(0, 200) : "Unknown item",
      calories: Math.max(0, Math.round(isFinite(cal) ? cal : 0)),
      protein: Math.max(0, Math.round((isFinite(p) ? p : 0) * 10) / 10),
      carbs: Math.max(0, Math.round((isFinite(c) ? c : 0) * 10) / 10),
      fat: Math.max(0, Math.round((isFinite(f) ? f : 0) * 10) / 10),
      fiber: Math.max(0, Math.round((isFinite(fib) ? fib : 0) * 10) / 10),
      sugar: Math.max(0, Math.round((isFinite(sug) ? sug : 0) * 10) / 10),
      serving_size: (item.serving_size || "1 serving").slice(0, 100),
      estimated_grams: Math.max(0, Math.round((isFinite(eg) ? eg : 0) * 10) / 10),
      measurement_unit: normalizeMeasurementUnit(item.measurement_unit),
      measurement_amount: Math.max(0, Math.round((isFinite(ma) ? ma : 1.0) * 10) / 10),
      confidence: Math.min(1, Math.max(0, isFinite(conf) ? conf : 0.7)),
    }
  })

  parsed.total_calories = parsed.items.reduce((sum: number, i: any) => sum + i.calories, 0)
  parsed.total_protein = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.protein, 0) * 10) / 10
  parsed.total_carbs = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.carbs, 0) * 10) / 10
  parsed.total_fat = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.fat, 0) * 10) / 10

  // Macro math validation: P*4 + C*4 + F*9 should ≈ total_calories (±15%)
  const macroSum = parsed.total_protein * 4 + parsed.total_carbs * 4 + parsed.total_fat * 9
  if (parsed.total_calories > 0 && macroSum > 0) {
    const ratio = macroSum / parsed.total_calories
    if (ratio < 0.85 || ratio > 1.15) {
      // Adjust carbs to close the gap (carbs are most commonly misestimated)
      const carbsCorrection = (parsed.total_calories - (parsed.total_protein * 4 + parsed.total_fat * 9)) / 4
      if (carbsCorrection > 0) {
        // Distribute correction proportionally across items
        const oldTotalCarbs = parsed.total_carbs
        if (oldTotalCarbs > 0) {
          const scale = carbsCorrection / oldTotalCarbs
          for (const item of parsed.items) {
            item.carbs = Math.round(item.carbs * scale * 10) / 10
          }
        }
        parsed.total_carbs = Math.round(carbsCorrection * 10) / 10
      }
    }
  }

  // Micronutrient totals — pass through from AI or sum from items
  const safeNum = (v: any) => { const n = Number(v); return isFinite(n) ? Math.round(n * 10) / 10 : 0 }
  parsed.fiber_g = safeNum(parsed.fiber_g) || Math.round(parsed.items.reduce((s: number, i: any) => s + (Number(i.fiber) || 0), 0) * 10) / 10
  parsed.sugar_g = safeNum(parsed.sugar_g) || Math.round(parsed.items.reduce((s: number, i: any) => s + (Number(i.sugar) || 0), 0) * 10) / 10
  parsed.sodium_mg = safeNum(parsed.sodium_mg)
  parsed.cholesterol_mg = safeNum(parsed.cholesterol_mg)
  parsed.saturated_fat_g = safeNum(parsed.saturated_fat_g)

  // Health score (1-10)
  const hs = Number(parsed.health_score)
  parsed.health_score = (isFinite(hs) && hs >= 1 && hs <= 10) ? Math.round(hs) : null
  parsed.health_score_reason = typeof parsed.health_score_reason === "string" ? parsed.health_score_reason.slice(0, 300) : null

  // Display name: use AI's name or join item names, cap length
  const rawName = parsed.display_name || parsed.items.map((i: any) => i.name).join(" & ")
  parsed.display_name = typeof rawName === "string" ? rawName.slice(0, 100) : "Food"

  return parsed
}

function isValidUUID(str: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
}

function parseAIResponse(text: string): any {
  let cleaned = text.trim()
  cleaned = cleaned.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim()

  // Use balanced-brace extraction instead of greedy regex
  const start = cleaned.indexOf("{")
  if (start === -1) {
    throw new Error("Could not parse AI response: no JSON object found")
  }

  let depth = 0
  let end = -1
  for (let i = start; i < cleaned.length; i++) {
    if (cleaned[i] === "{") depth++
    else if (cleaned[i] === "}") {
      depth--
      if (depth === 0) { end = i; break }
    }
  }

  if (end === -1) {
    throw new Error("Could not parse AI response: unbalanced braces")
  }

  const jsonStr = cleaned.substring(start, end + 1)
  try {
    return JSON.parse(jsonStr)
  } catch (e) {
    throw new Error(`Invalid JSON in AI response: ${(e as Error).message}`)
  }
}

async function safeJsonParse(response: globalThis.Response, label: string): Promise<any> {
  const text = await response.text()
  try {
    return JSON.parse(text)
  } catch {
    console.error(`${label}: non-JSON response (status ${response.status}):`, text.slice(0, 200))
    throw new Error(`${label} returned invalid response`)
  }
}

// Fetch with timeout + retry (2 attempts, exponential backoff)
async function fetchWithRetry(url: string, options: RequestInit, label: string, timeoutMs = 25000, maxAttempts = 2): Promise<globalThis.Response> {
  let lastError: Error | null = null
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const controller = new AbortController()
      const timeout = setTimeout(() => controller.abort(), timeoutMs)
      const response = await fetch(url, { ...options, signal: controller.signal })
      clearTimeout(timeout)
      // Retry on 429/5xx
      if ((response.status === 429 || response.status >= 500) && attempt < maxAttempts - 1) {
        const delay = (attempt + 1) * 1000 + Math.random() * 500
        console.warn(`${label}: status ${response.status}, retrying in ${Math.round(delay)}ms...`)
        await new Promise(r => setTimeout(r, delay))
        continue
      }
      return response
    } catch (e) {
      lastError = e as Error
      if ((e as Error).name === "AbortError") {
        console.error(`${label}: timed out after ${timeoutMs}ms (attempt ${attempt + 1}/${maxAttempts})`)
      } else {
        console.error(`${label}: fetch error (attempt ${attempt + 1}/${maxAttempts}):`, (e as Error).message)
      }
      if (attempt < maxAttempts - 1) {
        const delay = (attempt + 1) * 1000 + Math.random() * 500
        await new Promise(r => setTimeout(r, delay))
      }
    }
  }
  throw lastError || new Error(`${label} failed after ${maxAttempts} attempts`)
}

async function handlePhoto(base64Image: string, apiKey: string): Promise<Response> {
  const response = await fetchWithRetry(
    "https://api.anthropic.com/v1/messages",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 2048,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: base64Image,
                },
              },
              { type: "text", text: PHOTO_ANALYSIS_PROMPT },
            ],
          },
        ],
      }),
    },
    "Anthropic photo API",
    25000, // 25s timeout
  )

  const data = await safeJsonParse(response, "Anthropic photo API")

  if (!response.ok) {
    console.error("Anthropic photo API error:", response.status, data?.error?.type, data?.error?.message)
    return errorResponse("Photo analysis failed. Please try again.", 502)
  }

  if (!data.content?.[0]?.text) {
    throw new Error("Empty AI response")
  }

  const parsed = parseAIResponse(data.content[0].text)
  const validated = validateAndFixResponse(parsed)

  return jsonResponse(validated)
}

async function handleText(query: string, apiKey: string): Promise<Response> {
  const response = await fetchWithRetry(
    "https://api.anthropic.com/v1/messages",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 2048,
        messages: [
          {
            role: "user",
            content: `${TEXT_ANALYSIS_PROMPT}\n\nThe user described: ${JSON.stringify(query)}\n\nEstimate the nutrition for this food/meal as accurately as possible.`,
          },
        ],
      }),
    },
    "Anthropic text API",
    25000,
  )

  const data = await safeJsonParse(response, "Anthropic text API")

  if (!response.ok) {
    console.error("Anthropic text API error:", response.status, data?.error?.type)
    throw new Error("Text analysis failed")
  }

  if (!data.content?.[0]?.text) {
    throw new Error("Empty AI response")
  }

  const parsed = parseAIResponse(data.content[0].text)
  const validated = validateAndFixResponse(parsed)

  return jsonResponse(validated)
}

async function handleBarcode(barcode: string, apiKey: string): Promise<Response> {
  try {
    const response = await fetch(`${OPENFOODS_BASE}/${barcode}.json`)

    if (response.ok) {
      const data = await response.json()
      const product = data.product

      if (product && product.nutriments) {
        const n = product.nutriments
        const servingSize = product.serving_size || "1 serving"
        const productName = product.product_name || "Scanned Product"

        // Use ?? via nullish coalescing to avoid JS || treating 0 as falsy
        const hasServing = n["energy-kcal_serving"] != null && n["energy-kcal_serving"] > 0
        const cals = Math.round(hasServing ? (n["energy-kcal_serving"] ?? 0) : (n["energy-kcal_100g"] ?? 0))
        const protein = Math.round((hasServing ? (n.proteins_serving ?? 0) : (n.proteins_100g ?? 0)) * 10) / 10
        const carbs = Math.round((hasServing ? (n.carbohydrates_serving ?? 0) : (n.carbohydrates_100g ?? 0)) * 10) / 10
        const fat = Math.round((hasServing ? (n.fat_serving ?? 0) : (n.fat_100g ?? 0)) * 10) / 10
        const fiber = Math.round((hasServing ? (n.fiber_serving ?? 0) : (n.fiber_100g ?? 0)) * 10) / 10
        const sugar = Math.round((hasServing ? (n.sugars_serving ?? 0) : (n.sugars_100g ?? 0)) * 10) / 10
        const sodium = Math.round((hasServing ? (n.sodium_serving ?? 0) : (n.sodium_100g ?? 0)) * 1000 * 10) / 10 // g → mg

        // Accept zero-calorie products (water, diet drinks) if we have a product name
        if (cals >= 0 && productName !== "Scanned Product") {
          const result = {
            display_name: productName,
            items: [
              {
                id: crypto.randomUUID(),
                name: productName,
                calories: cals,
                protein,
                carbs,
                fat,
                fiber,
                sugar,
                serving_size: servingSize,
                confidence: 0.95,
              },
            ],
            total_calories: cals,
            total_protein: protein,
            total_carbs: carbs,
            total_fat: fat,
            fiber_g: fiber,
            sugar_g: sugar,
            sodium_mg: sodium,
          }

          const validated = validateAndFixResponse(result)
          return jsonResponse(validated)
        }
      }
    }
  } catch {
    // Fall through to AI lookup
  }

  return await handleText(`Nutrition for the product with barcode ${barcode}. If you recognize this barcode, provide accurate nutrition data. Otherwise provide your best estimate.`, apiKey)
}
