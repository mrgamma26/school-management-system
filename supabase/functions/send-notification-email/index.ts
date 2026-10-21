// supabase/functions/send-notification-email/index.ts
//
// Emails a notification to its recipient's own address.
//   { "notificationId": "<uuid>" }  -> deliver that notification
//   { "processPending": true }      -> deliver up to 20 queued notifications
//
// The recipient address is resolved from the database (guardian, staff or the
// Auth account), never from the request. Every attempt is written to
// email_delivery_log. Secrets: SMTP_USERNAME, SMTP_PASSWORD (optional:
// SMTP_HOST, SMTP_PORT, SMTP_FROM, CRON_SECRET).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PRIVILEGED_ROLES = ["HEAD_TEACHER", "SUPER_USER", "ADMINISTRATOR"];
const BATCH_SIZE = 20;

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

// deno-lint-ignore no-explicit-any
type Admin = any;

async function schoolName(admin: Admin): Promise<string> {
  const { data } = await admin.from("school_settings").select("school_name")
    .limit(1).maybeSingle();
  return (data?.school_name as string | undefined)?.trim() ||
    "School Management System";
}

interface Recipient {
  name: string;
  email: string | null;
  userId: string | null;
}

async function resolveRecipient(
  admin: Admin,
  n: { guardianid: string | null; recipientuserid: string | null },
): Promise<Recipient> {
  if (n.guardianid) {
    const { data } = await admin.from("guardian")
      .select("firstname, lastname, email, userid")
      .eq("guardianid", n.guardianid).maybeSingle();
    if (data) {
      return {
        name: `${data.firstname} ${data.lastname}`.trim(),
        email: (data.email as string | null)?.trim() || null,
        userId: data.userid ?? n.recipientuserid,
      };
    }
  }
  if (n.recipientuserid) {
    const { data: staff } = await admin.from("staff")
      .select("firstname, lastname, email")
      .eq("userid", n.recipientuserid).maybeSingle();
    if (staff?.email) {
      return {
        name: `${staff.firstname} ${staff.lastname}`.trim(),
        email: (staff.email as string).trim(),
        userId: n.recipientuserid,
      };
    }
    const { data: authUser } = await admin.auth.admin.getUserById(
      n.recipientuserid,
    );
    return {
      name: staff ? `${staff.firstname} ${staff.lastname}`.trim() : "",
      email: authUser?.user?.email ?? null,
      userId: n.recipientuserid,
    };
  }
  return { name: "", email: null, userId: null };
}

