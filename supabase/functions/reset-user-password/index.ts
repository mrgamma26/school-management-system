// supabase/functions/reset-user-password/index.ts
// Resets a user's password and sets mustchangepassword = true.
// Only SUPER_USER or ADMINISTRATOR may call this function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

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


// ── Credentials email (SMTP secrets: SMTP_USERNAME, SMTP_PASSWORD) ──────────
function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

async function sendMail(
  to: string,
  subject: string,
  text: string,
  html: string,
): Promise<{ ok: boolean; error?: string }> {
  const username = Deno.env.get("SMTP_USERNAME");
  const password = Deno.env.get("SMTP_PASSWORD");
  if (!username || !password) {
    return { ok: false, error: "SMTP credentials are not configured." };
  }
  const port = Number(Deno.env.get("SMTP_PORT") ?? "465");
  const client = new SMTPClient({
    connection: {
      hostname: Deno.env.get("SMTP_HOST") ?? "smtp.gmail.com",
      port,
      tls: port === 465,
      auth: { username, password },
    },
  });
  try {
    await client.send({
      from: Deno.env.get("SMTP_FROM") ?? username,
      to,
      subject,
      content: text,
      html,
    });
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  } finally {
    try {
      await client.close();
    } catch { /* ignore */ }
  }
}

// Emails a temporary password. The delivery log stores the message with the
// password masked, so the log never contains a usable credential.
// deno-lint-ignore no-explicit-any
async function emailCredentials(admin: any, o: {
  to: string;
  name: string;
  userId: string;
  password: string;
  kind: "NEW_ACCOUNT" | "PASSWORD_RESET";
}): Promise<{ ok: boolean; error?: string }> {
  const { data: settings } = await admin.from("school_settings")
    .select("school_name").limit(1).maybeSingle();
  const school = (settings?.school_name as string | undefined)?.trim() ||
    "School Management System";
  const intro = o.kind === "NEW_ACCOUNT"
    ? `An account has been created for you at ${school}.`
    : `Your password at ${school} has been reset by an administrator.`;
  const build = (pw: string) =>
    `Hello ${o.name || "there"},\n\n${intro}\n\nSign-in email: ${o.to}\nTemporary password: ${pw}\n\n` +
    `When you sign in with this temporary password you will be asked to choose your own new password and confirm it. ` +
    `Please do this straight away and never share your password with anyone.\n\n${school}`;
  const subject = o.kind === "NEW_ACCOUNT"
    ? `Your ${school} account`
    : `Your ${school} password was reset`;
  const text = build(o.password);
  const html = `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;line-height:1.6;color:#10233F">
<div style="max-width:600px;margin:0 auto;padding:20px">
<div style="background:#0D47A1;color:#fff;padding:16px 20px"><h2 style="margin:0">${escapeHtml(school)}</h2></div>
<div style="padding:20px;background:#F4F8FC">
<p>Hello ${escapeHtml(o.name || "there")},</p>
<p>${escapeHtml(intro)}</p>
<div style="background:#fff;padding:15px;border-left:4px solid #1565C0">
<p style="margin:0"><strong>Sign-in email:</strong> ${escapeHtml(o.to)}</p>
<p style="margin:8px 0 0"><strong>Temporary password:</strong> <code style="font-size:16px">${escapeHtml(o.password)}</code></p></div>
<p>When you sign in with this temporary password you will be asked to choose your own new password and confirm it. Please do this straight away and never share your password with anyone.</p></div>
</div></body></html>`;

  const { data: log } = await admin.from("email_delivery_log").insert({
    recipient_user_id: o.userId,
    recipient_address: o.to,
    subject,
    rendered_message: build("********"),
    message_type: o.kind,
    related_entity: "systemuser",
    related_id: o.userId,
  }).select("email_log_id").single();

  const result = await sendMail(o.to, subject, text, html);
  if (log?.email_log_id) {
    await admin.from("email_delivery_log").update({
      status: result.ok ? "SENT" : "FAILED",
      sent_at: result.ok ? new Date().toISOString() : null,
      failure_reason: result.ok ? null : result.error,
      retry_count: result.ok ? 0 : 1,
    }).eq("email_log_id", log.email_log_id);
  }
  return result;
}

// Supports both the legacy and the new Supabase API-key environment variables.
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

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const publishableKey = runtimeKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
    const secretKey = runtimeKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS");
    if (!supabaseUrl || !publishableKey || !secretKey) {
      return jsonResponse({ error: "Function is missing Supabase runtime keys." }, 500);
    }

    const anonClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: callerData } = await anonClient.auth.getUser();
    if (!callerData.user) return jsonResponse({ error: "Unauthorized" }, 401);

    const { data: callerProfile } = await anonClient
      .from("systemuser")
      .select("role:role!fk_systemuser_role(rolename)")
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

    if (targetUserId === callerData.user.id) {
      return jsonResponse(
        { error: "Use the change-password screen to change your own password." },
        400,
      );
    }

    // An Administrator may only reset Teacher, Accountant and Guardian
    // passwords (mirrors private.can_manage_account() in the database).
    // Without this an Administrator could take over a Super User account.
    if (callerRole.toUpperCase() !== "SUPER_USER") {
      const { data: target } = await anonClient
        .from("systemuser")
        .select("role:role!fk_systemuser_role(rolename)")
        .eq("userid", targetUserId)
        .maybeSingle();
      const targetRole = (target?.role as { rolename: string } | null)
        ?.rolename?.toUpperCase() ?? "";
      if (!["TEACHER", "ACCOUNTANT", "GUARDIAN"].includes(targetRole)) {
        return jsonResponse({ error: "Forbidden" }, 403);
      }
    }

    const serviceClient = createClient(supabaseUrl, secretKey);

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

    // Email the new temporary password to the account owner.
    const { data: owner } = await serviceClient.auth.admin.getUserById(targetUserId);
    const ownerEmail = owner?.user?.email ?? null;
    let emailSent = false;
    let emailError: string | null = null;
    if (ownerEmail) {
      const { data: s } = await serviceClient.from("staff")
        .select("firstname").eq("userid", targetUserId).maybeSingle();
      const { data: g } = s ? { data: null } : await serviceClient.from("guardian")
        .select("firstname").eq("userid", targetUserId).maybeSingle();
      const r = await emailCredentials(serviceClient, {
        to: ownerEmail,
        name: (s?.firstname ?? g?.firstname ?? "") as string,
        userId: targetUserId,
        password: newPassword,
        kind: "PASSWORD_RESET",
      });
      emailSent = r.ok;
      emailError = r.ok ? null : (r.error ?? null);
    } else {
      emailError = "The account has no email address.";
    }

    return jsonResponse({ success: true, emailSent, emailError });
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500);
  }
});
