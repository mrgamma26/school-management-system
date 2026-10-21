import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../theme/app_tokens.dart';
import '../../../settings/presentation/settings_providers.dart';
import '../providers/auth_provider.dart';

/// Login entry point — credentials are validated through [AuthNotifier].
/// Navigation after login is handled by the central [GoRouter] redirect.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    if (mounted) _passwordCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final branding = ref
        .watch(schoolBrandingProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final logoUrl = ref
        .watch(schoolSettingsRepositoryProvider)
        .publicLogoUrl(branding?.logoPath);
    final schoolName = branding?.schoolName ?? AppStrings.appName;
    final motto = branding?.motto;

    final brand = _BrandPanel(
      schoolName: schoolName,
      motto: motto,
      logoUrl: logoUrl,
      compact: !wide,
    );
    final card = _LoginCard(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      obscure: _obscure,
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onSubmit: _login,
      loading: authState.isLoading,
      error: authState.errorMessage,
      schoolName: schoolName,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: brand),
                Expanded(
                  flex: 9,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: card,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  brand,
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: card,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Navy brand panel ─────────────────────────────────────────────────────────

class _BrandPanel extends StatelessWidget {
  final String schoolName;
  final String? motto;
  final String? logoUrl;
  final bool compact;

  const _BrandPanel({
    required this.schoolName,
    required this.motto,
    required this.logoUrl,
    required this.compact,
  });

  String get _initials {
    final words = schoolName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return AppStrings.appInitial;
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logoUrl != null
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _initialsText(),
              ),
            )
          : _initialsText(),
    );

    // The editable school name is the main headline below, so the top of the
    // blue panel only needs the logo and does not repeat any text.
    final header = Align(alignment: Alignment.centerLeft, child: logo);

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          schoolName,
          style: TextStyle(
            fontSize: compact ? 28 : 44,
            height: 1.08,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            'A shared workspace for guardians, teachers, and school staff.',
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB9D7F8),
            ),
          ),
        ),
      ],
    );

    final footer = Text(
      (motto == null || motto!.trim().isEmpty)
          ? 'Knowledge · Character · Service'
          : motto!,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: Color(0xFF8FB8E8),
      ),
    );

    return Container(
      color: AppColors.navy,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MotifPainter())),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 48),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, const SizedBox(height: 28), headline],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [header, headline, footer],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _initialsText() => Text(
    _initials,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      color: AppColors.primaryDark,
    ),
  );
}

/// Decorative circles + dot grid on the navy panel.
class _MotifPainter extends CustomPainter {
  const _MotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.05);

    final c = Offset(size.width * 0.92, size.height * 0.88);
    canvas.drawCircle(c, size.shortestSide * 0.62, fill);
    canvas.drawCircle(c, size.shortestSide * 0.62, ring);
    canvas.drawCircle(c, size.shortestSide * 0.42, ring);
    canvas.drawCircle(c, size.shortestSide * 0.22, ring);

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.16);
    const gap = 18.0;
    final ox = size.width - 8 * gap - 28;
    for (var r = 0; r < 6; r++) {
      for (var col = 0; col < 8; col++) {
        canvas.drawCircle(Offset(ox + col * gap, 28 + r * gap), 1.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Sign-in card ─────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool loading;
  final String? error;
  final String schoolName;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.loading,
    required this.error,
    required this.schoolName,
  });

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0D47A1),
            blurRadius: 48,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WELCOME BACK',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in ',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            _label('Email address'),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'Enter your email',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                if (!v.contains('@')) return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Password'),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                  ),
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password is required.' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign in '),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text(
                  'Need help signing in?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '© ${DateTime.now().year} $schoolName',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
