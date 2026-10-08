// supabase/functions/send-notification-email/index.ts
// Edge Function that sends notification emails to guardians using Gmail SMTP.
// Triggered when a notification is created with emailstatus = 'PENDING'.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

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

interface NotificationPayload {
  notificationId: string;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

Deno.serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  let notificationId: string | undefined;

  try {
    // ── 1. Require an authenticated caller ───────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonResponse({ error: "Unauthorized" }, 401);

    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: callerData } = await authClient.auth.getUser();
    if (!callerData.user) return jsonResponse({ error: "Unauthorized" }, 401);

    // ── 2. Parse request body ────────────────────────────────────────────
    const payload: NotificationPayload = await req.json();
    notificationId = payload.notificationId;

    if (!notificationId) return jsonResponse({ error: "Missing notificationId" }, 400);

    // ── 3. Initialize Supabase client with service role ──────────────────
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: notification, error: notificationError } = await supabaseClient
      .from("notification")
      .select("notificationid, subject, message, sentby, guardian(firstname, lastname, email), staff!sentby(firstname, lastname)")
      .eq("notificationid", notificationId)
      .single();
    if (notificationError || !notification) {
      return jsonResponse({ error: "Notification not found" }, 404);
    }

    const { data: callerProfile } = await authClient
      .from("systemuser")
      .select("role(rolename)")
      .eq("userid", callerData.user.id)
      .eq("isactive", true)
      .single();
    const callerRole = ((callerProfile?.role as { rolename: string } | null)
      ?.rolename ?? "").toUpperCase();
    const privileged = ["HEAD_TEACHER", "SUPER_USER", "ICA_DIRECTOR"]
      .includes(callerRole);

    const sender = notification.staff as { firstname: string; lastname: string } | null;
    const { data: callerStaff } = await authClient
      .from("staff")
      .select("staffid")
      .eq("userid", callerData.user.id)
      .single();
    const isSender = callerStaff?.staffid === notification.sentby;
    if (!privileged && !isSender) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    const guardian = notification.guardian as { firstname: string; lastname: string; email: string };
    const guardianName = `${guardian.firstname} ${guardian.lastname}`.trim();
    const guardianEmail = guardian.email;
    const subject = notification.subject as string;
    const message = notification.message as string;
    const senderName = sender
      ? `${sender.firstname} ${sender.lastname}`.trim()
      : "School Administration";

    // ── 3. Check Gmail SMTP credentials ───────────────────────────────────
    const smtpUsername = Deno.env.get("SMTP_USERNAME");
    const smtpPassword = Deno.env.get("SMTP_PASSWORD");
    
    if (!smtpUsername || !smtpPassword) {
      // Update status to FAILED if credentials not configured
      await supabaseClient
        .from("notification")
        .update({ emailstatus: "FAILED" })
        .eq("notificationid", notificationId);
      
      return jsonResponse(
        { 
          success: false, 
          message: "SMTP credentials not configured. Notification saved without email delivery." 
        },
        200,
      );
    }

    // Escape stored user content before placing it in an HTML email.
    const safeGuardianName = escapeHtml(guardianName || "Guardian");
    const safeSubject = escapeHtml(subject);
    const safeMessage = escapeHtml(message).replaceAll("\n", "<br>");
    const safeSenderName = escapeHtml(senderName);

    // Construct HTML email body
    const htmlBody = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #1976d2; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .message { background-color: white; padding: 15px; border-left: 4px solid #1976d2; }
            .footer { margin-top: 20px; padding: 10px; text-align: center; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>School Notification</h1>
            </div>
            <div class="content">
              <p>Dear ${safeGuardianName},</p>
              <div class="message">
                <h3>${safeSubject}</h3>
                <p>${safeMessage}</p>
              </div>
              <p style="margin-top: 20px;">
                <strong>From:</strong> ${safeSenderName}
              </p>
            </div>
            <div class="footer">
              <p>This is an automated notification from the School Management System.</p>
              <p>Please do not reply to this email.</p>
            </div>
          </div>
        </body>
      </html>
    `;

    // ── 4. Send email via Gmail SMTP ──────────────────────────────────────
    const client = new SMTPClient({
      connection: {
        hostname: "smtp.gmail.com",
        port: 465,
        tls: true,
        auth: {
          username: smtpUsername,
          password: smtpPassword,
        },
      },
    });

    await client.send({
      from: smtpUsername,
      to: guardianEmail,
      subject: `School Notification: ${subject}`,
      content: message,
      html: htmlBody,
    });

    await client.close();

    // ── 5. Update notification status to SENT ─────────────────────────────
    await supabaseClient
      .from("notification")
      .update({ emailstatus: "SENT" })
      .eq("notificationid", notificationId);

    return jsonResponse({
      success: true,
      message: "Email sent successfully via Gmail SMTP",
    });

  } catch (e) {
    console.error("Error in send-notification-email function:", e);
    
    // Update status to FAILED
    try {
      const supabaseClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );
      
      await supabaseClient
        .from("notification")
        .update({ emailstatus: "FAILED" })
        .eq("notificationid", notificationId ?? "");
    } catch (updateError) {
      console.error("Failed to update status:", updateError);
    }

    return jsonResponse({ error: "Email delivery failed." }, 500);
  }
});
