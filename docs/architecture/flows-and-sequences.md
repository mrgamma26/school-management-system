# Data flows and key sequences

The data-flow diagram covers authentication, academic operations, assessment, finance, and progression. Sources: feature repositories under [`lib/features`](../../lib/features/) and migrations [`0036`](../../supabase/migrations/0036_three_term_progression.sql), [`0040`](../../supabase/migrations/0040_progression_and_grade_security.sql), and [`0042`](../../supabase/migrations/0042_configurable_payment_channels.sql).

```mermaid
flowchart LR
  User --> UI[Role-specific Flutter UI]
  UI --> AuthState[Auth and Riverpod state]
  UI --> Repo[Feature repository]
  Repo --> Q[PostgREST queries]
  Repo --> RPC[Trusted RPCs]
  Q --> RLS[RLS policies]
  RPC --> Rules[Database validation/business rules]
  RLS --> Data[(School data)]
  Rules --> Data
  Data --> Repo
  Repo --> UI
  UI --> User
```

## Authentication

```mermaid
sequenceDiagram
  actor User
  participant UI as LoginPage
  participant State as AuthNotifier
  participant Repo as AuthRepository
  participant SB as Supabase
  participant Router as GoRouter
  User->>UI: Email and password
  UI->>State: signIn
  State->>Repo: signIn
  Repo->>SB: Auth password sign-in
  Repo->>SB: Load systemuser and role
  SB-->>Repo: Session and profile
  Repo-->>State: AppUser
  State-->>Router: Auth state changed
  Router-->>User: Role dashboard or password-change page
```

## Assessment submission

```mermaid
sequenceDiagram
  actor Teacher
  participant UI as Assessment/Grade UI
  participant Repo as Repositories
  participant DB as Supabase DB
  Teacher->>UI: Select assigned class and subject
  UI->>Repo: Create assessment
  Repo->>DB: Insert assessment (RLS)
  Teacher->>UI: Enter scores and save draft
  UI->>Repo: Upsert grades
  Repo->>DB: Validate assignment and student subject
  Teacher->>UI: Submit grades
  UI->>Repo: submitAssessment
  Repo->>DB: Set eligible grades SUBMITTED
  DB-->>UI: Submission confirmed
```

## Payment recording

```mermaid
sequenceDiagram
  actor Accountant
  participant UI as RecordPaymentPage
  participant Repo as FinanceRepository
  participant RPC as record_payment_v2
  participant DB as PostgreSQL
  Accountant->>UI: Fee, amount, method, evidence
  UI->>Repo: recordPayment
  Repo->>RPC: Typed arguments + JSON details
  RPC->>RPC: Check role, dates, channel, method fields
  RPC->>DB: Insert payment and audit record
  DB-->>RPC: IDs
  RPC-->>UI: Generated receipt number
```

## Progression decision

```mermaid
sequenceDiagram
  actor Head as Head Teacher
  participant UI as ProgressionReviewsPage
  participant Repo as ProgressionRepository
  participant Calc as calculate/refresh RPC
  participant Decide as decide_and_place_student
  participant DB as PostgreSQL
  Head->>UI: Refresh annual review
  UI->>Repo: refreshAnnualReview
  Repo->>Calc: Student and school year
  Calc->>DB: Enrollment + submitted results + active rule
  Calc-->>UI: Term evidence, warnings, recommendation
  alt Complete
    Head->>UI: Promote/Retain + reason
    UI->>Decide: Review, decision, target period, reason
    Decide->>DB: Lock review and placement
    Decide->>DB: Update decision/placement/subjects/audit
    Decide-->>UI: Confirmed decision
  else Incomplete
    UI-->>Head: Decision disabled with missing-result warnings
  end
```
