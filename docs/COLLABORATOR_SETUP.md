# Collaborator Setup and Handoff

This guide lets another developer clone, run, test, and safely contribute to the School Management System. The safest default is an isolated local Supabase stack; it does not expose production records or require shared server secrets.

## 1. Owner handoff checklist

Before inviting a collaborator:

1. Commit and push the exact changes they should test. Uncommitted files remain only on the owner's computer.
2. Invite the collaborator from the GitHub repository settings if they need direct push access.
3. Agree on a branch and pull-request workflow.
4. Choose either the isolated local setup or a dedicated hosted development Supabase project.
5. Never send service-role keys, secret keys, SMTP passwords, production user passwords, or real school data.
6. If hosted testing is required, create the collaborator's application account from User Management and send the temporary password separately from the account email.

## 2. Prerequisites

Install:

- Git
- Flutter SDK compatible with the SDK constraint in `pubspec.yaml`
- Microsoft Edge or Chrome for web testing
- PowerShell 7 on Windows
- Docker Desktop or another Docker-compatible runtime
- Supabase CLI

Confirm the tools are available:

```text
git --version
flutter --version
docker --version
supabase --version
pwsh --version
```

## 3. Clone the project

```text
git clone https://github.com/mrgamma26/school-management-system.git
cd school-management-system
git switch -c feature/your-change
```

If the repository is private, accept the GitHub invitation before cloning.

## 4. Recommended local setup

Start Docker, then run:

```powershell
.\scripts\setup-local.ps1
```

The script performs these local-only actions:

- starts Supabase;
- resets the local database from all committed migrations and `supabase/seed.sql`;
- reads the local API URL and publishable or anon key from the Supabase CLI;
- writes those client values to ignored `env/dev.json`;
- creates or links `admin@local.school` as a local Super User; and
- prints a temporary password only if a new Auth account was created.

The local database reset deletes existing local data. It does not target a linked cloud project. After the first login, change the temporary password. Then use User Management to create fictional Teacher, Head Teacher, Accountant, Administrator, and Guardian accounts. Students have records but do not have login accounts.

Local email is captured by Supabase Mailpit rather than sent to real recipients. The Supabase CLI prints the local Studio and Mailpit URLs after startup.

## 5. Hosted development setup

Use a dedicated development project, never the production project.

1. Copy `env/dev.example.json` to `env/dev.json`.
2. Ask the owner for the development `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
3. Put them only in `env/dev.json`.
4. Ask the owner to create your application account with the correct role.
5. Sign in with the temporary password sent through a separate secure channel and change it when prompted.

The client does not need a service-role key. Supabase supplies privileged runtime keys to deployed Edge Functions. Email-provider credentials are configured by the deployment owner and are not shared with ordinary collaborators.

## 6. Run the application

```powershell
.\run-dev.ps1
```

Manual equivalent:

```text
flutter pub get
flutter run -d edge --web-port=8080 --dart-define-from-file=env/dev.json --no-web-resources-cdn
```

For release mode:

```powershell
.\run-release.ps1
```

## 7. Create test users and sign in

Only a Super User or authorized Administrator creates application users.

1. Sign in as the local or development Super User.
2. Open User Management and select Create User.
3. Choose the role and account type, then enter fictional profile details.
4. Save the user and copy the one-time temporary password.
5. Send the email and password through separate approved channels.
6. The new user signs in with the temporary password, changes it when prompted, and is routed to the dashboard for the assigned role.

A Teacher may also serve as Head Teacher, but one account has one active application role at a time. Use separate development accounts when both dashboards must be tested independently.

## 8. Minimum role workflow test

1. Super User creates the required staff and Guardian accounts.
2. Administrator creates one shared academic year and Terms 1, 2, and 3 with valid dates, then creates Forms 1 to 4, subjects, and teacher assignments.
3. Administrator registers a student, links a Guardian, places the student in a class, and enrolls the student in subjects.
4. Accountant configures or uses an approved payment channel, creates the fee structure, and records a payment.
5. Teacher creates an assessment, enters grades, and submits the results.
6. Head Teacher reviews complete annual evidence and records progression when all required term results exist.
7. Guardian verifies payment history, notifications, academic progress, report-card access rules, and progression. Students do not sign in.

## 9. Verification before a pull request

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=env/dev.json --no-web-resources-cdn
```

For database changes:

```text
supabase start
supabase db reset
```

Create a new migration for every schema change. Do not edit migrations that other collaborators may already have applied.

## 10. Common problems

- **Missing `env/dev.json`:** run `scripts/setup-local.ps1` or copy the example and add development client values.
- **Supabase cannot start:** confirm Docker is running and the configured ports are free.
- **Sign-in succeeds but no dashboard appears:** confirm the Auth user has an active `systemuser` row and the correct role.
- **An empty teacher roster:** confirm the class, subject, academic period, teacher assignment, student placement, and student-subject enrollment all match.
- **A Guardian sees no student:** confirm the `studentguardian` link exists.
- **Email does not arrive locally:** inspect Mailpit. Do not add production SMTP credentials just to test locally.
- **Migration history differs:** compare migration lists and ask the owner before any repair. Never reset a linked remote database without explicit approval.

## 11. What must stay private

Do not place real values in documentation, issues, pull requests, screenshots, or chat. Keep these private: service-role or secret keys, SMTP passwords, email-provider API keys, user passwords, signing files, bank details, deposit slips, and identifiable student or guardian records.

The repository intentionally provides key names and safe locations instead of real secrets. See `SECURITY.md` for the complete handling rules.
