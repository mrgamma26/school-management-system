import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const ALLOWED_CALLER_ROLES = ["SUPER_USER", "ADMINISTRATOR"];

// Mirrors private.can_assign_role() in the database: a Super User may assign
// any approved role, an Administrator only Teacher, Accountant or Guardian.
const ASSIGNABLE_ROLES: Record<string, string[]> = {
  SUPER_USER: [
    "SUPER_USER",
    "ADMINISTRATOR",
    "HEAD_TEACHER",
    "TEACHER",
    "ACCOUNTANT",
    "GUARDIAN",
  ],
  ADMINISTRATOR: ["TEACHER", "ACCOUNTANT", "GUARDIAN"],
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
    },
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

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Any non-blank text is a valid name (the value is already trimmed and length-checked).
const NAME_PATTERN = /^\S[\s\S]*$/u;
const MALAWI_PHONE_PATTERN = /^(?:(?:\+265)|0)(?:88|89|98|99)\d{7}$/;
const ISO_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseIsoDate(value: string | null): Date | null {
  if (!value) return null;
  const match = ISO_DATE_PATTERN.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return parsed.getUTCFullYear() === year &&
      parsed.getUTCMonth() === month - 1 &&
      parsed.getUTCDate() === day
    ? parsed
    : null;
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
      .select("role:role!fk_systemuser_role(rolename)")
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

    const rawProfile = body.profileData ?? body;
    if (!isRecord(rawProfile)) {
      return jsonResponse({ error: "Profile data must be a JSON object." }, 400);
    }
    const profile = rawProfile;
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
    const dateOfBirth = optionalText(profile.dateOfBirth ?? profile.dateofbirth);
    const nationalId = optionalText(profile.nationalId ?? profile.nationalid);
    const alternativePhone = optionalText(profile.alternativePhone ?? profile.alternativephone);
    const jobTitle = optionalText(profile.jobTitle ?? profile.jobtitle);
    const department = optionalText(profile.department);
    const employmentType = optionalText(profile.employmentType ?? profile.employmenttype);
    const employmentStartDate = optionalText(profile.employmentStartDate ?? profile.employmentstartdate);
    const professionalQualifications = optionalText(profile.professionalQualifications ?? profile.professionalqualifications);
    const highestAcademicQualification = optionalText(profile.highestAcademicQualification ?? profile.highestacademicqualification);
    const yearsOfExperience = Number(profile.yearsOfExperience ?? profile.yearsofexperience ?? 0);
    const emergencyContactName = optionalText(profile.emergencyContactName ?? profile.emergencycontactname);
    const emergencyContactPhone = optionalText(profile.emergencyContactPhone ?? profile.emergencycontactphone);
    const emergencyContactRelationship = optionalText(profile.emergencyContactRelationship ?? profile.emergencycontactrelationship);

    if (
      !email || !EMAIL_PATTERN.test(email) || !password ||
      !roleId || !username ||
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
    if (
      password.length < 12 || !/[A-Z]/.test(password) || !/[a-z]/.test(password) ||
      !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)
    ) {
      return jsonResponse({ error: "Use a password with at least 12 characters, including upper/lower case, a number and a symbol." }, 400);
    }
    if (
      firstName.length > 80 || lastName.length > 80 ||
      !NAME_PATTERN.test(firstName) || !NAME_PATTERN.test(lastName) ||
      (middleName !== null &&
        (middleName.length > 80 || !NAME_PATTERN.test(middleName))) ||
      !["MALE", "FEMALE"].includes(gender)
    ) {
      return jsonResponse({ error: "Enter valid staff names and gender." }, 400);
    }
    if (type === "staff" && (!employeeNumber || !dateOfBirth || !phoneNumber || !jobTitle || !employmentType || !employmentStartDate || !emergencyContactName || !emergencyContactPhone || !emergencyContactRelationship)) {
      return jsonResponse({
        error: "Complete all required identity, employment and emergency-contact fields.",
      }, 400);
    }
    if (type === "staff") {
      const dob = parseIsoDate(dateOfBirth);
      const startDate = parseIsoDate(employmentStartDate);
      const today = new Date();
      const minimumBirthDate = new Date(Date.UTC(today.getUTCFullYear() - 18, today.getUTCMonth(), today.getUTCDate()));
      if (!dob || dob > minimumBirthDate) {
        return jsonResponse({ error: "Staff members must be at least 18 years old." }, 400);
      }
      if (!startDate) {
        return jsonResponse({ error: "Enter a valid employment start date." }, 400);
      }
      if (
        !MALAWI_PHONE_PATTERN.test(phoneNumber!) ||
        !MALAWI_PHONE_PATTERN.test(emergencyContactPhone!) ||
        (alternativePhone !== null &&
          !MALAWI_PHONE_PATTERN.test(alternativePhone))
      ) {
        return jsonResponse({ error: "Enter valid Malawi phone numbers." }, 400);
      }
      if (
        !Number.isInteger(yearsOfExperience) || yearsOfExperience < 0 ||
        yearsOfExperience > 70
      ) {
        return jsonResponse({ error: "Years of experience must be from 0 to 70." }, 400);
      }
    }

    // The service key bypasses RLS, so the role being granted must be checked
    // here against the caller's own authority before anything is created.
    const { data: targetRole, error: targetRoleError } = await callerClient
      .from("role")
      .select("rolename")
      .eq("roleid", roleId)
      .single();
    const targetRoleName = (targetRole?.rolename as string | undefined)
      ?.toUpperCase() ?? "";
    if (targetRoleError || !targetRoleName) {
      return jsonResponse({ error: "The selected role does not exist." }, 400);
    }
    if (!(ASSIGNABLE_ROLES[callerRole] ?? []).includes(targetRoleName)) {
      return jsonResponse(
        { error: "You are not permitted to create accounts with that role." },
        403,
      );
    }
    if ((type === "guardian") !== (targetRoleName === "GUARDIAN")) {
      return jsonResponse(
        { error: "Guardian accounts must use the Guardian role, and staff accounts cannot." },
        400,
      );
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
        dateofbirth: dateOfBirth,
        nationalid: nationalId,
        phonenumber: phoneNumber,
        alternativephone: alternativePhone,
        physicaladdress: physicalAddress,
        jobtitle: jobTitle,
        department,
        employmenttype: employmentType,
        employmentstartdate: employmentStartDate,
        professionalqualifications: professionalQualifications,
        highestacademicqualification: highestAcademicQualification,
        yearsofexperience: Number.isFinite(yearsOfExperience) ? yearsOfExperience : 0,
        emergencycontactname: emergencyContactName,
        emergencycontactphone: emergencyContactPhone,
        emergencycontactrelationship: emergencyContactRelationship,
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

    // Email the temporary password to the new user. If delivery fails the
    // account still exists and the administrator can pass the password on.
    const emailResult = await emailCredentials(adminClient, {
      to: email,
      name: firstName,
      userId,
      password,
      kind: "NEW_ACCOUNT",
    });
    return jsonResponse({
      userId,
      emailSent: emailResult.ok,
      emailError: emailResult.ok ? null : "Credentials email could not be sent.",
    });
  } catch (error) {
    console.error("create-user failed", error);
    return jsonResponse({ error: "Unexpected account creation error." }, 500);
  }
});
