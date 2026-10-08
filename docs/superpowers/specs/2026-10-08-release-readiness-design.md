# Release Readiness and Repository Synchronization Design

## Objective

Bring the current Flutter project to a verifiable release-ready repository state, document the final implementation, and synchronize the reviewed source to the GitHub `main` branch. No product behavior, role policy, database contract, or public route should change unless required to correct a confirmed defect.

## Compatibility repairs

### Fee structure contract

Fee structures are school-wide after migration `0035_school_wide_fee_structures.sql`. The Dart model correctly omits class-specific fields, while an older test still expects `classId`, `className`, and a four-key insert payload. Update the test to verify the current school-wide contract: academic period, fee type, amount, and a three-key insert payload.

### Calendar interaction tests

Calendar tests currently locate a day using visible date text. Multiple widgets can contain the same number, and the selected text child is not a reliable pointer target. Give each interactive day cell a deterministic value key derived from its date and update tests to tap or long-press that cell. This improves testability and accessibility diagnostics without changing user-visible behavior.

### Static-analysis cleanup

Resolve all reported warnings and informational lints with local, behavior-preserving edits: remove unused imports/locals/elements, use braces, replace deprecated form-field initialization, avoid unsafe context use across asynchronous gaps, use approved logging, and normalize private callback parameter names. Do not introduce dependencies or broad architectural rewrites.

## Verification

The release gate is:

1. `dart format` reports no changed Dart file requiring formatting.
2. `flutter analyze` exits successfully with no findings.
3. `flutter test` exits successfully with the complete test suite passing.
4. Documentation links resolve and Mermaid blocks remain balanced.
5. `git diff --check` passes for the files selected for release.
6. A repository audit excludes environment files, credentials, generated builds, dependency caches, temporary automation, editor-local state, backups, and scratch files.
7. A case-insensitive source scan finds no references to prohibited assistant or editor-product names.

## Repository synchronization

Preserve the project’s current source, migrations, tests, documentation, and platform files. Remove only confirmed temporary or backup artifacts. Review the complete staged file list and secret scan before committing. Push the verified commit history to `main` without rewriting history or force-pushing.

## User-manual operating sequence

Document the system as a dependency-ordered school workflow rather than a disconnected list of screens. For every role, identify the outcome that role owns, the records that must exist first, the exact task sequence, the evidence of success, and the next role that consumes the result. The primary order is Super User, Administrator, parallel Teacher and Accountant work, Head Teacher progression after Teacher submission, then Guardian verification. Calendar and communication work is ongoing across the year.

## Failure handling

If analysis or tests still fail, do not push `main`; report and repair the failure first. If GitHub rejects a normal push because the branch is protected or remote history changed, stop and report the exact blocker rather than bypassing protection.
