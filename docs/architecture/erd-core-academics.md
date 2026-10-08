# Core and academics ERD

This ERD shows confirmed relational keys and cardinalities for identity, academics, assessment, and progression. Sources: [`0002_tables.sql`](../../supabase/migrations/0002_tables.sql), [`0033_student_subject_enrollments.sql`](../../supabase/migrations/0033_student_subject_enrollments.sql), and [`0036_three_term_progression.sql`](../../supabase/migrations/0036_three_term_progression.sql).

```mermaid
erDiagram
  ROLE ||--o{ SYSTEMUSER : grants
  ROLE ||--o{ ROLEPERMISSION : contains
  SYSTEMUSER ||--o| STAFF : profile
  SYSTEMUSER ||--o| GUARDIAN : profile
  STUDENT ||--o{ STUDENTGUARDIAN : linked
  GUARDIAN ||--o{ STUDENTGUARDIAN : linked
  STUDENT ||--o{ STUDENTCLASSHISTORY : placed
  CLASS ||--o{ STUDENTCLASSHISTORY : contains
  ACADEMICYEAR ||--o{ STUDENTCLASSHISTORY : period
  CLASS ||--o{ CLASSSUBJECT : has
  SUBJECT ||--o{ CLASSSUBJECT : teaches
  STAFF ||--o{ CLASSSUBJECT : assigned
  ACADEMICYEAR ||--o{ CLASSSUBJECT : period
  STUDENT ||--o{ STUDENTSUBJECT : enrolls
  CLASSSUBJECT ||--o{ STUDENTSUBJECT : includes
  CLASSSUBJECT ||--o{ ASSESSMENT : owns
  ASSESSMENT ||--o{ GRADE : receives
  STUDENT ||--o{ GRADE : earns
  STAFF ||--o{ GRADE : enters
  STUDENT ||--o{ PROGRESSIONREVIEW : reviewed
  PROGRESSIONRULE ||--o{ PROGRESSIONREVIEW : snapshot_applies
  STUDENT ||--o{ WEEDINGREVIEW : reviewed
```

`PROGRESSIONRULE` is stored in each review’s calculation snapshot rather than by a direct foreign key. Supabase Auth’s `auth.users` relation to `SYSTEMUSER.userid` is enforced operationally by the user lifecycle functions, not declared as a public-schema FK in the shown migrations.
