# User List Deactivation Design

## Goal

Allow a Super User to safely deactivate an account directly from User
Management without deleting historical school data.

## Behaviour

- Each user row shows a red deactivation icon only to a Super User.
- The current Super User cannot deactivate their own account.
- Tapping the icon opens a confirmation dialog naming the target user and
  explaining that the account will no longer be able to sign in.
- Confirming calls the existing privileged `delete-user` Edge Function, which
  sets `systemuser.isactive` to `false`; no Auth, staff, guardian, grade,
  payment, or audit records are hard-deleted.
- After a successful response, User Management refreshes and the row displays
  its existing `INACTIVE` status.

## Security and validation

The client only renders the action for a Super User, and the Edge Function
independently enforces the same server-side role check. The UI displays a
friendly error if the function is unavailable or rejects the request.

## Testing

- Super User sees the action for another active user and can deactivate them.
- Confirmation cancel makes no change.
- The target user can no longer sign in and remains visible as inactive.
- Other roles never see the action.
- A Super User cannot deactivate their own account.
