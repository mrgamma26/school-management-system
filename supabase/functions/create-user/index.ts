// supabase/functions/create-user/index.ts
// Privileged Edge Function that creates an Auth user + systemuser + staff/guardian profile.
// The service-role key NEVER leaves this server-side function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_CALLER_ROLES = ["SUPER_USER", "SYSTEM_ADMIN", "ADMINISTRATOR", "REGISTRAR"];

// CORS headers required for Flutter web (localhost triggers browser preflight)
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
  // Handle CORS preflight — browser sends OPTIONS before the real POST
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // ── 1. Require an Authorization header ──────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    // ── 2. Verify the caller using their user-facing token ───────────────
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: callerData } = await anonClient.auth.getUser();
    if (!callerData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    // ── 3. Verify caller has a permitted role ────────────────────────────
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

    // ── 4. Parse request body ────────────────────────────────────────────
    const body = await req.json();

    // Support both payload shapes:
    //   Shape A (StaffFormPage): flat fields + type:"staff"
    //   Shape B (CreateUserPage / StudentFormPage): userType + profileData nested
    const isShapeB = body.userType !== undefined;

    const email: string = body.email;
    const password: string = body.password;
    const username: string = body.username ?? email.split("@")[0];
    const roleId: string = body.roleId;
    const type: string = isShapeB
      ? body.userType.toLowerCase()   // "STAFF" → "staff", "GUARDIAN" → "guardian"
      : (body.type ?? "staff");

    // Flatten profileData if shape B was used
    const profile = isShapeB ? (body.profileData ?? {}) : body;

    const firstName: string  = profile.firstName  ?? profile.firstname  ?? "";
    const middleName: string | null = profile.middleName ?? profile.middlename ?? null;
    const lastName: string   = profile.lastName   ?? profile.lastname   ?? "";
    const gender: string     = profile.gender     ?? "MALE";
    const employeeNumber: string | null = profile.employeeNumber ?? profile.employeenumber ?? null;
    const phoneNumber: string | null    = profile.phoneNumber    ?? profile.phonenumber    ?? null;
    const physicalAddress: string | null = profile.physicalAddress ?? profile.physicaladdress ?? null;

    if (!email || !password || !roleId || !type) {
      return jsonResponse(
        { error: "Missing required fields: email, password, roleId, type." },
        400,
      );
    }

    // ── 5. Create Auth user with the service-role key ────────────────────
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: created, error: authError } =
      await serviceClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });

    if (authError || !created.user) {
      return jsonResponse(
        { error: authError?.message ?? "Auth creation failed." },
        400,
      );
    }

    const userId = created.user.id;

    // ── 6. Create systemuser row ─────────────────────────────────────────
    const { error: sysUserError } = await serviceClient
      .from("systemuser")
      .insert({
        userid: userId,
        roleid: roleId,
        username: username,
        mustchangepassword: true,
        isactive: true,
      });

    if (sysUserError) {
      await serviceClient.auth.admin.deleteUser(userId);
      return jsonResponse({ error: sysUserError.message }, 400);
    }

    // ── 7. Create staff or guardian profile ──────────────────────────────
    const profileTable = type === "staff" ? "staff" : "guardian";

    const profileData =
      type === "staff"
        ? {
            userid: userId,
            employeenumber: employeeNumber,
            firstname: firstName,
            middlename: middleName,
            lastname: lastName,
            gender: gender,
            email: email,
          }
        : {
            userid: userId,
            firstname: firstName,
            middlename: middleName,
            lastname: lastName,
            gender: gender,
            phonenumber: phoneNumber,
            physicaladdress: physicalAddress,
            email: email,
          };

    const { error: profileInsertError } = await serviceClient
      .from(profileTable)
      .insert(profileData);

    if (profileInsertError) {
      await serviceClient.from("systemuser").delete().eq("userid", userId);
      await serviceClient.auth.admin.deleteUser(userId);
      return jsonResponse({ error: profileInsertError.message }, 400);
    }

    return jsonResponse({ userId });

  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
