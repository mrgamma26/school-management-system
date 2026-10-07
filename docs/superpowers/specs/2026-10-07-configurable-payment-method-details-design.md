# Configurable Payment Method Details

## Goal

Capture sufficient audit and reconciliation evidence for every payment method
without displaying irrelevant fields. Administrators configure reusable receiving
channels, accountants record payments, and guardians see the resulting receipt
and payment history.

## Roles

- Administrators and Super Users manage payment-channel configuration.
- Accountants record payments against active configured channels.
- Guardians may view payments for linked students but cannot edit transaction
  evidence.
- Other roles cannot configure channels or record payments.

## Administrator Payment Configuration

Add a **Payment Configuration** destination to the Administrator and Super User
navigation. The page contains three independently managed sections:

1. **Bank Accounts**: display label, bank name, account name, masked account
   number, currency, and active state.
2. **Card Channels**: display label, POS/online type, provider name,
   terminal/merchant identifier, and active state.
3. **Mobile Money Wallets**: display label, provider, masked merchant till or
   wallet number, and active state.

Configuration records are deactivated rather than deleted when referenced by a
payment. Inactive records remain readable in historical payment evidence but
cannot be selected for a new transaction. Configuration creates and updates are
written to the audit log. Passwords, API keys, PINs, and full card numbers are
never collected.

## Accountant Payment Form

The primary payment-method dropdown controls the method-specific portion of the
form. Changing the method clears incompatible channel selections and validation
errors. Common fields remain student, fee type, gross amount, method, payment
date, and optional payer note.

### Cash

No receiving channel is required. A payer reference is optional. The school
receipt is generated automatically.

### Bank Transfer

Require an active receiving bank account, payer bank name, transaction
reference/UTR, and value or clearance date. Accept an optional non-negative bank
or intermediary fee.

### Cheque

Require a six-digit cheque number, drawee bank and branch, cheque date, deposit
date, and one of `PENDING_CLEARANCE`, `CLEARED`, `POST_DATED`, or
`BOUNCED_RETURNED`. Accept an optional deposit-slip reference. Cheque evidence
does not link to a receiving channel.

### Card

Require an active card channel, card network (`VISA`, `MASTERCARD`,
`AMERICAN_EXPRESS`, or `LOCAL_DEBIT`), exactly four numeric card-ending digits,
and an authorization/approval code. Accept an optional non-negative processing
fee. Never accept or persist a full primary account number or CVV.

### Mobile Money

Require an active wallet whose configured provider is Airtel Money or TNM
Mpamba, a transaction/SMS reference, a valid sender phone number, and the exact
transaction timestamp. The wallet selection supplies the receiving merchant
till or wallet number.

### Other

Require a transaction description and an external reference.

## Persistence and Validation

Use reusable payment-channel records for bank, card, and mobile-money receiving
destinations. Each payment links to at most one channel and stores its typed
transaction evidence as structured JSON, plus a separate non-negative
processing-fee value. Existing `referencenumber` remains the searchable external
reference. Existing payments remain readable after migration.

Create one security-definer database function for payment creation. It must:

1. Confirm the caller is an active Accountant or otherwise has the existing
   payment-write permission.
2. Confirm the fee, student, and staff actor exist.
3. Confirm any selected channel is active and belongs to the chosen method.
4. Validate every required method-specific key and value.
5. Reject a duplicate non-empty external reference for the same method and
   receiving channel.
6. Generate a collision-safe school receipt number.
7. Insert the payment and audit record in one transaction.

The application calls this function rather than performing a direct payment
insert. Server errors are mapped to clear field or form messages. A failed
validation creates neither a payment nor an audit record.

## Receipt and History

Every successful payment receives a unique school receipt number regardless of
method. Non-cash methods also retain their external transaction proof. All
Payments, the student account, and guardian Payment History show the gross
amount, method, generated receipt, external reference where appropriate, and a
safe summary of the receiving channel. Sensitive or unnecessary transaction
details are not exposed to guardians.

## Testing

- Create, update, deactivate, and list each channel type as Administrator.
- Confirm Accountant can select active channels but not inactive channels.
- Record Cash, Bank Transfer, Cheque, Card, Mobile Money, and Other payments.
- Verify required-field, format, date, non-negative-fee, inactive-channel, and
  duplicate-reference failures.
- Verify card inputs cannot accept more than four ending digits and no full card
  number or CVV is stored.
- Verify generated receipts are unique and visible in All Payments, student
  history, guardian history, and the audit log.
- Verify unauthorized roles cannot manage configuration or record payments.
- Verify historical payments remain readable after a channel is deactivated.

## Out of Scope

This feature does not connect to bank, card-gateway, or mobile-money APIs; settle
funds automatically; store gateway secrets; or perform automatic cheque
clearance. Those integrations can consume the same configuration model later.
