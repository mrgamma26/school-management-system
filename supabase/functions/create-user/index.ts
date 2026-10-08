import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_CALLER_ROLES = [
  "SUPER_USER",
  "SYSTEM_ADMIN",
  "ADMINISTRATOR",
  "REGISTRAR",
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function runtimeKey(legacyName: string, dictionaryName: string): string | null {
  const legacy = Deno.env.get(legacyName);
  if (legacy) return legacy;

  const raw = Deno.env.get(dictionaryName);
  if (!raw) return null;
  try {
    const keys = JSON.parse(raw) as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch {
    return null;
  }
}

function optionalText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text || null;
}

function requiredText(value: unknown): string {
  return optionalText(value) ?? "";
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const publishableKey = runtimeKey(
      "SUPABASE_ANON_KEY",
      "SUPABASE_PUBLISHABLE_KEYS",
    );
    const secretKey = runtimeKey(
      "SUPABASE_SERVICE_ROLE_KEY",
      "SUPABASE_SECRET_KEYS",
    );
    if (!supabaseUrl || !publishableKey || !secretKey) {
      return jsonResponse(
        { error: "The create-user function is missing Supabase runtime keys." },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Unauthorized." }, 401);

    const callerClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: callerData, error: callerError } = await callerClient.auth
      .getUser();
    if (callerError || !callerData.user) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    const { data: callerProfile, error: profileError } = await callerClient
      .from("systemuser")
      .select("role(rolename)")
      .eq("userid", callerData.user.id)
      .eq("isactive", true)
      .single();
    const callerRole = (
      callerProfile?.role as { rolename?: string } | null
    )?.rolename?.toUpperCase() ?? "";
    if (profileError || !ALLOWED_CALLER_ROLES.includes(callerRole)) {
      return jsonResponse(
        { error: "Only administrators can create accounts." },
        403,
      );
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json() as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "Request body must be JSON." }, 400);
    }

    const profile = (body.profileData ?? body) as Record<string, unknown>;
    const email = requiredText(body.email).toLowerCase();
    const password = requiredText(body.password);
    const roleId = requiredText(body.roleId);
    const username = requiredText(body.username) || email.split("@")[0];
    const type = requiredText(body.userType ?? body.type).toLowerCase();
    const firstName = requiredText(profile.firstName ?? profile.firstname);
    const middleName = optionalText(profile.middleName ?? profile.middlename);
    const lastName = requiredText(profile.lastName ?? profile.lastname);
    const gender = requiredText(profile.gender).toUpperCase() || "MALE";
    const employeeNumber = optionalText(
      profile.employeeNumber ?? profile.employeenumber,
    );
    const phoneNumber = optionalText(
      profile.phoneNumber ?? profile.phonenumber,
    );
    const physicalAddress = optionalText(
      profile.physicalAddress ?? profile.physicaladdress,
    );

    if (
      !email || !email.includes("@") || !password || !roleId || !username ||
      !firstName || !lastName || !["staff", "guardian"].includes(type)
    ) {
      return jsonResponse(
        {
          error:
            "Email, password, role, account type, first name and last name are required.",
        },
        400,
      );
    }
    if (type === "staff" && !employeeNumber) {
      return jsonResponse({
        error: "Employee number is required for staff accounts.",
      }, 400);
    }

    const adminClient = createClient(supabaseUrl, secretKey);
    const { data: created, error: authError } = await adminClient.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
      });
    if (authError || !created.user) {
      return jsonResponse({
        error: authError?.message ?? "Auth account creation failed.",
      }, 400);
    }

    const userId = created.user.id;
    const cleanup = async () => {
      await adminClient.from("systemuser").delete().eq("userid", userId);
      await adminClient.auth.admin.deleteUser(userId);
    };

    const { error: systemUserError } = await adminClient.from("systemuser")
      .insert({
        userid: userId,
        roleid: roleId,
        username,
        mustchangepassword: true,
        isactive: true,
      });
    if (systemUserError) {
      await cleanup();
      return jsonResponse({ error: systemUserError.message }, 400);
    }

    const { error: insertError } = type === "staff"
      ? await adminClient.from("staff").insert({
        userid: userId,
        employeenumber: employeeNumber,
        firstname: firstName,
        middlename: middleName,
        lastname: lastName,
        gender,
        email,
      })
      : await adminClient.from("guardian").insert({
        userid: userId,
        firstname: firstName,
        middlename: middleName,
        lastname: lastName,
        gender,
        phonenumber: phoneNumber ?? "N/A",
        physicaladdress: physicalAddress ?? "N/A",
        email,
      });
    if (insertError) {
      await cleanup();
      return jsonResponse({ error: insertError.message }, 400);
    }

    return jsonResponse({ userId });
  } catch (error) {
    console.error("create-user failed", error);
    return jsonResponse({ error: "Unexpected account creation error." }, 500);
  }
});
