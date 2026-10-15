# Security and Credential Handling

This application handles school identities, grades, fees, payment evidence, and guardian relationships. Use fictional data in development and give every collaborator the least access needed.

## Key handling matrix

| Value | Where it belongs | May be used in Flutter | May be committed | Sharing rule |
|---|---|---:|---:|---|
| `SUPABASE_URL` | Ignored `env/dev.json` | Yes | No real environment value | Send with the development publishable key through an approved private channel |
| `SUPABASE_PUBLISHABLE_KEY` or legacy anon key | Ignored `env/dev.json` | Yes | No real environment value | Client-safe only when RLS is correctly enabled; share only for a development project |
| `SUPABASE_SERVICE_ROLE_KEY` or secret key | Supabase server runtime only | Never | Never | Do not email, message, paste into Flutter, or give to ordinary collaborators |
| `SMTP_PASSWORD` or email-provider API key | Supabase Edge Function secrets | Never | Never | Repository owner or deployment administrator configures it directly |
| Temporary user password | Password manager or encrypted one-to-one channel | Sign-in only | Never | Send separately from the username and require a first-login password change |

## Safe collaboration defaults

- Prefer the local Supabase stack. It gives each developer isolated keys and prevents accidental access to live school data.
- If cloud testing is required, create a separate development project with fictional records and separate test accounts.
- Give GitHub repository access and application access separately. GitHub access does not require database administrator secrets.
- Keep row-level security enabled. The publishable key is not a replacement for RLS.
- Configure Edge Function secrets in the Supabase dashboard or with `supabase secrets set --env-file <ignored-file>`.
- Review audit logs and deactivate accounts promptly when a collaborator no longer needs access.

## If a secret or password is exposed

1. Revoke or rotate it immediately in the service that issued it.
2. Remove it from the current files and commits.
3. Treat Git history, screenshots, email, chat, and build logs as compromised copies.
4. Invalidate affected sessions and reset affected user passwords.
5. Review database and audit activity for misuse.

Removing a secret from the newest commit is not enough after it has been pushed. Rotate the value first, then clean repository history with the repository owner's approval.

## Reporting a vulnerability

Do not open a public issue containing personal data, credentials, or exploit details. Contact the repository owner privately with the affected area, reproduction steps, impact, and suggested mitigation.
