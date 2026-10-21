import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../providers/auth_provider.dart';

/// Forces a password change when [AppUser.mustChangePassword] is true.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Always validate: length, no edge spaces, and new == confirm.
    if (!_formKey.currentState!.validate()) return;
    final newPassword = _newPasswordController.text;

    final success = await ref
        .read(authProvider.notifier)
        .changePassword(newPassword);

    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        context.go(homeForRole(user.roleName));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Standalone route (outside the app shell), so it keeps its own Scaffold.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: UiCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ACCOUNT SECURITY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Set a New Password',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose your own password to replace the temporary one you were emailed. '
                        'You will use this new password every time you sign in.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      UiField(
                        label: 'New password',
                        child: TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            hintText: 'At least 8 characters',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 19,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 19,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                              tooltip: _obscureNew
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) {
                              return 'Password is required.';
                            }
                            if (password != password.trim()) {
                              return 'Password cannot start or end with a space.';
                            }
                            if (password.length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      UiField(
                        label: 'Confirm new password',
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: 'Repeat the new password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 19,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 19,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              tooltip: _obscureConfirm
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) {
                            final confirm = value ?? '';
                            if (confirm.isEmpty) {
                              return 'Please confirm your password.';
                            }
                            if (confirm != _newPasswordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (authState.errorMessage != null)
                        UiNotice(
                          authState.errorMessage!,
                          icon: Icons.error_outline_rounded,
                        ),
                      const SizedBox(height: 22),
                      UiButton(
                        authState.isLoading ? 'Saving…' : 'Set Password',
                        expand: true,
                        onPressed: authState.isLoading ? null : _submit,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: authState.isLoading
                            ? null
                            : () => ref.read(authProvider.notifier).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
