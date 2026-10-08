// supabase/functions/reset-user-password/index.ts
// Resets a user's password and sets mustchangepassword = true.
// Only SUPER_USER or ADMINISTRATOR may call this function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_CALLER_ROLES = ["SUPER_USER", "ADMINISTRATOR"];

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

    const { targetUserId, newPassword } = await req.json();
    if (!targetUserId || !newPassword) {
      return jsonResponse(
        { error: "targetUserId and newPassword are required." },
        400,
      );
    }

    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Reset Auth password
    const { error: authError } = await serviceClient.auth.admin.updateUserById(
      targetUserId,
      { password: newPassword },
    );

    if (authError) return jsonResponse({ error: authError.message }, 400);

    // Force re-login on next sign-in
    const { error: profileError } = await serviceClient
      .from("systemuser")
      .update({ mustchangepassword: true })
      .eq("userid", targetUserId);

    if (profileError) return jsonResponse({ error: profileError.message }, 400);

    return jsonResponse({ success: true });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
