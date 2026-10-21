# Manual Supabase Edge Function deployment

Deploy Edge Functions from the Supabase Dashboard. Do not put a service-role
key in `env/dev.json` or in the Flutter app.

1. Open **Supabase Dashboard → Edge Functions → Deploy new function → Via
   Editor**.
2. Enter the exact function name below.
3. Copy the matching local `index.ts` file into the editor and select
   **Deploy function**.
4. For `create-user`, turn **Verify JWT** off in the function settings. This
   project uses a publishable key, and `create-user` validates the signed-in
   user's access token and administrator role inside the function with
   `auth.getUser()` before using the service-role client.
5. Use **Logs** on that function page if a request fails.

| Function name | Copy this file |
| --- | --- |
| `create-user` | `supabase/functions/create-user/index.ts` |
| `reset-user-password` | `supabase/functions/reset-user-password/index.ts` |
| `delete-user` | `supabase/functions/delete-user/index.ts` |
| `send-notification-email` | `supabase/functions/send-notification-email/index.ts` |

Supabase provides `SUPABASE_URL` and its publishable/secret runtime keys to
deployed functions. Do not create or expose `SUPABASE_SERVICE_ROLE_KEY` in the
Flutter client. The email function may need its own provider-specific secrets;
see its `README.md` before deploying it.

## Email setup (notifications and new-user passwords)

`send-notification-email`, `create-user` and `reset-user-password` send mail
through SMTP. Set these secrets once (Dashboard > Edge Functions > Secrets, or
`supabase secrets set`):

| Secret | Value |
| --- | --- |
| `SMTP_USERNAME` | the sending address, e.g. your Gmail address |
| `SMTP_PASSWORD` | a Gmail **App Password** (not your normal password) |
| `SMTP_FROM` | optional, defaults to `SMTP_USERNAME` |
| `SMTP_HOST` / `SMTP_PORT` | optional, default `smtp.gmail.com` / `465` |
| `CRON_SECRET` | optional, only if you schedule the queue (below) |

Automatic notifications (e.g. year-end outcomes) are queued as `PENDING` by the
database. To deliver them without a user action, schedule a call to
`send-notification-email` every 5 minutes with the header `x-cron-secret` and
the body `{"processPending": true}` (Dashboard > Integrations > Cron).
Every attempt is recorded in `email_delivery_log` (Super User can read it).
