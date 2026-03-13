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

const FUEL_PERSONALITY = `You are the user's personal nutrition coach inside Fuel. You're not an AI assistant — you're their coach. Think of yourself like a knowledgeable friend who genuinely cares about their progress and knows their data inside and out.

HOW YOU TALK:
- Talk like a real person texting a friend, not like a formal assistant. Short, natural sentences. Contractions always ("you're" not "you are", "don't" not "do not").
- Keep responses tight — 2-4 sentences for simple questions, a bit longer when you're actually coaching through something.
- Never use emojis. Never say: "Great question!", "Absolutely!", "I'd be happy to help", "Here's the thing", "Let me break this down." Those are AI tells. Just talk.
- You can be direct. "You're short on protein today" is better than "It appears your protein intake may be below target."
- Show personality. Be encouraging without being cheesy. Be honest without being harsh. If they're crushing it, say so plainly. If they're off track, tell them what to do about it — don't lecture.
- Ask follow-up questions sometimes. "What are you thinking for dinner?" or "Have you been feeling hungry mid-afternoon?" makes it feel like a conversation, not a Q&A.

HOW YOU COACH:
- You know their numbers. Use them. "You've got about 600 cal and 40g protein left for dinner" is coaching. "Try to eat balanced meals" is not.
- Suggest real, specific foods — not categories. "A chicken thigh with roasted veggies would land you right on target" beats "consider a lean protein with vegetables."
- Read between the lines. If someone asks "what should I eat" they want you to look at their remaining macros and give them an actual meal idea, not a lesson on macronutrients.
- When they share what they ate, react naturally. Comment on what stood out, what was smart, or what they could tweak next time.
- If they have a streak going, mention it casually — "day 12, by the way" not "Congratulations on your 12-day streak!"
- Remember you're looking at their LIVE data. Reference their actual meals by name when relevant.
- When you have their 7-day history, USE IT. Spot patterns: "You've been under on protein 4 of the last 5 days" or "Your calories have been consistent all week — nice."
- When you know their most-logged foods, reference them: "You seem to like Greek yogurt — that'd close your protein gap today."

WHAT YOU KNOW:
- Everything about nutrition, food, diets, cooking, supplements, fitness nutrition, and wellness.
- You know real restaurant menus — major chains, fast food, fast casual. When suggesting orders, use REAL menu items with realistic calorie estimates.
- Lead with the direct answer to any question. Then connect it back to their situation if it's relevant.
- Be accurate. If you're not sure about specific nutritional data, say so rather than guessing.

BOUNDARIES:
- If they ask about something completely unrelated to food/health/fitness (politics, coding, etc.), just say "that's not really my area — but if you've got any food questions, I'm here."
- When the user mentions food they ate or want to log (like "I had a burger" or "log 2 eggs"), acknowledge it naturally in 1-2 sentences. Don't list calories — the app handles that.`

interface Card {
  type: string
  tip_text?: string
  food_query?: string
  meal_plan?: object
  restaurant_order?: object
  meal_edit?: object
  grocery_list?: object
  meal_prep?: object
  substitution?: object
  fridge_meal?: object
  streak_recovery?: object
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

  if (/what.*(eaten|eat|had|log)|food.*today|review/.test(msg) && !/plan|suggest|recommend|should.*eat|help.*order|grocery|shopping/.test(msg)) {
    cards.push({ type: "meal_log" })
  }

  // Food logging intent detection
  const foodLogPattern = /^(?:i (?:had|ate|just ate|just had|eaten)|(?:log|add|track) (?:a |an |my |the )?|(?:had|ate|eating|just ate) )/i
  const shortFoodDesc = /^\d+\s+\w|^(?:eggs?|toast|chicken|rice|salad|burger|pizza|sandwich|wrap|bowl|shake|protein bar|yogurt|oatmeal|banana|apple)\b/i
  if (foodLogPattern.test(userMessage) || (shortFoodDesc.test(userMessage) && userMessage.split(' ').length <= 10)) {
    // Don't trigger if it's clearly a question or a restaurant query
    if (!/\?|what|how|should|can|is|are|do|does|order|at a |i'm at/.test(msg)) {
      cards.push({ type: "food_log", food_query: userMessage })
    }
  }

