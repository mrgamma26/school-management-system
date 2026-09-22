# Send Notification Email Edge Function

This Edge Function sends notification emails to guardians using the Resend email API.

## Setup

### 1. Install Resend (Optional - for email delivery)

If you want to enable email delivery, sign up for a free account at [Resend](https://resend.com) and get your API key.

### 2. Set Environment Variables

Set the following secrets in your Supabase project:

```bash
# Required for the function to work
supabase secrets set RESEND_API_KEY=your_resend_api_key_here
supabase secrets set SENDER_EMAIL=notifications@yourdomain.com

# These are automatically available in Edge Functions
# SUPABASE_URL=your_supabase_url
# SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### 3. Deploy the Function

```bash
supabase functions deploy send-notification-email
```

## Usage

The function is automatically called by the `CommunicationsRepository.sendNotification()` method when `sendEmail: true` is passed.

### Example:

```dart
final notificationId = await CommunicationsRepository().sendNotification(
  guardianId: guardianId,
  staffId: staffId,
  subject: 'Important Notice',
  message: 'Your child has been selected for the science fair.',
  sendEmail: true, // This triggers the Edge Function
);
```

## Request Payload

```json
{
  "notificationId": "uuid",
  "guardianEmail": "parent@example.com",
  "guardianName": "John Doe",
  "subject": "Important Notice",
  "message": "Your child has been selected for the science fair.",
  "senderName": "Jane Smith"
}
```

## Response

### Success (200)

```json
{
  "success": true,
  "message": "Email sent successfully",
  "emailId": "resend_email_id"
}
```

### Error (400/500)

```json
{
  "success": false,
  "message": "Email delivery failed",
  "error": "Error details"
}
```

## Email Status

The function automatically updates the `notification` table's `emailstatus` field:

- `PENDING` → `SENT` (on success)
- `PENDING` → `FAILED` (on error)
- `NOT_APPLICABLE` (when sendEmail is false)

## Alternative: Using SMTP

If you prefer to use SMTP instead of Resend, modify the email sending section in `index.ts`:

```typescript
// Example using Deno's SMTP client
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts";

const smtp = new SmtpClient();
await smtp.connectTLS({
  hostname: "smtp.gmail.com",
  port: 465,
  username: Deno.env.get("SMTP_USERNAME"),
  password: Deno.env.get("SMTP_PASSWORD"),
});

await smtp.send({
  from: "notifications@school.edu",
  to: guardianEmail,
  subject: `School Notification: ${subject}`,
  content: htmlBody,
  html: htmlBody,
});
```

## Testing

Test the function locally:

```bash
supabase functions serve send-notification-email --env-file supabase/.env.local
```

Then send a test request:

```bash
curl -i --location --request POST 'http://localhost:54321/functions/v1/send-notification-email' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "notificationId": "test-uuid",
    "guardianEmail": "test@example.com",
    "guardianName": "Test Guardian",
    "subject": "Test Subject",
    "message": "Test message",
    "senderName": "Test Sender"
  }'
```

## Notes

- The function requires the `RESEND_API_KEY` environment variable to be set for email delivery
- If `RESEND_API_KEY` is not configured, notifications will be created with `emailstatus: 'FAILED'`
- The function uses the service role key to update notification status directly
- Email failures are logged but don't prevent notification creation
- HTML email template includes school branding and proper formatting
