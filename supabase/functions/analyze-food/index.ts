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

const ANALYSIS_JSON_FORMAT = `{"display_name":"string","items":[{"id":"uuid-v4","name":"string","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size":"string","confidence":0.00}],"total_calories":0,"total_protein":0.0,"total_carbs":0.0,"total_fat":0.0}`

const PHOTO_ANALYSIS_PROMPT = `You are a USDA-certified clinical nutritionist. Analyze this food photo with precision.

SCAN PROTOCOL: Scan entire image systematically — center, edges, background, containers, drinks. Identify EVERY distinct food/drink. When multiple foods share a plate, list each separately. Count discrete items precisely (3 strips, 2 tacos). Include ALL sauces, condiments, dressings, toppings.

WEIGHT-FIRST METHOD: For each item, estimate weight in grams FIRST using visual cues, then derive calories. Plate ~10in diameter. Palm ~4oz/113g meat. Fist ~1 cup/240ml. Thickness: thin breast 3-4oz, thick 6-8oz. Bowl of rice/pasta: 1-1.5 cups cooked.

COOKING ADJUSTMENTS: Grill marks=grilled (base). Golden/crispy=fried (+30-50% cal). Glistening=oiled (+40-120cal/tbsp). Creamy sauce: 150-200cal/¼cup.

HIDDEN CALORIES: Oil 120cal/tbsp, butter 100cal/tbsp, cheese slice 70cal, ranch 130cal/2tbsp, mayo 100cal/tbsp, bun 140cal, soda 140cal/12oz.

ANCHORS: chicken breast 4oz: 187cal 35P 0C 4F, rice 1cup: 206cal 4P 45C 0.4F, pizza slice: 285cal, egg: 72cal, pasta 1cup: 220cal, salmon 4oz: 234cal, fries med: 365cal, burger patty ¼lb: 290cal.

RULES: Always give definitive numbers. Slight overestimate (5-10%) preferred. Validate P×4+C×4+F×9 ≈ calories. Restaurant = 1.5-2x home. Read nutrition labels exactly if visible. Non-food → name: "Not a food item", calories: 0, confidence: 0.1. Confidence: 0.9+ clear, 0.75-0.89 common, 0.6-0.74 mixed, 0.4-0.59 blurry.
RESPOND ONLY IN THIS JSON FORMAT: ${ANALYSIS_JSON_FORMAT}`

const TEXT_ANALYSIS_PROMPT = `Expert nutritionist. Estimate nutrition for the described food using USDA data.
Rules: Use specified quantity exactly, or assume standard serving. Be specific about serving_size. Restaurant/brands = published data. Combo foods = separate items. Account for cooking oils/butter/sauces. Validate: P×4+C×4+F×9 ≈ calories.
RESPOND ONLY IN THIS JSON FORMAT: ${ANALYSIS_JSON_FORMAT}`

// Max base64 image size: ~2.7MB (client compresses to 1.5MB JPEG → ~2MB base64, with headroom)
const MAX_IMAGE_SIZE = 2.7 * 1024 * 1024
const MAX_QUERY_LENGTH = 500

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return errorResponse("Authentication required", 401)
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return errorResponse("Session expired. Please sign in again.", 401)
    }

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

function validateAndFixResponse(parsed: any): any {
  if (!parsed.items || !Array.isArray(parsed.items)) {
    throw new Error("Invalid AI response structure")
  }

  parsed.items = parsed.items.map((item: any) => {
    const cal = Number(item.calories) || 0
    const p = Number(item.protein) || 0
    const c = Number(item.carbs) || 0
    const f = Number(item.fat) || 0
    const conf = Number(item.confidence) || 0.7
    return {
      id: item.id && isValidUUID(item.id) ? item.id : crypto.randomUUID(),
      name: item.name || "Unknown item",
      calories: Math.max(0, Math.round(isFinite(cal) ? cal : 0)),
      protein: Math.max(0, Math.round((isFinite(p) ? p : 0) * 10) / 10),
      carbs: Math.max(0, Math.round((isFinite(c) ? c : 0) * 10) / 10),
      fat: Math.max(0, Math.round((isFinite(f) ? f : 0) * 10) / 10),
      serving_size: item.serving_size || "1 serving",
      confidence: Math.min(1, Math.max(0, isFinite(conf) ? conf : 0.7)),
    }
  })

  parsed.total_calories = parsed.items.reduce((sum: number, i: any) => sum + i.calories, 0)
  parsed.total_protein = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.protein, 0) * 10) / 10
  parsed.total_carbs = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.carbs, 0) * 10) / 10
  parsed.total_fat = Math.round(parsed.items.reduce((sum: number, i: any) => sum + i.fat, 0) * 10) / 10

  parsed.display_name = parsed.display_name || parsed.items.map((i: any) => i.name).join(" & ")

  return parsed
}

function isValidUUID(str: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
}

function parseAIResponse(text: string): any {
  let cleaned = text.trim()
  cleaned = cleaned.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim()

  const jsonMatch = cleaned.match(/\{[\s\S]*\}/)
  if (!jsonMatch) {
    throw new Error("Could not parse AI response: no JSON object found")
  }

  try {
    return JSON.parse(jsonMatch[0])
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

async function handlePhoto(base64Image: string, apiKey: string): Promise<Response> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
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
  })

  const data = await safeJsonParse(response, "Anthropic photo API")

  if (!response.ok) {
    console.error("Anthropic photo API error:", response.status, data?.error?.type)
    throw new Error("Photo analysis failed")
  }

  if (!data.content?.[0]?.text) {
    throw new Error("Empty AI response")
  }

  const parsed = parseAIResponse(data.content[0].text)
  const validated = validateAndFixResponse(parsed)

  return jsonResponse(validated)
}

async function handleText(query: string, apiKey: string): Promise<Response> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
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
  })

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
                serving_size: servingSize,
                confidence: 0.95,
              },
            ],
            total_calories: cals,
            total_protein: protein,
            total_carbs: carbs,
            total_fat: fat,
          }

          return jsonResponse(result)
        }
      }
    }
  } catch {
    // Fall through to AI lookup
  }

  return await handleText(`Nutrition for the product with barcode ${barcode}. If you recognize this barcode, provide accurate nutrition data. Otherwise provide your best estimate.`, apiKey)
}
