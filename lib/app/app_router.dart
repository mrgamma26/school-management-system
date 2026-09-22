// lib/app/app_router.dart
//
// Re-exports the central router provider so that app.dart can import
// from a single app-layer file, keeping the feature/core import boundary clean.

export '../core/router.dart' show routerProvider, homeForRole;
