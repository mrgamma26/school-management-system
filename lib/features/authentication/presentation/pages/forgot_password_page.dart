import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';

/// FIX 2: Forgot Password Page
/// Allows users to request a password reset email.
/// Uses Supabase built-in password reset functionality.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: Uri.base.resolve('/reset-password').toString(),
      );

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send reset email. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: _emailSent ? _successView() : _formView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String kicker, String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            'Account help',
            'Forgot Password?',
            "Enter your email address and we'll send you instructions to reset your password.",
          ),
          const SizedBox(height: 22),
          UiField(
            label: 'Email address',
            child: TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _requestReset(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                hintText: 'you@school.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required.';
                }
                if (!v.contains('@')) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
          ),
          if (_errorMessage != null)
            UiNotice(_errorMessage!, icon: Icons.error_outline_rounded),
          const SizedBox(height: 22),
          UiButton(
            _isLoading ? 'Sending…' : 'Send Reset Link',
            expand: true,
            onPressed: _isLoading ? null : _requestReset,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Reset requested',
          'Check Your Email',
          "We've sent password reset instructions to ${_emailCtrl.text.trim()}.",
        ),
        const InlineGuide(
          title: 'Next steps.',
          text:
              '1. Check your inbox and spam folder. 2. Click the reset link in the email. '
              '3. Create a new password. 4. Sign in with your new password.',
        ),
        const SizedBox(height: 22),
        UiButton(
          'Back to Login',
          expand: true,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _emailSent = false;
            _errorMessage = null;
          }),
          child: const Text("Didn't receive the email? Try again"),
        ),
      ],
    );
  }
}
