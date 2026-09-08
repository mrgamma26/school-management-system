# school_management_app

A Flutter school management application backed by Supabase.

```bash
cp env.example.json env.json
```

Open `env.json` and fill in your Supabase project values:

```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<your-publishable-key>"
}
```

> `env.json` is listed in `.gitignore` and must **never** be committed.

### 2. Run / build with the env file

```bash
# Development
flutter run --dart-define-from-file=env.json

# Specific environment file
flutter run --dart-define-from-file=env/dev.json

# Release build
flutter build apk --dart-define-from-file=env.json
flutter build ipa --dart-define-from-file=env.json
```

### 3. VS Code / Kiro

A `.vscode/launch.json` is included that passes `--dart-define-from-file=env.json`
automatically, so **F5 / Run and Debug** works without typing the flag each time.
Select the **"school_management_app (dev)"** configuration from the debug panel.

