import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

async function removeCatchPhotos(
  admin: ReturnType<typeof createClient>,
  userId: string,
) {
  const storage = admin.storage.from("catch-photos");
  for (let page = 0; page < 10; page += 1) {
    const { data, error } = await storage.list(userId, {
      limit: 1000,
      // Deleting the page shifts the remaining objects into its range.
      offset: 0,
    });
    if (error) throw error;
    if (!data || data.length === 0) return;

    const paths = data
      .map((item) => item.name)
      .filter((name): name is string => name.trim().length > 0)
      .map((name) => `${userId}/${name}`);
    if (paths.length > 0) {
      const { error: removeError } = await storage.remove(paths);
      if (removeError) throw removeError;
    }
    if (data.length < 1000) return;
  }
  throw new Error("Too many catch-photo objects to delete in one request");
}

async function deleteOwnedRows(
  admin: ReturnType<typeof createClient>,
  userId: string,
  actorKey: string,
) {
  const ownedTables = [
    { table: "profiles", column: "id" },
    { table: "catches", column: "user_id" },
    { table: "daily_leaderboard", column: "user_id" },
    { table: "coin_grant_claims", column: "user_id" },
    { table: "player_profiles", column: "user_id" },
    { table: "player_fish_collections", column: "user_id" },
    { table: "player_catches", column: "user_id" },
    { table: "player_coin_transactions", column: "user_id" },
    { table: "player_gameplay_reward_claims", column: "user_id" },
    { table: "player_fishing_sessions", column: "user_id" },
    { table: "player_notification_tokens", column: "user_id" },
  ] as const;
  for (const { table, column } of ownedTables) {
    const { error } = await admin.from(table).delete().eq(column, userId);
    if (error) throw error;
  }

  // Analytics deliberately stores a project-local SHA-256 actor key instead
  // of the auth UUID; remove those rows with the same privacy-preserving key.
  const { error: analyticsError } = await admin
    .from("analytics_events")
    .delete()
    .eq("actor_key", actorKey);
  if (analyticsError) throw analyticsError;
}

async function analyticsActorKey(userId: string) {
  const bytes = new TextEncoder().encode(userId);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "Deletion service is not configured" }, 503);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "Invalid session" }, 401);

  const userId = userData.user.id;
  const admin = createClient(supabaseUrl, serviceRoleKey);
  try {
    const actorKey = await analyticsActorKey(userId);
    await removeCatchPhotos(admin, userId);
    await deleteOwnedRows(admin, userId, actorKey);
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
    return json({ deleted: true });
  } catch (_) {
    return json(
      { error: "Account deletion did not complete; support follow-up is required" },
      500,
    );
  }
});
