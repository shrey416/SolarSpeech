import "https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { action, ...params } = await req.json();

    // ── Record a navigation transition ──────────────────────
    if (action === "record") {
      const { session_id, from_route, to_route, from_screen, to_screen } =
        params;

      // Insert the raw navigation event
      const { error: insertErr } = await supabase
        .from("navigation_events")
        .insert({
          session_id,
          from_route,
          to_route,
          from_screen,
          to_screen,
        });

      if (insertErr) throw insertErr;

      // Upsert the aggregate stat (increment count)
      const { error: upsertErr } = await supabase.rpc(
        "refresh_transition_stats"
      );
      // Non-critical: don't fail if aggregation fails
      if (upsertErr) console.warn("Stats refresh warning:", upsertErr.message);

      // Auto-register route embeddings for dynamic routes (plant/inverter detail)
      await ensureRouteEmbedding(supabase, to_route, to_screen);

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── Get crowd-based suggestions ─────────────────────────
    if (action === "suggest") {
      const { route, limit = 5 } = params;

      // 1. Direct transition suggestions (what do most users do next)
      const { data: direct, error: directErr } = await supabase.rpc(
        "get_crowd_suggestions",
        { p_route: route, p_limit: limit }
      );
      if (directErr) throw directErr;

      // 2. Similar route suggestions (what users on similar pages do)
      const { data: similar, error: simErr } = await supabase.rpc(
        "get_similar_route_suggestions",
        { p_route: route, p_limit: 3 }
      );
      // Non-critical
      if (simErr) console.warn("Similar routes warning:", simErr.message);

      // Compute total transitions from this route for percentage
      const totalCount =
        direct?.reduce(
          (sum: number, r: { transition_count: number }) =>
            sum + r.transition_count,
          0
        ) ?? 1;

      // Format suggestions
      const suggestions = (direct ?? []).map(
        (row: {
          to_route: string;
          to_screen: string;
          transition_count: number;
          similarity_score: number;
        }) => ({
          to_route: row.to_route,
          to_screen: row.to_screen,
          transition_count: row.transition_count,
          percentage: Math.round((row.transition_count / totalCount) * 100),
          similarity_score: row.similarity_score,
          source: "direct",
        })
      );

      // Add similar-route suggestions that aren't already in direct
      const directRoutes = new Set(
        suggestions.map((s: { to_route: string }) => s.to_route)
      );
      const extraSuggestions = (similar ?? [])
        .filter(
          (row: { to_route: string }) => !directRoutes.has(row.to_route)
        )
        .map(
          (row: {
            similar_route: string;
            to_route: string;
            to_screen: string;
            transition_count: number;
            cosine_similarity: number;
          }) => ({
            to_route: row.to_route,
            to_screen: row.to_screen,
            transition_count: row.transition_count,
            percentage: 0, // no direct percentage for these
            similarity_score: row.cosine_similarity,
            source: "similar",
            similar_from: row.similar_route,
          })
        );

      return new Response(
        JSON.stringify({
          suggestions: [...suggestions, ...extraSuggestions],
          total_transitions: totalCount,
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

/**
 * Inserts a route embedding for dynamic routes (e.g. /plants/:id/inverters/:id)
 * by classifying the route pattern and generating a feature vector.
 */
async function ensureRouteEmbedding(
  supabase: ReturnType<typeof createClient>,
  route: string,
  screen: string
) {
  // Check if already exists
  const { data: existing } = await supabase
    .from("route_embeddings")
    .select("id")
    .eq("route", route)
    .maybeSingle();

  if (existing) return;

  // Generate embedding from route pattern
  // [dashboard, plant, inverter, sensor, alert, export, slms, depth]
  const embedding = routeToEmbedding(route);

  await supabase
    .from("route_embeddings")
    .insert({ route, screen, embedding: `[${embedding.join(",")}]` })
    .single();
}

function routeToEmbedding(route: string): number[] {
  const isDashboard = route === "/dashboard" ? 1 : 0;
  const isPlant =
    route.startsWith("/plants/") || route === "/my-plants" ? 1 : 0;
  const isInverter = route.includes("/inverters") ? 1 : 0;
  const isSensor =
    route.includes("/sensors") ||
    route.includes("/mfm/") ||
    route.includes("/temp/")
      ? 1
      : 0;
  const isAlert = route.includes("/alerts") ? 1 : 0;
  const isExport = route.includes("/exports") ? 1 : 0;
  const isSlms = route.includes("/slms") ? 1 : 0;

  // Depth: count path segments beyond the first
  const segments = route.split("/").filter(Boolean).length;
  const depth = Math.min(segments / 4, 1.0); // normalize to 0-1

  return [
    isDashboard,
    isPlant,
    isInverter,
    isSensor,
    isAlert,
    isExport,
    isSlms,
    depth,
  ];
}
