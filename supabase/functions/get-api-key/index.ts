import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// This endpoint is deprecated. API keys are never exposed to clients.
// All AI calls go through the analyze-food edge function instead.
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  return new Response(
    JSON.stringify({ error: "This endpoint has been retired." }),
    { status: 410, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  )
})