async function deliver(
  admin: Admin,
  notificationId: string,
): Promise<{ status: "SENT" | "FAILED" | "SKIPPED" | "NOT_FOUND"; error?: string }> {
  const { data: n } = await admin.from("notification")
    .select(
      "notificationid, subject, message, sentby, guardianid, recipientuserid, emailstatus",
    )
    .eq("notificationid", notificationId).maybeSingle();
  if (!n) return { status: "NOT_FOUND" };
  if (n.emailstatus === "SENT") return { status: "SKIPPED" };

  const recipient = await resolveRecipient(admin, n);

  let senderName = await schoolName(admin);
  if (n.sentby) {
    const { data: s } = await admin.from("staff")
      .select("firstname, lastname").eq("staffid", n.sentby).maybeSingle();
    if (s) senderName = `${s.firstname} ${s.lastname}`.trim();
  }
  const school = await schoolName(admin);
  const subject = `${school}: ${n.subject}`;
  const text = `Dear ${recipient.name || "user"},\n\n${n.subject}\n\n${n.message}\n\nFrom: ${senderName}\n\nThis is an automated message from ${school}. Please do not reply.`;
  const html = `<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;line-height:1.6;color:#10233F">
<div style="max-width:600px;margin:0 auto;padding:20px">
<div style="background:#0D47A1;color:#fff;padding:16px 20px"><h2 style="margin:0">${escapeHtml(school)}</h2></div>
<div style="padding:20px;background:#F4F8FC">
<p>Dear ${escapeHtml(recipient.name || "user")},</p>
<div style="background:#fff;padding:15px;border-left:4px solid #1565C0">
<h3 style="margin-top:0">${escapeHtml(n.subject as string)}</h3>
<p>${escapeHtml(n.message as string).replaceAll("\n", "<br>")}</p></div>
<p><strong>From:</strong> ${escapeHtml(senderName)}</p></div>
<p style="text-align:center;color:#666;font-size:12px">Automated message from ${escapeHtml(school)}. Please do not reply.</p>
</div></body></html>`;

  const { data: log } = await admin.from("email_delivery_log").insert({
    recipient_user_id: recipient.userId,
    recipient_address: recipient.email ?? "(no address on file)",
    subject,
    rendered_message: text,
    message_type: "NOTIFICATION",
    related_entity: "notification",
    related_id: notificationId,
  }).select("email_log_id").single();

  let result: { ok: boolean; error?: string };
  if (!recipient.email) {
    result = { ok: false, error: "Recipient has no email address on file." };
  } else {
    result = await sendMail(recipient.email, subject, text, html);
  }

  if (log?.email_log_id) {
    await admin.from("email_delivery_log").update({
      status: result.ok ? "SENT" : "FAILED",
      sent_at: result.ok ? new Date().toISOString() : null,
      failure_reason: result.ok ? null : result.error,
      retry_count: result.ok ? 0 : 1,
    }).eq("email_log_id", log.email_log_id);
  }
  await admin.from("notification")
    .update({ emailstatus: result.ok ? "SENT" : "FAILED" })
    .eq("notificationid", notificationId);

  return result.ok
    ? { status: "SENT" }
    : { status: "FAILED", error: result.error };
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
      return jsonResponse({ error: "Function is missing Supabase runtime keys." }, 500);
    }
    const admin = createClient(supabaseUrl, secretKey);

    // A scheduled job may call with the shared secret instead of a user.
    const cronSecret = Deno.env.get("CRON_SECRET");
    const cronOk = !!cronSecret &&
      req.headers.get("x-cron-secret") === cronSecret;

    let callerUserId: string | null = null;
    let callerRole = "";
    if (!cronOk) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) return jsonResponse({ error: "Unauthorized" }, 401);
      const authClient = createClient(supabaseUrl, publishableKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: callerData } = await authClient.auth.getUser();
      if (!callerData.user) return jsonResponse({ error: "Unauthorized" }, 401);
      callerUserId = callerData.user.id;
      const { data: profile } = await authClient.from("systemuser")
        .select("role:role!fk_systemuser_role(rolename)")
        .eq("userid", callerUserId).eq("isactive", true).maybeSingle();
      callerRole = ((profile?.role as { rolename: string } | null)?.rolename ??
        "").toUpperCase();
      if (!callerRole) return jsonResponse({ error: "Forbidden" }, 403);
    }

    let body: Record<string, unknown> = {};
    try {
      body = await req.json() as Record<string, unknown>;
    } catch { /* empty body */ }

    // ── Deliver the queue ────────────────────────────────────────────────
    if (body.processPending === true) {
      const { data: pending } = await admin.from("notification")
        .select("notificationid").eq("emailstatus", "PENDING")
        .order("createdat", { ascending: true }).limit(BATCH_SIZE);
      let sent = 0;
      let failed = 0;
      for (const row of pending ?? []) {
        const r = await deliver(admin, row.notificationid as string);
        if (r.status === "SENT") sent++;
        else if (r.status === "FAILED") failed++;
      }
      return jsonResponse({ processed: (pending ?? []).length, sent, failed });
    }

    // ── Deliver one notification ─────────────────────────────────────────
    const notificationId = typeof body.notificationId === "string"
      ? body.notificationId
      : "";
    if (!notificationId) return jsonResponse({ error: "Missing notificationId" }, 400);

    if (!cronOk) {
      const { data: n } = await admin.from("notification")
        .select("sentby, guardianid, recipientuserid")
        .eq("notificationid", notificationId).maybeSingle();
      if (!n) return jsonResponse({ error: "Notification not found" }, 404);
      const { data: staff } = await admin.from("staff").select("staffid")
        .eq("userid", callerUserId).maybeSingle();
      const isSender = !!staff && staff.staffid === n.sentby;
      const isRecipient = n.recipientuserid === callerUserId;
      if (!PRIVILEGED_ROLES.includes(callerRole) && !isSender && !isRecipient) {
        return jsonResponse({ error: "Forbidden" }, 403);
      }
    }

    const result = await deliver(admin, notificationId);
    if (result.status === "NOT_FOUND") {
      return jsonResponse({ error: "Notification not found" }, 404);
    }
    if (result.status === "FAILED") {
      return jsonResponse({ success: false, error: result.error }, 200);
    }
    return jsonResponse({ success: true, status: result.status });
  } catch (e) {
    console.error("send-notification-email failed", e);
    return jsonResponse({ error: "Email delivery failed." }, 500);
  }
});
