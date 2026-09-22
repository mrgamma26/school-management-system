# Gmail SMTP Setup Instructions

## Quick Setup (3 Steps)

### Step 1: Get Gmail App Password

1. **Go to your Google Account:**
   - Visit: https://myaccount.google.com/security

2. **Enable 2-Step Verification** (if not already enabled):
   - Scroll to "Signing in to Google"
   - Click "2-Step Verification"
   - Follow the prompts to enable it

3. **Create App Password:**
   - Visit: https://myaccount.google.com/apppasswords
   - Or search for "App Passwords" in your Google Account settings
   - Select app: **Mail**
   - Select device: **Other (Custom name)**
   - Type: "School Management System"
   - Click **Generate**
   - **IMPORTANT:** Copy the 16-character password (like: `abcd efgh ijkl mnop`)
   - Remove the spaces: `abcdefghijklmnop`

### Step 2: Install Supabase CLI & Deploy

Open your terminal (Command Prompt or PowerShell) in your project folder:

```bash
# Install Supabase CLI globally
npm install -g supabase

# Login to Supabase (opens browser)
supabase login

# Link your project (get your project ref from dashboard)
supabase link --project-ref YOUR_PROJECT_REF

# Set Gmail credentials
supabase secrets set SMTP_USERNAME=your-email@gmail.com
supabase secrets set SMTP_PASSWORD=abcdefghijklmnop

# Deploy the email function
supabase functions deploy send-notification-email
```

**To find your PROJECT_REF:**
- Go to: https://supabase.com/dashboard
- Click on your project
- Look at the URL: `https://supabase.com/dashboard/project/YOUR_PROJECT_REF`
- Or go to Settings → General → Reference ID

### Step 3: Test It

That's it! Now when you send a notification in the app with `sendEmail: true`, it will automatically send via Gmail.

---

## Example Commands (Copy & Paste)

Replace the values with your actual information:

```bash
# 1. Login
supabase login

# 2. Link project (replace abc123 with your actual project ref)
supabase link --project-ref abc123

# 3. Set credentials (replace with your actual email and app password)
supabase secrets set SMTP_USERNAME=yourschool@gmail.com
supabase secrets set SMTP_PASSWORD=abcdefghijklmnop

# 4. Deploy
supabase functions deploy send-notification-email
```

---

## Verification

### Check if it worked:

```bash
# List your secrets (values are hidden for security)
supabase secrets list

# You should see:
# SMTP_USERNAME
# SMTP_PASSWORD
# SUPABASE_URL (automatically set)
# SUPABASE_SERVICE_ROLE_KEY (automatically set)

# List functions
supabase functions list

# You should see:
# send-notification-email
```

---

## Common Issues & Solutions

### ❌ "2-Step Verification is required"
**Solution:** Enable 2-Step Verification first at https://myaccount.google.com/security

### ❌ "App Passwords is not available"
**Solution:** 
- Make sure 2-Step Verification is enabled
- Wait a few minutes after enabling 2-Step Verification
- Try accessing https://myaccount.google.com/apppasswords directly

### ❌ "Authentication failed" in logs
**Solution:**
- Double-check you used the App Password, not your regular Gmail password
- Make sure there are no spaces in the password
- App Password should be 16 characters: `abcdefghijklmnop`

### ❌ "Command 'supabase' not found"
**Solution:**
```bash
# Install Supabase CLI
npm install -g supabase

# If npm is not installed, install Node.js first from:
# https://nodejs.org/
```

### ❌ "Project ref not found"
**Solution:**
- Go to your Supabase dashboard
- Settings → General → Reference ID
- Copy the exact ID (no extra spaces)

---

## Gmail Limits

- **Free Gmail:** 500 emails per day
- **Google Workspace:** 2,000 emails per day

If you need more, consider:
- Using multiple Gmail accounts with load balancing
- Switching to a dedicated email service (Resend, SendGrid, etc.)

---

## Testing Email Delivery

1. **In your Flutter app**, send a test notification:

```dart
await CommunicationsRepository().sendNotification(
  guardianId: someGuardianId,
  staffId: someStaffId,
  subject: "Test Email",
  message: "This is a test to verify email delivery works.",
  sendEmail: true, // ← This triggers the email
);
```

2. **Check the notification table:**
   - `emailstatus` should change from `PENDING` to `SENT`
   - If it's `FAILED`, check the function logs

3. **View function logs:**
```bash
supabase functions logs send-notification-email
```

---

## What if I don't want email right now?

No problem! The app works fine without email:
- Just don't set the secrets
- Or set `sendEmail: false` when creating notifications
- Notifications will still be created and viewable in the app
- You can add email later whenever you're ready

---

## Next Steps

After email is working:
1. Test with a real guardian email
2. Customize the email template if needed
3. Monitor your Gmail sending limits
4. Consider setting up a dedicated school Gmail account

Need help? Check the function logs:
```bash
supabase functions logs send-notification-email --tail
```
