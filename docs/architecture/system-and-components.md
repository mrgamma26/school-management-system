# System context and components

This diagram includes user roles, the Flutter client, Supabase boundaries, and external email delivery. Implementations: [`lib/main.dart`](../../lib/main.dart), [`lib/core/router.dart`](../../lib/core/router.dart), [`supabase/functions`](../../supabase/functions/).

```mermaid
flowchart LR
  Users[School users<br/>Admins, Head Teachers,<br/>Teachers, Accountants, Guardians]
  App[Flutter application<br/>Web and platform clients]
  Auth[Supabase Auth]
  API[Supabase PostgREST and RPC]
  DB[(PostgreSQL<br/>tables, RLS, functions)]
  EF[Supabase Edge Functions]
  Mail[Email provider]
  Users --> App
  App --> Auth
  App --> API
  API --> DB
  App --> EF
  EF --> Auth
  EF --> DB
  EF --> Mail
```

The component diagram shows the principal in-process responsibilities. Feature repositories and some page-local providers share the same Supabase boundary.

```mermaid
flowchart TB
  Entry[main.dart / SchoolApp] --> Router[GoRouter + role guards]
  Entry --> State[Riverpod providers/notifiers]
  Router --> UI[Feature pages and dashboards]
  State --> UI
  UI --> Repos[Feature repositories]
  UI --> Shared[Shared widgets, theme, utilities]
  Repos --> Client[Global Supabase client]
  Client --> Backend[Auth / PostgREST / RPC / Functions]
```
