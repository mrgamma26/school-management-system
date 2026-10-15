# Email Delivery Setup Guide

This guide shows you how to set up email delivery for school notifications.

## Prerequisites

1. **Supabase CLI** installed:
   ```bash
   npm install -g supabase
   ```

2. **Your Supabase Project Reference ID**:
   - Go to your Supabase dashboard: https://supabase.com/dashboard
   - Select your project
   - Go to **Settings** → **General** 
   - Copy the **Reference ID** (looks like: `abcdefghijklmnop`)

## Option 1: Using Resend (Recommended - Easy & Free)

### Step 1: Get Resend API Key

1. **Sign up at Resend:**
   - Go to https://resend.com/signup
   - Create a free account (100 emails/day free forever)
   - Verify your email address

2. **Create API Key:**
   - In Resend dashboard, click **API Keys** (left sidebar)
   - Click **Create API Key**
   - Give it a name like "School Management System"
   - Copy the key (starts with `re_...`)
   - ⚠️ Save this key securely - you can't see it again!

3. **Verify Domain (Optional for production):**
   - Click **Domains** in Resend dashboard
   - Click **Add Domain**
   - Enter your school domain (e.g., `myschool.edu`)
   - Add the DNS records they provide to your domain registrar
   - Or skip this and use `onboarding@resend.dev` for testing

### Step 2: Deploy to Supabase

Open your terminal in the project root and run:

```bash
# 1. Login to Supabase
supabase login

# 2. Link your project (replace with your actual project ref)
supabase link --project-ref YOUR_PROJECT_REF

# 3. Set the email secrets
supabase secrets set RESEND_API_KEY=YOUR_RESEND_API_KEY
supabase secrets set SENDER_EMAIL=notifications@yourdomain.com

# 4. Deploy the function
supabase functions deploy send-notification-email
```

**For the SENDER_EMAIL:**
- If you verified your domain: use `notifications@yourschool.edu`
- For testing: use `onboarding@resend.dev`

### Step 3: Test It

The email function will now be called automatically when you send a notification with `sendEmail: true` in the app.

---

## Option 2: Using Gmail SMTP

### Step 1: Set Up Gmail App Password

1. **Enable 2-Factor Authentication:**
   - Go to https://myaccount.google.com/security
   - Under "Signing in to Google", enable **2-Step Verification**

2. **Create App Password:**
   - Go to https://myaccount.google.com/apppasswords
   - Select app: **Mail**
   - Select device: **Other** (type "School Management System")
   - Click **Generate**
   - Copy the 16-character password (no spaces)

### Step 2: Replace the Edge Function

Replace the content of `index.ts` with `index-smtp.ts`:

```bash
# In your project root
cp supabase/functions/send-notification-email/index-smtp.ts supabase/functions/send-notification-email/index.ts
```

### Step 3: Deploy with Gmail Credentials

```bash
# 1. Login and link (if not done already)
supabase login
supabase link --project-ref YOUR_PROJECT_REF

# 2. Set Gmail credentials
supabase secrets set SMTP_USERNAME=your-email@gmail.com
supabase secrets set SMTP_PASSWORD=your-16-char-app-password

# 3. Deploy the function
supabase functions deploy send-notification-email
```

---

## Option 3: Skip Email for Now (Development Mode)

If you want to test the app without email delivery:

**The system will work fine without email setup!**
- Notifications will still be created in the database
- The `emailstatus` will be set to `FAILED` or `NOT_APPLICABLE`
- Users can still view notifications in the app
- You can set up email later when ready

To use without email:
1. Just deploy the function as-is (without setting secrets)
2. Or don't call `sendEmail: true` when creating notifications
3. Everything else works normally

---

## Verifying Your Setup

### Check if secrets are set:

```bash
supabase secrets list
```

You should see:
- `RESEND_API_KEY` (for Resend)
- `SENDER_EMAIL` (for Resend)
OR
- `SMTP_USERNAME` (for Gmail)
- `SMTP_PASSWORD` (for Gmail)

### Check if function is deployed:

```bash
supabase functions list
```

You should see `send-notification-email` in the list.

### Test the function:

In your app, try sending a notification:

```dart
await CommunicationsRepository().sendNotification(
  guardianId: guardianId,
  staffId: staffId,
  subject: "Test Notification",
  message: "This is a test message.",
  sendEmail: true, // Set to true to trigger email
);
```

Check the notification table - the `emailstatus` should change from `PENDING` to `SENT` or `FAILED`.

---

## Troubleshooting

### "Function not found" error
```bash
# Redeploy the function
supabase functions deploy send-notification-email
```

### Emails not sending (status stays PENDING)
1. Check secrets are set: `supabase secrets list`
2. Check function logs: `supabase functions logs send-notification-email`
3. Verify API key is valid in Resend/Gmail dashboard

### "Authentication failed" error (Gmail)
- Make sure 2FA is enabled on your Google account
- Use App Password, not your regular Gmail password
- App password has no spaces

### "Domain not verified" error (Resend)
- Use `onboarding@resend.dev` as SENDER_EMAIL for testing
- Or complete domain verification in Resend dashboard

---

## Production Checklist

Before going live:

- [ ] Domain verified in Resend (or Gmail set up)
- [ ] SENDER_EMAIL uses your school's domain
- [ ] Secrets set in Supabase production project
- [ ] Function deployed to production
- [ ] Test email sent successfully
- [ ] Email template customized with school name/logo
- [ ] Reply-to address configured (if needed)

---

## Cost Considerations

### Resend (Recommended)
- ✅ **Free tier:** 100 emails/day forever
- ✅ **Paid:** $20/month for 50,000 emails
- ✅ **No credit card required for free tier**

### Gmail SMTP
- ✅ **Free:** 500 emails/day (personal Gmail)
- ✅ **Google Workspace:** 2,000 emails/day
- ⚠️ **May get flagged as spam** if sending many emails

---

## Questions?

If you have issues:
1. Check the function logs: `supabase functions logs send-notification-email`
2. Verify secrets: `supabase secrets list`
3. Test with a simple notification first
4. Check your email provider's status page

The system works fine without email - you can always add it later!
