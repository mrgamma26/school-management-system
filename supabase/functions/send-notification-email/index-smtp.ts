// Alternative version using Gmail SMTP
// Replace index.ts with this if you want to use Gmail instead of Resend

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

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const payload = await req.json();
    const {
      notificationId,
      guardianEmail,
      guardianName,
      subject,
      message,
      senderName,
    } = payload;

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Gmail SMTP configuration
    const smtpUsername = Deno.env.get("SMTP_USERNAME"); // your-email@gmail.com
    const smtpPassword = Deno.env.get("SMTP_PASSWORD"); // App password from Gmail
    
    if (!smtpUsername || !smtpPassword) {
      await supabaseClient
        .from("notification")
        .update({ emailstatus: "FAILED" })
        .eq("notificationid", notificationId);
      
      return jsonResponse({
        success: false,
        message: "SMTP credentials not configured"
      }, 200);
    }

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
              <p>Dear ${guardianName || "Guardian"},</p>
              <div class="message">
                <h3>${subject}</h3>
                <p>${message.replace(/\n/g, '<br>')}</p>
              </div>
              <p style="margin-top: 20px;">
                <strong>From:</strong> ${senderName || "School Administration"}
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

    // Send email via Gmail SMTP
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

    await supabaseClient
      .from("notification")
      .update({ emailstatus: "SENT" })
      .eq("notificationid", notificationId);

    return jsonResponse({
      success: true,
      message: "Email sent successfully via SMTP",
    });

  } catch (e) {
    console.error("Error:", e);
    
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    
    await supabaseClient
      .from("notification")
      .update({ emailstatus: "FAILED" })
      .eq("notificationid", payload.notificationId);

    return jsonResponse({ error: String(e) }, 500);
  }
});
