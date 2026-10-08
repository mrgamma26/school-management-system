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
