# Existing Guardian Registration Design

## Goal

When registering a student, staff can link one or more already registered
parents or guardians, create new guardians, or do both in one registration.
This prevents duplicate guardian accounts when siblings attend the school.

## Registration interface

The Guardians section gains a `Link Existing Parent or Guardian` action above
the new-guardian forms. It opens a searchable selection dialog populated with
registered guardians.

For every selected guardian, the form shows a compact link entry with:

- guardian name and identifying contact information;
- a relationship field, defaulting to `Parent`;
- a remove action before registration is saved.

Selected guardians cannot be selected again. New guardian forms remain
available and may be completed alongside existing guardian links.

## Save behavior

Registration requires at least one guardian across both selected existing
guardians and completed new guardian forms.

After the student has been created, the app links each selected existing
guardian through `studentguardian` with the chosen relationship. It does not
create a new authentication user, password, or guardian row for them.

New guardian forms keep the existing account creation and credentials dialog.
The registration workflow prevents duplicate student-guardian pairs. Every
existing guardian link is audit logged with the current staff user.

## Failure and retry behavior

If linking fails after the student is created, the existing partial-save retry
flow remains active. Successful links are tracked in the live form so retrying
does not insert them twice.

## Verification

- A sibling can be registered using one existing guardian only.
- An existing guardian and a newly created guardian can both be linked.
- Duplicate selection and duplicate `studentguardian` links are prevented.
- No account credentials dialog appears for an existing guardian.
- Existing guardian links appear in the student's Guardian Links page.
