# School Management System

A role-based Flutter application for school administration, academics, assessments, finance, communications, and student progression. The backend is Supabase Auth and PostgreSQL with row-level security and trusted RPC functions.

## Start here

- [Technical specification](docs/technical-specification.md)
- [User manual](docs/user-manual.md)
- [Architecture diagrams](docs/architecture/README.md)

## Local development

Provide `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` through an ignored dart-define JSON file, then run:

```text
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Apply the SQL files in `supabase/migrations/` in numeric order to a compatible Supabase project. Never commit environment values, service-role keys, signing files, or production credentials.
