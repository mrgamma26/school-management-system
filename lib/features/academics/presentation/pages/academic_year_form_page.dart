import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../widgets/ui_kit.dart';
import '../../data/academic_calendar_repository.dart';
import '../../domain/models/academic_calendar.dart';
import '../../../../core/navigation/close_form.dart';

/// Screen 19 - Create or edit an academic year with its three terms.
class AcademicYearFormPage extends StatefulWidget {
  final AcademicCalendarYear? existing;

  const AcademicYearFormPage({this.existing, super.key});

  @override
  State<AcademicYearFormPage> createState() => _AcademicYearFormPageState();
}

class _AcademicYearFormPageState extends State<AcademicYearFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AcademicCalendarRepository();
  late final TextEditingController _nameController;
  late final List<AcademicTermDraft> _terms;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _makeCurrent = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final year = widget.existing;
    _nameController = TextEditingController(text: year?.name ?? '');
    _startDate = year?.startDate;
    _endDate = year?.endDate;
    _makeCurrent = year?.isCurrent ?? false;
    _terms = ['TERM_1', 'TERM_2', 'TERM_3'].map((code) {
      AcademicTermPeriod? period;
      for (final item in year?.terms ?? const <AcademicTermPeriod>[]) {
        if (item.code == code) period = item;
      }
      return AcademicTermDraft(
        code,
        startDate: period?.startDate,
        endDate: period?.endDate,
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int? get _academicStartYear => parseAcademicStartYear(_nameController.text);

  Future<DateTime?> _pick(DateTime? value) {
    final startYear = _academicStartYear;
    final firstDate = DateTime(startYear ?? 2020);
    final lastDate = DateTime(2100, 12, 31);
    final preferred =
        value ??
        (startYear == null ? DateTime.now() : DateTime(startYear, 1, 1));
    final initialDate = preferred.isBefore(firstDate)
        ? firstDate
        : (preferred.isAfter(lastDate) ? lastDate : preferred);
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  String? _validateDates() {
    return validateAcademicCalendarDraft(
      academicStartYear: _academicStartYear,
      yearStart: _startDate,
      yearEnd: _endDate,
      terms: _terms,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final validation = _validateDates();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.saveYear(
        id: widget.existing?.id,
        name: canonicalAcademicYearName(_nameController.text)!,
        startDate: _startDate!,
        endDate: _endDate!,
        terms: _terms,
        makeCurrent: _makeCurrent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic year and all three terms saved.'),
        ),
      );
      closeForm(context, '/academics/years', true);
    } catch (error) {
      setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPageLayout(
      kicker: 'Academics',
      title: widget.existing == null
          ? 'Create Academic Year'
          : 'Edit Academic Year',
      subtitle: 'Set the year and all three valid non-overlapping terms.',
      formTitle: 'Year details',
      saving: _saving,
      saveLabel: 'Save academic year',
      onSave: _submit,
      error: _error,
      guideTitle: 'Term rules:',
      guide:
          'All three terms are required, must stay inside the year, and cannot overlap.',
      sideTitle: 'Checks before saving',
      side: const [
        CheckRow(label: 'One year serves Forms 1 to 4', checked: true),
        CheckRow(label: 'Terms 1, 2 and 3 are all required', checked: true),
        CheckRow(label: 'Term dates stay inside the year', checked: true),
        CheckRow(label: 'Terms cannot overlap', checked: true),
      ],
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldGrid(
              children: [
                FullWidth(
                  child: UiField(
                    label: 'Academic year name *',
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: '2026/2027'),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Academic year name is required.';
                        }
                        final year = parseAcademicStartYear(value);
                        if (year == null || year < 2020 || year > 2099) {
                          return 'Enter a year such as 2027 or 2027/2028.';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                _DateField(
                  label: 'Year starts *',
                  value: _startDate,
                  onTap: () async {
                    final value = await _pick(_startDate);
                    if (value != null) setState(() => _startDate = value);
                  },
                ),
                _DateField(
                  label: 'Year ends *',
                  value: _endDate,
                  onTap: () async {
                    final value = await _pick(_endDate);
                    if (value != null) setState(() => _endDate = value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Term dates',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FieldGrid(
              children: [
                for (final term in _terms) ...[
                  _DateField(
                    label: '${term.label} starts *',
                    value: term.startDate,
                    onTap: () async {
                      final value = await _pick(term.startDate);
                      if (value != null) setState(() => term.startDate = value);
                    },
                  ),
                  _DateField(
                    label: '${term.label} ends *',
                    value: term.endDate,
                    onTap: () async {
                      final value = await _pick(term.endDate);
                      if (value != null) setState(() => term.endDate = value);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make this the current academic year'),
              subtitle: const Text(
                'This replaces the previously current year after validation.',
              ),
              value: _makeCurrent,
              onChanged: (value) => setState(() => _makeCurrent = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => UiField(
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? 'Select date' : formatUiDate(value)),
      ),
    ),
  );
}
