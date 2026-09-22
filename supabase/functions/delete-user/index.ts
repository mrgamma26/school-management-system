// supabase/functions/delete-user/index.ts
// Soft-deactivates a user (sets isactive=false on systemuser).
// Hard-deleting users is not permitted to preserve historical records.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_CALLER_ROLES = ["SUPER_USER", "SYSTEM_ADMIN"];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Unauthorized" }, 401);

    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: callerData } = await anonClient.auth.getUser();
    if (!callerData.user) return jsonResponse({ error: "Unauthorized" }, 401);

    const { data: callerProfile } = await anonClient
      .from("systemuser")
      .select("role(rolename)")
      .eq("userid", callerData.user.id)
      .eq("isactive", true)
      .single();

    const callerRole = (callerProfile?.role as { rolename: string } | null)
      ?.rolename ?? "";

    if (!ALLOWED_CALLER_ROLES.includes(callerRole.toUpperCase())) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    const { targetUserId } = await req.json();
    if (!targetUserId) {
      return jsonResponse({ error: "targetUserId is required." }, 400);
    }

    // Soft-delete: set isactive = false. Never hard-delete a user.
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error } = await serviceClient
      .from("systemuser")
      .update({ isactive: false })
      .eq("userid", targetUserId);

    if (error) return jsonResponse({ error: error.message }, 400);

    return jsonResponse({ success: true });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