  // Extract actionable tip from response
  const tipMatch = responseText.match(/([^.!?]*(?:try |aim for |focus on |prioritize )[^.!?]*[.!?])/i)
  if (tipMatch) {
    cards.push({ type: "tip", tip_text: tipMatch[1].trim() })
  }

  return cards
}

// Common restaurant chains for detection
const CHAIN_NAMES = [
  "chipotle", "mcdonald", "mcdonalds", "mcd's", "subway", "wendy", "wendys",
  "taco bell", "chick-fil-a", "chick fil a", "chickfila", "panda express",
  "in-n-out", "in n out", "innout", "five guys", "panera", "sweetgreen",
  "cava", "shake shack", "starbucks", "dunkin", "popeyes", "burger king",
  "kfc", "dominos", "domino's", "papa johns", "wingstop", "raising cane",
  "raising canes", "whataburger", "zaxby", "cookout", "portillo", "mod pizza",
  "blaze pizza", "noodles", "jersey mike", "firehouse", "jimmy john",
  "potbelly", "jason's deli", "jasons deli", "whole foods", "trader joe",
  "olive garden", "applebee", "chili's", "chilis", "outback", "red lobster",
  "cheesecake factory", "texas roadhouse", "cracker barrel", "ihop", "denny",
  "waffle house", "sonic", "arby", "arbys", "jack in the box", "carl's jr",
  "carls jr", "hardee", "el pollo loco", "wawa", "sheetz", "buc-ee",
  "tropical smoothie", "jamba", "smoothie king", "nandos", "nando's",
  "bonchon", "pei wei", "qdoba", "moe's", "del taco", "culver",
]

const GENERIC_RESTAURANT_TYPES = [
  "restaurant", "fast food", "diner", "steakhouse", "sushi place", "sushi bar",
  "pizza place", "pizzeria", "mexican", "chinese", "thai", "indian",
  "italian", "korean", "japanese", "bbq", "barbecue", "burger place",
  "burger joint", "cafe", "coffee shop", "bakery", "brunch", "buffet",
  "seafood", "vietnamese", "pho", "ramen", "gastropub", "food truck",
  "food court", "wing place", "chicken place", "taqueria", "bodega",
]

// Short chain names that could match common English words — require word boundaries
const AMBIGUOUS_CHAINS = new Set(["sonic", "noodles", "cookout", "cava", "mod pizza", "potbelly"])

