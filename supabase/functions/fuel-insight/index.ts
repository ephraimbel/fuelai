import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return jsonResponse({ insight: "Your day is waiting." })
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return jsonResponse({ insight: "Your day is waiting." })
    }

    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")
    if (!ANTHROPIC_API_KEY) {
      return jsonResponse({ insight: "Your day is waiting." })
    }

    let data: any
    try {
      data = await req.json()
    } catch {
      return jsonResponse({ insight: "Your day is waiting." })
    }

    // Validate input — coerce to safe numeric strings
    const calories = Math.max(0, Math.min(99999, Number(data.calories) || 0))
    const targetCalories = Math.max(1, Math.min(99999, Number(data.target_calories) || 2000))
    const protein = Math.max(0, Math.min(9999, Number(data.protein) || 0))
    const targetProtein = Math.max(1, Math.min(9999, Number(data.target_protein) || 150))
    const carbs = Math.max(0, Math.min(9999, Number(data.carbs) || 0))
    const fat = Math.max(0, Math.min(9999, Number(data.fat) || 0))
    const mealCount = Math.max(0, Math.min(99, Number(data.meal_count) || 0))
    const goalType = typeof data.goal_type === "string" ? data.goal_type.slice(0, 20) : "maintain"

    const prompt = `Generate a single-sentence nutrition insight for today.

Data:
- Calories: ${calories} of ${targetCalories} target
- Protein: ${protein}g of ${targetProtein}g target
- Carbs: ${carbs}g
- Fat: ${fat}g
- Meals logged: ${mealCount}
- Goal: ${goalType}

Rules:
- ONE sentence only. Under 15 words.
- Be specific to the numbers. Never generic.
- Tone: calm, wise, direct. Like a mentor who respects your intelligence.
- If on track: acknowledge simply. "You're on pace." "Protein is strong today."
- If off track: state the gap and one action. "40g short on protein. Grab some eggs."
- If nothing logged: "Whenever you're ready." or "Your day is a blank canvas."
- NEVER use exclamation marks, emojis, or words like amazing/awesome/great.

Respond with ONLY the insight sentence, nothing else.`

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 20000)

    let response: Response
    try {
      response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-haiku-4-5-20251001",
          max_tokens: 64,
          messages: [{ role: "user", content: prompt }],
        }),
        signal: controller.signal,
      })
    } catch (fetchErr: unknown) {
      clearTimeout(timeoutId)
      const isAbort = fetchErr instanceof DOMException && fetchErr.name === "AbortError"
      console.error("Anthropic fetch error:", isAbort ? "timeout" : fetchErr)
      return jsonResponse({ insight: "Your day is waiting." })
    }
    clearTimeout(timeoutId)

    const result = await response.json()

    if (!response.ok || !result.content?.[0]?.text) {
      console.error("Anthropic API error:", response.status, result?.error?.type)
      return jsonResponse({ insight: "Your day is waiting." })
    }

    return jsonResponse({ insight: result.content[0].text.trim() })
  } catch (error) {
    console.error("fuel-insight error:", error)
    return jsonResponse({ insight: "Your day is waiting." })
  }
})
