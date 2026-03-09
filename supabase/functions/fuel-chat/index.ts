import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const FALLBACK_MSG = "Something went wrong on my end. Try asking again — I'm here to help with your nutrition."

function jsonResponse(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

const FUEL_PERSONALITY = `You are the nutrition coach inside "Fuel," a calorie-tracking app. You are a calm, direct, knowledgeable coach — not a chatbot.

VOICE: Warm but concise. 2-5 sentences typical, longer when coaching or explaining. No emojis, no exclamation marks. Never say: awesome, amazing, great job, oops, hey there. Use a confident, peer-to-peer tone — like a friend who happens to be a nutritionist.

CORE ROLE — NUTRITION COACH:
You don't just answer questions. You coach. When the user asks open-ended questions like "how can I improve," "any tips," "help me," "what should I do," or "how do I get better" — give them a personalized coaching response based on their data. Analyze their current intake vs targets, identify gaps, and give specific, actionable advice.

COACHING BEHAVIOR:
- Always reference the user's actual numbers when giving advice. "You're at 1400 of 2000 cal" is better than "track your calories."
- Identify patterns: Are they consistently low on protein? Eating too little early in the day? Overloading on carbs?
- Give specific food suggestions, not vague advice. "Add a Greek yogurt (150 cal, 15g protein) as a snack" beats "eat more protein."
- When they're on track, tell them what's working and why. When they're off track, tell them what to adjust without being preachy.
- Proactively mention what they should focus on next based on their remaining macros.
- If they have a streak going, acknowledge it naturally.

NUTRITION EXPERT:
Answer any question about food, nutrition, diets, cooking, supplements, fitness nutrition, or wellness. Lead with the direct answer. For general knowledge questions, give thorough, accurate information — then tie it back to their situation if relevant.

When asked about progress, use actual numbers. When asked what to eat, consider their macro gaps and suggest specific foods with approximate calories/macros.

Only redirect if completely off-topic (politics, coding, weather): "That's outside my lane — anything food-related I can help with?"`

interface Card {
  type: string
  tip_text?: string
}

function detectCards(userMessage: string, responseText: string): Card[] {
  const msg = userMessage.toLowerCase()
  const cards: Card[] = []

  if (/calori|how.*(am i|doing|going|look)|progress|remaining|left/.test(msg)) {
    cards.push({ type: "calorie_progress" })
  }

  if (/macro|protein|carb|fat|balance|nutrient|enough protein/.test(msg)) {
    cards.push({ type: "macro_breakdown" })
  }

  if (/what.*(eaten|eat|had|log)|meal|food.*today|review/.test(msg)) {
    cards.push({ type: "meal_log" })
  }

  // Extract actionable tip from response
  const tipMatch = responseText.match(/([^.!?]*(?:try |aim for |focus on |prioritize )[^.!?]*[.!?])/i)
  if (tipMatch) {
    cards.push({ type: "tip", tip_text: tipMatch[1].trim() })
  }

  return cards
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verify auth
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return jsonResponse({ message: "Please sign in to use the chat." })
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return jsonResponse({ message: "Session expired. Please sign in again.", error: "auth_expired" })
    }

    const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")
    if (!ANTHROPIC_API_KEY) {
      return jsonResponse({
        message: "I'm having trouble connecting right now. In the meantime — tell me what you ate today and I can help plan your next meal.",
      })
    }

    let body: any
    try {
      body = await req.json()
    } catch {
      return jsonResponse({ message: "Not sure I follow. Try asking about your calories, macros, or what to eat next." })
    }
    const { message, history, context } = body

    // Validate and sanitize input
    const safeMessage = typeof message === "string" ? message.slice(0, 2000) : ""
    if (!safeMessage.trim()) {
      return jsonResponse({ message: "Not sure I follow. Try asking about your calories, macros, or what to eat next." })
    }

    const ctx = context || {}
    const systemPrompt = `${FUEL_PERSONALITY}

USER CONTEXT:
- Goal: ${typeof ctx.goal_type === "string" ? ctx.goal_type.slice(0, 20) : "maintain"}
- Calorie target: ${Math.max(0, Number(ctx.target_calories) || 2000)} cal
- Protein target: ${Math.max(0, Number(ctx.target_protein) || 120)}g
- Today so far: ${Math.max(0, Number(ctx.today_calories) || 0)} cal, ${Math.max(0, Number(ctx.today_protein) || 0)}g protein, ${Math.max(0, Number(ctx.today_carbs) || 0)}g carbs, ${Math.max(0, Number(ctx.today_fat) || 0)}g fat
- Recent meals: ${typeof ctx.recent_meals === "string" ? ctx.recent_meals.slice(0, 500) : "none logged yet"}
- Current streak: ${Math.max(0, Number(ctx.streak) || 0)} days

COACHING NOTES:
- Calories remaining today: ${Math.max(0, (Number(ctx.target_calories) || 2000) - (Number(ctx.today_calories) || 0))} cal
- Protein remaining today: ${Math.max(0, (Number(ctx.target_protein) || 120) - (Number(ctx.today_protein) || 0))}g
- If they ask how to improve, what to do, or for advice — analyze their data and give specific, personalized guidance.`

    // Sanitize history — only allow valid roles, limit length
    const validRoles = new Set(["user", "assistant"])
    let safeHistory = Array.isArray(history)
      ? history
          .filter((h: any) => validRoles.has(h.role) && typeof h.content === "string")
          .slice(-6)
          .map((h: any) => ({ role: h.role, content: h.content.slice(0, 500) }))
      : []
    // Anthropic API requires messages to start with "user" role
    while (safeHistory.length > 0 && safeHistory[0].role !== "user") {
      safeHistory.shift()
    }

    const messages = [
      ...safeHistory,
      { role: "user", content: safeMessage },
    ]

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        temperature: 0.3,
        max_tokens: 512,
        system: systemPrompt,
        messages,
      }),
    })

    const data = await response.json()

    if (!response.ok || !data.content?.[0]?.text) {
      console.error("Anthropic API error:", response.status, data?.error?.type)
      return jsonResponse({
        message: "I'm having a brief connection issue. Check back in a moment — your tracking data is safe.",
      })
    }

    const responseText = data.content[0].text
    const cards = detectCards(safeMessage, responseText)

    return jsonResponse({
      message: responseText,
      cards: cards.length > 0 ? cards : undefined,
    })
  } catch (error: unknown) {
    console.error("fuel-chat error:", error)
    return jsonResponse({ message: FALLBACK_MSG })
  }
})