function detectRestaurantIntent(msg: string): boolean {
  const lower = msg.toLowerCase()
  // Direct chain mentions (with word boundary check for ambiguous short names)
  if (CHAIN_NAMES.some(c => {
    if (AMBIGUOUS_CHAINS.has(c)) {
      return new RegExp(`\\b${c.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`).test(lower)
    }
    return lower.includes(c)
  })) return true
  // Generic restaurant type mentions
  if (GENERIC_RESTAURANT_TYPES.some(t => lower.includes(t))) return true
  // Intent patterns: "eating out", "going out to eat", "ordering from", "what should i get at"
  if (/(?:eating out|going out to eat|ordering from|order(?:ing)? at|what.*(?:order|get).*at|i'm at (?:a |an |the )|eating at|dinner at|lunch at|grabbing|picking up)/i.test(msg)) return true
  return false
}

function detectMealEditIntent(msg: string): boolean {
  return /(?:swap|replace|change|remove|take out|take off|add|switch|actually|update|edit|modify|make it|undo|change.*back|never ?mind.*(?:meal|edit|change)).*|(?:actually (?:that was|it was|i had)|(?:large|medium|small|extra) (?:not|instead)|less |more |without |no (?:more )?(?:cheese|sauce|bread|rice|dressing))/i.test(msg)
}

function detectGroceryIntent(msg: string): boolean {
  return /grocer|shopping list|what.*(?:buy|shop|get from.*store)|buy for (?:the )?week|meal prep (?:list|shop)|stock up|pantry|need to shop|store run|what do i need/i.test(msg)
}

function detectMealPrepIntent(msg: string): boolean {
  return /meal prep|batch cook|prep.*(?:week|days|ahead)|cook.*(?:bulk|advance|ahead)|prep.*plan|food prep|sunday.*prep|prep my|weekly.*prep/i.test(msg)
}

function detectSubstitutionIntent(msg: string): boolean {
  return /(?:swap|replace|substitute|instead of|alternative|switch).*(?:for|with|to)|what.*(?:instead|replace|swap|substitute)|low.?carb.*(?:swap|version|alternative)|healthier.*(?:option|version|alternative)|(?:keto|vegan|gluten.?free).*(?:swap|version|alternative)|what can i (?:eat|have) instead/i.test(msg)
}

function detectFridgeIntent(msg: string): boolean {
  return /(?:i have|i've got|i got|what.*make with|what.*cook with|work with).*(?:and|,|&)|(?:in my (?:fridge|pantry|kitchen|freezer))|(?:make (?:something|a meal|food) (?:with|from|using))|(?:only have|just have|all i have)/i.test(msg)
}

function detectRecoveryIntent(msg: string): boolean {
  return /(?:went over|cheat (?:day|meal)|binge|off track|over.*(?:calories|target|limit|budget)|under.*(?:calories|target)|broke.*streak|messed up.*(?:diet|food|eat|cal)|fell off.*(?:track|wagon|diet)|too much.*(?:food|eat|ate|cal)|recovery.*(?:plan|day|meal)|get back on track|compensate|damage control|fix.*yesterday|ate too|overate|blew it|blew my)/i.test(msg)
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
    const targetCal = Math.max(1200, Number(ctx.target_calories) || 2000)
    const targetProt = Math.max(40, Number(ctx.target_protein) || 120)
    const targetCarbs = Math.max(50, Number(ctx.target_carbs) || 200)
    const targetFat = Math.max(20, Number(ctx.target_fat) || 65)
    const todayCal = Math.max(0, Number(ctx.today_calories) || 0)
    const todayProt = Math.max(0, Number(ctx.today_protein) || 0)
    const todayCarbs = Math.max(0, Number(ctx.today_carbs) || 0)
    const todayFat = Math.max(0, Number(ctx.today_fat) || 0)
    const calRemaining = Math.max(0, targetCal - todayCal)
    const protRemaining = Math.max(0, targetProt - todayProt)
    const carbsRemaining = Math.max(0, targetCarbs - todayCarbs)
    const fatRemaining = Math.max(0, targetFat - todayFat)
    const streak = Math.max(0, Number(ctx.streak) || 0)
    const calPercent = targetCal > 0 ? Math.round((todayCal / targetCal) * 100) : 0
    const protPercent = targetProt > 0 ? Math.round((todayProt / targetProt) * 100) : 0
    const recentMeals = typeof ctx.recent_meals === "string" ? ctx.recent_meals.slice(0, 500) : ""
    const userName = typeof ctx.display_name === "string" && ctx.display_name.trim() ? ctx.display_name.trim().split(" ")[0] : ""
    const dietStyle = typeof ctx.diet_style === "string" ? ctx.diet_style : ""
    const goalType = typeof ctx.goal_type === "string" ? ctx.goal_type.slice(0, 20) : "maintain"
    const topFoods = typeof ctx.top_foods === "string" ? ctx.top_foods.slice(0, 500) : ""
    const weightTrend = typeof ctx.weight_trend === "string" ? ctx.weight_trend.slice(0, 100) : ""
    const todayMealsDetail = typeof ctx.today_meals_detail === "string" ? ctx.today_meals_detail.slice(0, 3000) : ""
    const yesterdayCal = Math.max(0, Number(ctx.yesterday_calories) || 0)
    const yesterdayTarget = Math.max(0, Number(ctx.yesterday_target) || 0)

    // Parse 7-day history
    let weekHistoryBlock = ""
    if (typeof ctx.week_history === "string") {
      try {
        const days = JSON.parse(ctx.week_history)
        if (Array.isArray(days) && days.length > 0) {
          weekHistoryBlock = "\n\nLAST 7 DAYS:\n" + days.map((d: any) =>
            `- ${d.date}: ${d.cal} cal (${d.on_target ? 'on target' : 'off target'}) | ${d.p}g P | ${d.c}g C | ${d.f}g F`
          ).join("\n")
        }
      } catch { /* ignore parse errors */ }
    }

    // ── Intent Detection (order matters — more specific first) ──
    const wantsMealPrep = detectMealPrepIntent(safeMessage)
    const wantsRestaurant = !wantsMealPrep && detectRestaurantIntent(safeMessage)
    // Substitution before mealEdit: "swap rice for cauliflower" = substitution, "swap the rice in my lunch" = mealEdit
    const wantsSubstitution = !wantsRestaurant && detectSubstitutionIntent(safeMessage)
    // MealEdit requires reference to a logged meal context AND meal-specific language (my, the, that, lunch, dinner, breakfast)
    const mealEditHasMealRef = /(?:my |the |that |from |in )(?:meal|lunch|dinner|breakfast|snack|order|sandwich|salad|bowl|wrap|burger|pizza|plate|burrito)|(?:last|latest|recent) (?:meal|log)|actually (?:that was|it was|i had)/i.test(safeMessage)
    const wantsMealEdit = !wantsSubstitution && !wantsRestaurant && detectMealEditIntent(safeMessage) && todayMealsDetail.length > 2 && mealEditHasMealRef
    const wantsFridgeMeal = !wantsRestaurant && !wantsMealEdit && !wantsSubstitution && detectFridgeIntent(safeMessage)
    const wantsRecovery = !wantsMealPrep && !wantsSubstitution && !wantsFridgeMeal && detectRecoveryIntent(safeMessage)
    const wantsGroceryList = !wantsMealPrep && detectGroceryIntent(safeMessage)
    const wantsMealPlan = !wantsMealPrep && !wantsFridgeMeal && /plan.*(?:day|meal|food|eat)|meal plan|what.*eat.*(?:all|whole|rest|today)|plan.*today/i.test(safeMessage)

    // ── Feature-Specific Instructions ──
    let featureInstruction = ""

    if (wantsMealPlan) {
      const alreadyEaten = todayCal > 0
      featureInstruction = `

MEAL PLAN REQUEST:
The user wants a meal plan. You MUST generate one — do NOT just describe their current stats or ask what they want. Jump straight into coaching and BUILD THE PLAN. After your conversational response (2-3 sentences MAX), output a JSON block on a new line wrapped in <meal_plan>...</meal_plan> tags with this exact structure:
{"meals":[{"meal_type":"Breakfast","name":"...","calories":N,"protein":N,"carbs":N,"fat":N,"description":"Brief 1-sentence description"}],"total_calories":N,"total_protein":N,"total_carbs":N,"total_fat":N}

RULES:
${alreadyEaten
  ? `- They've already eaten ${todayCal} cal today. Plan REMAINING meals to hit ~${targetCal} cal total for the day. Only include meals they still need (e.g., if it's afternoon, skip breakfast).`
  : `- Nothing logged yet — plan a full day at ${targetCal} cal. Don't mention they haven't logged anything. Just build the plan.`}
- Respect their diet style: ${dietStyle || 'standard'}
- Hit macro targets: ${targetProt}g protein, ${targetCarbs}g carbs, ${targetFat}g fat
${topFoods ? `- They frequently eat: ${topFoods}. Work these foods in when they fit — it feels personalized.` : "- No food history yet — build a solid plan with approachable, popular meals. You can ask what they like as a follow-up."}
- Include 3-4 meals (breakfast, lunch, dinner, optional snack)
- Use SPECIFIC foods with realistic portions — "Grilled chicken breast (6oz) with brown rice and steamed broccoli", not "a lean protein with vegetables"
- Each meal's macros must add up correctly to the totals
- Your conversational text should be SHORT and coach-like ("Here's a solid day for you" or "Built this around your protein target"). The plan card does the heavy lifting.
- ALWAYS output the <meal_plan> JSON. Do NOT skip it.`
    } else if (wantsRestaurant) {
      featureInstruction = `

RESTAURANT ORDER REQUEST:
The user wants help ordering at a restaurant. After your conversational response (2-3 sentences MAX — be brief, the card shows the details), output a JSON block in <restaurant_order>...</restaurant_order> tags:
{"restaurant":"Restaurant Name","items":[{"name":"Menu item name","modifications":["no sour cream","extra lettuce"],"calories":N,"protein":N,"carbs":N,"fat":N}],"total_calories":N,"total_protein":N,"total_carbs":N,"total_fat":N,"food_query":"natural description for logging, e.g. Chipotle chicken burrito bowl"}

RULES:
- They have ${calRemaining} cal and ${protRemaining}g protein remaining today
${dietStyle ? `- Diet style: ${dietStyle}` : ''}
- Suggest a SPECIFIC order using REAL menu items from that restaurant
- Include modifications that optimize for their macros (e.g., "no tortilla" saves carbs, "double protein" hits protein target)
- For chain restaurants, use actual menu item names and realistic calorie estimates
- For generic restaurants ("a sushi place"), suggest common dishes with estimates
- food_query should be a natural text description combining all items, suitable for food logging
- If they say they already ordered something, acknowledge it and build the order card for what they got (so they can log it)
- Calorie estimates should be realistic — don't lowball. A Chipotle burrito is ~1000 cal, not 500
- Total macros must equal the sum of all items`
    } else if (wantsMealEdit) {
      featureInstruction = `

MEAL EDIT REQUEST:
The user wants to modify a logged meal. Here are today's meals with details:
${todayMealsDetail}

After your conversational response (1-2 sentences), output JSON in <meal_edit>...</meal_edit> tags:
{"meal_id":"the-uuid-from-above","meal_name":"Meal display name","changes":[{"action":"swap|remove|add|resize","original":"original item","replacement":"new item or null","calorie_diff":N,"protein_diff":N}],"original_calories":N,"original_protein":N,"original_carbs":N,"original_fat":N,"new_calories":N,"new_protein":N,"new_carbs":N,"new_fat":N}

RULES:
- meal_id MUST be a real UUID from the meals listed above. Do not invent one.
- If the user doesn't specify which meal, use the most recent one
- If it's ambiguous (multiple meals could match), ASK which one in your text response. Do NOT output <meal_edit> tags.
- action types: "swap" (replace item), "remove" (delete item), "add" (new item), "resize" (change portion)
- calorie_diff and protein_diff show the change (negative = reduction, positive = increase)
- original_* = the current meal macros, new_* = after the edit
- Be accurate with nutrition estimates for the replacement items`
    } else if (wantsGroceryList) {
      featureInstruction = `

GROCERY LIST REQUEST:
Generate a weekly grocery list. After your conversational response (2-3 sentences), output JSON in <grocery_list>...</grocery_list> tags:
{"categories":[{"name":"Category Name","icon":"sf_symbol_name","items":[{"name":"Item name","quantity":"2 lbs","note":null}]}],"total_items":N,"estimated_days":7}

RULES:
- Daily targets: ${targetCal} cal, ${targetProt}g protein, ${targetCarbs}g carbs, ${targetFat}g fat
- Diet style: ${dietStyle || 'standard'}
${topFoods ? `- They frequently eat: ${topFoods}. Include these items and mark with note "your go-to"` : '- No food history — build a solid default list'}
- Use these categories with SF Symbol icons:
  Produce (leaf.fill), Protein (bolt.fill), Dairy & Eggs (drop.fill), Grains & Bread (oval.fill), Pantry (cabinet.fill), Frozen (snowflake), Snacks (carrot.fill)
- Estimate quantities for ${7} days, 1 person
- Include 3-5 items per category — practical, not excessive
- Quantities should be specific: "2 lbs", "1 dozen", "1 bunch", "32 oz", "1 loaf"
- Keep it realistic — things that pair well together for real meals
- Total items should be 20-30 (manageable shopping trip)`
    } else if (wantsMealPrep) {
      featureInstruction = `

MEAL PREP REQUEST:
The user wants a batch cooking plan. After your conversational response (2-3 sentences MAX), output JSON in <meal_prep>...</meal_prep> tags:
{"prep_sessions":[{"session_name":"Session 1: Proteins","estimated_time":"45 min","items":[{"name":"Grilled Chicken Breast","servings":5,"per_serving":{"calories":280,"protein":35,"carbs":0,"fat":12},"prep_note":"Season with garlic powder and paprika, grill 6 min/side"}]}],"grocery_summary":[{"name":"Chicken breast","quantity":"2.5 lbs"}],"total_servings":20,"covers_days":5,"daily_average":{"calories":${targetCal},"protein":${targetProt},"carbs":${targetCarbs},"fat":${targetFat}}}

RULES:
- Daily targets: ${targetCal} cal, ${targetProt}g protein, ${targetCarbs}g carbs, ${targetFat}g fat
- Diet style: ${dietStyle || 'standard'}
${topFoods ? `- They frequently eat: ${topFoods}. Build the prep around these foods.` : '- No food history — use versatile, popular prep foods (chicken, rice, roasted veggies, etc.)'}
- 2-3 prep sessions (e.g., "Proteins", "Grains & Veggies", "Snacks")
- Each session: 2-4 items that can be batch cooked
- estimated_time per session: realistic (30-60 min each)
- servings = how many portions this yields (e.g., 5 for weekday lunches)
- per_serving macros must be accurate for a SINGLE portion
- prep_note = brief cooking instruction (1 sentence)
- grocery_summary = consolidated list of everything needed with quantities
- covers_days should be 5-7
- daily_average should approximate the user's targets
- ALWAYS output the <meal_prep> JSON.`
    } else if (wantsSubstitution) {
      featureInstruction = `

SMART SUBSTITUTION REQUEST:
The user wants alternatives for a specific food. After your conversational response (2-3 sentences MAX), output JSON in <substitutions>...</substitutions> tags:
{"original":{"name":"White Rice","serving":"1 cup cooked","calories":210,"protein":4,"carbs":45,"fat":0.5,"why":null,"best_for":null},"substitutes":[{"name":"Cauliflower Rice","serving":"1 cup","calories":25,"protein":2,"carbs":5,"fat":0.3,"why":"85% fewer carbs, similar volume","best_for":"low carb"}]}

RULES:
- They have ${calRemaining} cal, ${protRemaining}g protein, ${carbsRemaining}g carbs, ${fatRemaining}g fat remaining
- Diet style: ${dietStyle || 'standard'}
- Provide exactly 3 substitutes, ranked by how well they fit the user's remaining macros
- Each substitute needs: name, serving size, full macros, "why" (1 sentence on the tradeoff), "best_for" tag (e.g., "low carb", "high protein", "low calorie", "similar taste")
- The "original" field = the food being replaced with accurate macros. Set why and best_for to null for original.
- Serving sizes should be comparable (if original is 1 cup, subs should be ~1 cup)
- Be specific with food names: "Jasmine rice" not "rice"
- Macros must be realistic and accurate
- ALWAYS output the <substitutions> JSON.`
    } else if (wantsFridgeMeal) {
      featureInstruction = `

FRIDGE MODE REQUEST:
The user listed ingredients they have. Build ONE complete meal. After your conversational response (2-3 sentences MAX), output JSON in <fridge_meal>...</fridge_meal> tags:
{"meal_name":"Garlic Chicken Stir Fry","description":"Quick one-pan meal, ready in 15 min","cook_time":"15 min","ingredients":[{"name":"Chicken breast","amount":"6 oz","calories":280,"protein":35,"carbs":0,"fat":12}],"total_calories":520,"total_protein":42,"total_carbs":45,"total_fat":18,"instructions":["Season chicken with salt and pepper","Heat oil in pan over medium-high","Cook chicken 5 min per side","Add vegetables, stir fry 3 min","Serve over rice"]}

RULES:
- They have ${calRemaining} cal and ${protRemaining}g protein remaining today
- Diet style: ${dietStyle || 'standard'}
- Build ONE cohesive meal from the ingredients they mentioned
- You CAN add basic pantry staples (oil, salt, pepper, garlic, soy sauce) — note amount as "(pantry)" for these
- Each ingredient must have realistic macros for the specified amount
- Include 3-5 brief cooking instructions (1 sentence each)
- cook_time should be realistic
- total macros must equal the sum of all ingredient macros
- The meal should fit within their remaining macros as closely as possible
- meal_name should be appetizing and specific
- ALWAYS output the <fridge_meal> JSON.`
    } else if (wantsRecovery) {
      featureInstruction = `

STREAK RECOVERY REQUEST:
The user had a rough day or wants to recover. Be empathetic but action-oriented — normalize it, don't shame. After your conversational response (2-3 sentences), output JSON in <streak_recovery>...</streak_recovery> tags:
{"situation":"over_target","yesterday_calories":${yesterdayCal},"yesterday_target":${yesterdayTarget || targetCal},"excess_or_deficit":${yesterdayCal > 0 ? yesterdayCal - (yesterdayTarget || targetCal) : 0},"recovery_plan":{"strategy":"Lighter meals today to offset yesterday's surplus","target_adjustment":{"calories":1600,"protein":${targetProt},"carbs":150,"fat":50},"meals":[{"meal_type":"Breakfast","name":"Greek Yogurt with Berries","calories":250,"protein":20,"carbs":30,"fat":5,"description":"High protein, keeps you full"}]},"motivation":"One day doesn't define your trajectory."}

RULES:
- situation: "over_target", "under_target", or "streak_broken"
- Today's normal targets: ${targetCal} cal, ${targetProt}g protein
- Today so far: ${todayCal} cal consumed
${yesterdayCal > 0 ? `- Yesterday they ate: ${yesterdayCal} cal (target was ${yesterdayTarget || targetCal})` : '- No yesterday data — respond based on what they told you'}
- target_adjustment = MODIFIED targets for recovery (not normal targets)
  - Overshoot: reduce today by ~50-70% of excess (never below 1200 cal)
  - Undershoot: slightly increase but don't overcompensate
  - Streak broken: use normal targets, focus on consistency
- Include 2-3 recovery meals that sum to adjusted target minus what they've eaten
- Each meal: specific, appetizing, macro-optimized
- motivation: 1 genuine sentence, not cheesy
- DO NOT shame. Frame as "course correction" not "damage control"
- ALWAYS output the <streak_recovery> JSON.`
    }

    const systemPrompt = `${FUEL_PERSONALITY}

THIS USER'S DATA (live from their app):
${userName ? `- Name: ${userName}` : ""}
- Goal: ${goalType}${dietStyle ? ` (${dietStyle} diet)` : ""}
- Daily targets: ${targetCal} cal | ${targetProt}g protein | ${targetCarbs}g carbs | ${targetFat}g fat
- Today so far: ${todayCal} cal (${calPercent}%) | ${todayProt}g protein (${protPercent}%) | ${todayCarbs}g carbs | ${todayFat}g fat
- Still needs: ${calRemaining} cal | ${protRemaining}g protein | ${carbsRemaining}g carbs | ${fatRemaining}g fat
- Meals today: ${recentMeals || "nothing logged yet"}
${streak > 0 ? `- Logging streak: ${streak} days` : ""}
${topFoods ? `- Most logged foods this week: ${topFoods}` : ""}
${weightTrend ? `- Weight trend: ${weightTrend}` : ""}
${weekHistoryBlock}

Use this data naturally in conversation. Don't dump all the numbers at once — weave them in when relevant.${featureInstruction}`

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

    // Token budget based on feature
    const maxTokens = (wantsMealPlan || wantsGroceryList || wantsMealPrep) ? 1500
      : (wantsRestaurant || wantsMealEdit || wantsFridgeMeal || wantsRecovery) ? 1200
      : (wantsSubstitution) ? 1000
      : 800

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 25000)

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
          temperature: 0.5,
          max_tokens: maxTokens,
          system: systemPrompt,
          messages,
        }),
        signal: controller.signal,
      })
    } catch (fetchErr: unknown) {
      clearTimeout(timeoutId)
      const isAbort = fetchErr instanceof DOMException && fetchErr.name === "AbortError"
      console.error("Anthropic fetch error:", isAbort ? "timeout" : fetchErr)
      return jsonResponse({
        message: isAbort
          ? "That took too long — try asking again. I'm here."
          : FALLBACK_MSG,
      })
    }
    clearTimeout(timeoutId)

    const data = await response.json()

    if (!response.ok || !data.content?.[0]?.text) {
      console.error("Anthropic API error:", response.status, data?.error?.type)
      return jsonResponse({
        message: "I'm having a brief connection issue. Check back in a moment — your tracking data is safe.",
      })
    }

    let responseText = data.content[0].text

    // ── Extract structured cards from XML tags ──
    const structuredCards: Card[] = []

    // Meal plan
    const planMatch = responseText.match(/<meal_plan>([\s\S]*?)<\/meal_plan>/)
    if (planMatch) {
      responseText = responseText.replace(/<meal_plan>[\s\S]*?<\/meal_plan>/, '').trim()
      try {
        structuredCards.push({ type: "meal_plan", meal_plan: JSON.parse(planMatch[1]) })
      } catch { /* skip */ }
    }

    // Restaurant order
    const restaurantMatch = responseText.match(/<restaurant_order>([\s\S]*?)<\/restaurant_order>/)
    if (restaurantMatch) {
      responseText = responseText.replace(/<restaurant_order>[\s\S]*?<\/restaurant_order>/, '').trim()
      try {
        structuredCards.push({ type: "restaurant_order", restaurant_order: JSON.parse(restaurantMatch[1]) })
      } catch { /* skip */ }
    }

    // Meal edit
    const editMatch = responseText.match(/<meal_edit>([\s\S]*?)<\/meal_edit>/)
    if (editMatch) {
      responseText = responseText.replace(/<meal_edit>[\s\S]*?<\/meal_edit>/, '').trim()
      try {
        structuredCards.push({ type: "meal_edit", meal_edit: JSON.parse(editMatch[1]) })
      } catch { /* skip */ }
    }

    // Grocery list
    const groceryMatch = responseText.match(/<grocery_list>([\s\S]*?)<\/grocery_list>/)
    if (groceryMatch) {
      responseText = responseText.replace(/<grocery_list>[\s\S]*?<\/grocery_list>/, '').trim()
      try {
        structuredCards.push({ type: "grocery_list", grocery_list: JSON.parse(groceryMatch[1]) })
      } catch { /* skip */ }
    }

    // Meal prep
    const prepMatch = responseText.match(/<meal_prep>([\s\S]*?)<\/meal_prep>/)
    if (prepMatch) {
      responseText = responseText.replace(/<meal_prep>[\s\S]*?<\/meal_prep>/, '').trim()
      try {
        structuredCards.push({ type: "meal_prep", meal_prep: JSON.parse(prepMatch[1]) })
      } catch { /* skip */ }
    }

    // Substitutions
    const subMatch = responseText.match(/<substitutions>([\s\S]*?)<\/substitutions>/)
    if (subMatch) {
      responseText = responseText.replace(/<substitutions>[\s\S]*?<\/substitutions>/, '').trim()
      try {
        structuredCards.push({ type: "substitution", substitution: JSON.parse(subMatch[1]) })
      } catch { /* skip */ }
    }

    // Fridge meal
    const fridgeMatch = responseText.match(/<fridge_meal>([\s\S]*?)<\/fridge_meal>/)
    if (fridgeMatch) {
      responseText = responseText.replace(/<fridge_meal>[\s\S]*?<\/fridge_meal>/, '').trim()
      try {
        structuredCards.push({ type: "fridge_meal", fridge_meal: JSON.parse(fridgeMatch[1]) })
      } catch { /* skip */ }
    }

    // Streak recovery
    const recoveryMatch = responseText.match(/<streak_recovery>([\s\S]*?)<\/streak_recovery>/)
    if (recoveryMatch) {
      responseText = responseText.replace(/<streak_recovery>[\s\S]*?<\/streak_recovery>/, '').trim()
      try {
        structuredCards.push({ type: "streak_recovery", streak_recovery: JSON.parse(recoveryMatch[1]) })
      } catch { /* skip */ }
    }

    // Clean up any leaked/malformed XML tags from response
    responseText = responseText
      .replace(/<\/?(meal_plan|restaurant_order|meal_edit|grocery_list|meal_prep|substitutions|fridge_meal|streak_recovery)[^>]*>/g, '')
      .trim()

    // Detect implicit cards (calorie progress, macros, etc.) — skip if structured cards already present
    const implicitCards = structuredCards.length > 0 ? [] : detectCards(safeMessage, responseText)

    // Structured cards first, then implicit
    const allCards = [...structuredCards, ...implicitCards]

    return jsonResponse({
      message: responseText,
      cards: allCards.length > 0 ? allCards : undefined,
    })
  } catch (error: unknown) {
    console.error("fuel-chat error:", error)
    return jsonResponse({ message: FALLBACK_MSG })
  }
})
