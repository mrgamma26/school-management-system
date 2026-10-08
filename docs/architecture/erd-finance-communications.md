# Finance and communications ERD

This ERD covers confirmed finance, messaging, comments, and calendar persistence. Sources: migrations [`0008`](../../supabase/migrations/0008_finance_tables.sql), [`0009`](../../supabase/migrations/0009_comms_tables.sql), [`0012`](../../supabase/migrations/0012_calendar_event_type.sql), and [`0042`](../../supabase/migrations/0042_configurable_payment_channels.sql).

```mermaid
erDiagram
  ACADEMICYEAR ||--o{ FEESTRUCTURE : prices
  CLASS o|--o{ FEESTRUCTURE : scopes
  FEESTRUCTURE ||--o{ PAYMENT : paid_against
  STUDENT ||--o{ PAYMENT : makes
  STAFF ||--o{ PAYMENT : records
  PAYMENTCHANNEL o|--o{ PAYMENT : receives
  STUDENT ||--o{ FINANCIALADJUSTMENT : receives
  STAFF ||--o{ FINANCIALADJUSTMENT : approves
  GUARDIAN ||--o{ NOTIFICATION : receives
  STAFF ||--o{ NOTIFICATION : sends
  STUDENT ||--o{ TEACHERCOMMENT : has
  STAFF ||--o{ TEACHERCOMMENT : writes
  ACADEMICYEAR ||--o{ TEACHERCOMMENT : period
  CLASS o|--o{ CALENDAREVENT : targets
  ACADEMICYEAR o|--o{ CALENDAREVENT : period
  STAFF ||--o{ CALENDAREVENT : creates
```

The optional `CLASS` relationship allows school-wide fee structures after migration `0035` and school-wide calendar events. Payment method evidence is method-specific JSON plus safe top-level reference, channel, receipt, and processing-fee fields.
