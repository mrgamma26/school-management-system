# School Management System

A role-based Flutter and Supabase application for school administration, academics, assessments, finance, communications, guardians, and student progression.

## What is included

The application supports six roles: Super User, Administrator, Head Teacher, Teacher, Accountant, and Guardian. Students do not sign in. Access is protected by application routing, Supabase Auth, PostgreSQL row-level security, and trusted database functions.

## Fastest safe setup for a collaborator

The recommended option is an isolated local Supabase environment. It needs Docker, the Flutter SDK, the Supabase CLI, Git, and PowerShell 7.

```powershell
git clone https://github.com/mrgamma26/school-management-system.git
cd school-management-system
.\scripts\setup-local.ps1
.\run-dev.ps1
```

The setup script starts the local Supabase services, rebuilds the local database from the committed migrations, creates the ignored `env/dev.json`, and creates or links a local Super User. It prints a one-time temporary password only when it creates a new account.

For a hosted development project instead, copy `env/dev.example.json` to `env/dev.json` and replace only the two client values supplied by the owner:

```json
{
  "SUPABASE_URL": "https://your-development-project.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "your-development-publishable-key"
}
```

Never put a service-role key, Supabase secret key, email-provider API key, SMTP password, user password, or production credential in this repository or in Flutter configuration.

## Run and verify

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d edge --dart-define-from-file=env/dev.json --no-web-resources-cdn
```

For a release-mode browser run:

```powershell
.\run-release.ps1
```

## Documentation

- [Collaborator setup](docs/COLLABORATOR_SETUP.md)
- [Security and credential handling](SECURITY.md)
- [Contribution workflow](CONTRIBUTING.md)
- [Technical specification](docs/technical-specification.md)
- [User manual](docs/user-manual.md)
- [Architecture diagrams](docs/architecture/README.md)
- [Edge Function deployment](supabase/functions/MANUAL_DEPLOYMENT.md)

## Database workflow

Migrations in `supabase/migrations/` are the schema source of truth. For an isolated local environment, run `supabase start` followed by `supabase db reset`. The reset command is destructive to the local database only. Do not run `supabase db reset --linked` against a shared or production project.

## Project status

The repository contains a recorded 8 October 2026 release verification and later work-in-progress changes. Before sharing a test build, run the commands above and review the latest records in `docs/`. A GitHub clone contains only committed and pushed work; local uncommitted files are not shared.

No licence file is currently included. The repository owner should choose a licence before permitting public reuse or redistribution.
