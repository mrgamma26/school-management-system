# Contributing

Thank you for helping improve the School Management System. Keep changes reviewable, testable, and safe for school data.

## Before you begin

1. Read `docs/COLLABORATOR_SETUP.md` and `SECURITY.md`.
2. Use a local or dedicated development Supabase project. Do not use production data for development.
3. Create a branch from the latest `main` branch.

```text
git switch main
git pull
git switch -c feature/short-description
```

## Development rules

- Keep business rules in the database where they protect every client, and keep matching client checks for clear user feedback.
- Add every database change as a new migration. Do not rewrite a migration that another collaborator may already have applied.
- Keep role names and access rules aligned across Flutter routing, menus, Edge Functions, migrations, and tests.
- Use fictional test data. Never commit real student, guardian, staff, financial, or authentication data.
- Do not commit `env/dev.json`, `.env` files, password lists, service-role keys, provider secrets, or signing files.
- Preserve the shared design tokens in `lib/theme/` instead of introducing page-specific colours and spacing without a design decision.

## Required checks

Run these before opening a pull request:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=env/dev.json --no-web-resources-cdn
```

When a migration changes, also run this against an isolated local stack:

```text
supabase start
supabase db reset
```

`supabase db reset` deletes local database data and rebuilds it. Never add `--linked` unless the repository owner has explicitly approved destroying a disposable remote development database.

## Pull requests

Explain the user-facing change, affected roles, database impact, tests performed, screenshots for UI work, and any manual deployment step. Keep unrelated changes out of the same pull request. A reviewer should be able to reproduce the change from the committed files alone.
