import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/academic_year.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Create or edit an academic year.
class AcademicYearFormPage extends ConsumerStatefulWidget {
  final AcademicYear? existing;

  const AcademicYearFormPage({this.existing, super.key});

  @override
  ConsumerState<AcademicYearFormPage> createState() =>
      _AcademicYearFormPageState();
}

class _AcademicYearFormPageState extends ConsumerState<AcademicYearFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AcademicRepository();

  late final TextEditingController _yearCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  String _term = 'TERM_1';
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _yearCtrl = TextEditingController(text: existing?.year.toString() ?? '');
    _startDate = existing?.startDate;
    _endDate = existing?.endDate;
    _term = existing?.term ?? 'TERM_1';
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, clear it
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      setState(() => _error = 'Please select a start date.');
      return;
    }
    if (_endDate == null) {
      setState(() => _error = 'Please select an end date.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'End date must be after start date.');
      return;
    }

    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null) {
      setState(() => _error = 'Enter a valid year.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = {
        'academicyear': year,
        'termname': _term,
        'startdate': _startDate!.toIso8601String().substring(0, 10),
        'enddate': _endDate!.toIso8601String().substring(0, 10),
      };

      if (_isEdit) {
        await _repo.updateAcademicYear(widget.existing!.id, data);
      } else {
        await _repo.createAcademicYear(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.roleName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Academic Year' : 'Create Academic Year'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Academic Year (e.g., 2024)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Year is required.';
                  final year = int.tryParse(v.trim());
                  if (year == null || year < 2020 || year > 2050) {
                    return 'Enter a valid year between 2020-2050.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Term Selection
              DropdownButtonFormField<String>(
                initialValue: _term,
                decoration: const InputDecoration(labelText: 'Term'),
                items: const [
                  DropdownMenuItem(value: 'TERM_1', child: Text('Term 1')),
                  DropdownMenuItem(value: 'TERM_2', child: Text('Term 2')),
                  DropdownMenuItem(value: 'TERM_3', child: Text('Term 3')),
                ],
                onChanged: (v) => setState(() => _term = v!),
              ),
              const SizedBox(height: 16),

              // Start Date
              GestureDetector(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _startDate?.toIso8601String().substring(0, 10) ??
                        'Select start date',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Date
              GestureDetector(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'End Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _endDate?.toIso8601String().substring(0, 10) ??
                        'Select end date',
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEdit
                              ? 'Update Academic Year'
                              : 'Create Academic Year',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
