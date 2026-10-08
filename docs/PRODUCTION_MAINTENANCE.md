# Production Maintenance Notes

## Configuration

- Development Supabase values are supplied through `env/dev.json` with `--dart-define-from-file`.
- `env/production.json` still contains placeholders and must be populated privately for a production build.
- Never place a Supabase service-role key in Flutter code or committed environment files.
- Password reset links must use a URL registered in Supabase Authentication URL Configuration. The URL must include the deployed application's `/reset-password` path.

## Authentication

Supabase Auth users must have a matching `public.systemuser` row using the same Auth UUID in `systemuser.userid`. The row must reference an existing `public.role` record and be active. Accounts created through the application's user-management flow are provisioned by the `create-user` Edge Function.

Role names are shared across the role table, Flutter routing, navigation, RLS policies, and Edge Functions. Change them together if the role model changes.

## Calendar permissions

All authenticated users can read `calendarevent` records. Guardians can open `/calendar` to view administrator-created holidays, exam days, closure days, and school events. Guardians must not access `/calendar/new` or `/calendar/:eventId/edit`; the Flutter route guard, calendar UI, and Supabase RLS policies all enforce this separation.

## Edge Functions

- `create-user` uses the service-role key only on the server and validates staff employee numbers before creating an Auth account.
- `send-notification-email` must authenticate the caller, verify notification ownership or a permitted privileged role, load message data from the notification record, and HTML-escape dynamic content.
- Deploy and configure Edge Function secrets outside the repository. Do not commit SMTP credentials or service-role keys.

## Android release

`android/app/build.gradle.kts` currently uses the debug signing configuration for release builds. Before publishing:

1. Create a private production keystore.
2. Store its path and passwords in a local or CI-only `android/key.properties` file.
3. Add a release signing configuration that reads those properties.
4. Keep `key.properties` and keystore files out of version control.
5. Replace the placeholder application ID with the organization's registered application ID.

Do not invent or commit signing credentials.

## Verification

Run from the repository root:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build web --dart-define-from-file=env/production.json
```

The Edge Functions should also be checked with the Deno/Supabase toolchain available in the deployment environment. This workspace does not currently have the `deno` command installed.
