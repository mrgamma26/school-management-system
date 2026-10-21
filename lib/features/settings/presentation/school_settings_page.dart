import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../theme/app_tokens.dart';
import '../../../widgets/ui_kit.dart';
import '../../academics/data/academic_calendar_repository.dart';
import '../../academics/domain/models/academic_calendar.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../domain/school_settings.dart';
import 'settings_providers.dart';

final _currentAcademicYearProvider = FutureProvider<AcademicCalendarYear?>(
  (ref) => AcademicCalendarRepository().currentYear(),
);

class SchoolSettingsPage extends ConsumerWidget {
  const SchoolSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(schoolSettingsProvider);
    return settings.when(
      loading: () => const UiPage(
        children: [
          PageHead(kicker: 'Administration', title: 'School Settings'),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading settings…'),
          ),
        ],
      ),
      error: (error, _) => UiPage(
        children: [
          const PageHead(kicker: 'Administration', title: 'School Settings'),
          ErrorState(
            error: error,
            onRetry: () => ref.invalidate(schoolSettingsProvider),
          ),
        ],
      ),
      data: (value) => _SettingsForm(initial: value),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final SchoolSettings initial;
  const _SettingsForm({required this.initial});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String _carryForward;
  String? _logoPath;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _logoPath = s.logoPath;
    _carryForward = s.balanceCarryForwardPolicy;
    _controllers = {
      'name': TextEditingController(text: s.schoolName),
      'motto': TextEditingController(text: s.motto),
      'physical': TextEditingController(text: s.physicalAddress),
      'postal': TextEditingController(text: s.postalAddress),
      'phone': TextEditingController(text: s.phoneNumber),
      'email': TextEditingController(text: s.emailAddress),
      'website': TextEditingController(text: s.website),
      'currency': TextEditingController(text: s.defaultCurrency),
      'footer': TextEditingController(text: s.receiptFooter),
      'methods': TextEditingController(
        text: s.acceptedPaymentMethods.join(', '),
      ),
      'overdue': TextEditingController(text: s.overdueDayOfTerm?.toString()),
      'maxMb': TextEditingController(
        text: (s.depositSlipMaxBytes / 1048576).round().toString(),
      ),
      'mimes': TextEditingController(text: s.depositSlipMimeTypes.join(', ')),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickLogo() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (file == null) return;
    final length = file.lengthSync() ?? await file.length();
    if (length == null || length > 2097152) {
      setState(
        () => _error =
            'The school logo must be a PNG, JPEG, or WebP image no larger than 2 MB.',
      );
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final mime = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path = await ref
          .read(schoolSettingsRepositoryProvider)
          .uploadLogo(
            bytes: await file.readAsBytes(),
            extension: extension,
            mimeType: mime,
          );
      setState(() => _logoPath = path);
    } catch (error) {
      setState(() => _error = 'Logo upload failed: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final methods = _controllers['methods']!.text
        .split(',')
        .map((item) => item.trim().toUpperCase().replaceAll(' ', '_'))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final mimes = _controllers['mimes']!.text
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.startsWith('image/'))
        .toSet()
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = SchoolSettings(
        settingsId: widget.initial.settingsId,
        schoolName: _controllers['name']!.text,
        logoPath: _logoPath,
        motto: _optional(_controllers['motto']!),
        physicalAddress: _optional(_controllers['physical']!),
        postalAddress: _optional(_controllers['postal']!),
        phoneNumber: _optional(_controllers['phone']!),
        emailAddress: _optional(_controllers['email']!),
        website: _optional(_controllers['website']!),
        defaultCurrency: _controllers['currency']!.text,
        receiptFooter: _optional(_controllers['footer']!),
        studentMinimumAge: 9,
        studentMaximumAge: null,
        staffMinimumAge: 18,
        acceptedPaymentMethods: methods,
        balanceCarryForwardPolicy: _carryForward,
        overdueDayOfTerm: int.tryParse(_controllers['overdue']!.text),
        depositSlipMaxBytes: int.parse(_controllers['maxMb']!.text) * 1048576,
        depositSlipMimeTypes: mimes,
      );
      await ref
          .read(schoolSettingsRepositoryProvider)
          .updateSettings(settings, user.userId);
      ref.invalidate(schoolSettingsProvider);
      ref.invalidate(schoolBrandingProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School settings saved.')));
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = ref
        .read(schoolSettingsRepositoryProvider)
        .publicLogoUrl(_logoPath);
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AcademicContext(year: ref.watch(_currentAcademicYearProvider)),
          _Section(
            title: 'School identity',
            children: [
              _field('name', 'School name *', required: true),
              _field('motto', 'School motto'),
              Row(
                children: [
                  if (logoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.md),
                      child: Image.network(
                        logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  UiButton.secondary(
                    'Upload logo',
                    icon: Icons.upload_outlined,
                    onPressed: _saving ? null : _pickLogo,
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Contact details',
            children: [
              _field('physical', 'Physical address'),
              _field('postal', 'Postal address'),
              _field('phone', 'Phone number', malawianPhone: true),
              _field('email', 'Email address', email: true),
              _field('website', 'Website'),
            ],
          ),
          _Section(
            title: 'Finance defaults',
            children: [
              _field(
                'currency',
                'Currency code *',
                required: true,
                maxLength: 3,
              ),
              _field(
                'methods',
                'Accepted payment methods *',
                required: true,
                helper:
                    'Comma-separated, for example CASH, BANK_DEPOSIT, MOBILE_MONEY',
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: UiField(
                  label: 'Balance carry-forward policy *',
                  child: DropdownButtonFormField<String>(
                    initialValue: _carryForward,
                    items: const [
                      DropdownMenuItem(
                        value: 'NONE',
                        child: Text('Do not carry forward'),
                      ),
                      DropdownMenuItem(
                        value: 'NEXT_TERM',
                        child: Text('Next term'),
                      ),
                      DropdownMenuItem(
                        value: 'NEXT_ACADEMIC_YEAR',
                        child: Text('Next academic year'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _carryForward = value!),
                  ),
                ),
              ),
              _field(
                'overdue',
                'Mid-term overdue day',
                number: true,
                helper: 'Optional day number within a term.',
              ),
              _field('footer', 'Receipt footer'),
            ],
          ),
          _Section(
            title: 'Validation and evidence',
            children: [
              const DetailLine('Student minimum age', '9 years'),
              const DetailLine('Student maximum age', 'Not configured'),
              const DetailLine('Staff minimum age', '18 years'),
              const SizedBox(height: Sp.md),
              _field(
                'maxMb',
                'Deposit-slip maximum size (MB) *',
                required: true,
                number: true,
              ),
              _field(
                'mimes',
                'Permitted deposit-slip MIME types *',
                required: true,
              ),
            ],
          ),
          if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
        ],
      ),
    );
    return UiPage(
      children: [
        PageHead(
          kicker: 'Administration',
          title: 'School Settings',
          subtitle: 'Identity, contact and finance defaults used across the app.',
          actions: [
            UiButton(
              _saving ? 'Saving…' : 'Save settings',
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        SplitLayout(
          breakpoint: 1000,
          main: form,
          side: _LoginPreview(
            name: _controllers['name']!.text,
            motto: _controllers['motto']!.text,
            logoUrl: logoUrl,
          ),
        ),
      ],
    );
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool email = false,
    bool number = false,
    bool malawianPhone = false,
    int? maxLength,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.md),
    child: UiField(
      label: label,
      child: TextFormField(
      controller: _controllers[key],
      keyboardType: number
          ? TextInputType.number
          : email
          ? TextInputType.emailAddress
          : TextInputType.text,
      maxLength: maxLength,
      decoration: InputDecoration(helperText: helper),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) {
          return '$label is required.';
        }
        if (email &&
            text.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Enter a valid email address.';
        }
        if (malawianPhone && text.isNotEmpty) {
          final compact = text.replaceAll(RegExp(r'[\s()-]'), '');
          if (!RegExp(r'^(?:\+265|0)[89]\d{8}$').hasMatch(compact)) {
            return 'Enter a valid Malawian phone number.';
          }
        }
        return null;
      },
    ),
    ),
  );
}

class _AcademicContext extends StatelessWidget {
  final AsyncValue<AcademicCalendarYear?> year;

  const _AcademicContext({required this.year});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Current academic context',
      children: [
        year.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Academic context is unavailable.'),
          data: (value) {
            final currentTerm = value?.terms
                .where((term) => term.isCurrent)
                .firstOrNull;
            return QueueItem(
              icon: Icons.calendar_month_outlined,
              title: value?.name ?? 'No current academic year',
              subtitle: currentTerm?.name ?? 'No current term selected',
              pill: const StatusPill('Managed in Academic Years'),
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.md),
    child: FormPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _LoginPreview extends StatelessWidget {
  final String name;
  final String motto;
  final String? logoUrl;
  const _LoginPreview({
    required this.name,
    required this.motto,
    required this.logoUrl,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Sp.xl),
    decoration: BoxDecoration(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LIVE LOGIN PREVIEW',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: Sp.xl),
        if (logoUrl != null)
          Image.network(
            logoUrl!,
            width: 88,
            height: 88,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.school, color: Colors.white, size: 64),
          )
        else
          const Icon(Icons.school, color: Colors.white, size: 64),
        const SizedBox(height: Sp.lg),
        Text(
          name.trim().isEmpty ? 'School Management System' : name.trim(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (motto.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Sp.sm),
            child: Text(
              motto.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    ),
  );
}
