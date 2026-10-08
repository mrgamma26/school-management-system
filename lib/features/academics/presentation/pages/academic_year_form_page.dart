import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/academic_year.dart';

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
  String? _form;
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
    _form = existing?.form;
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
      lastDate: DateTime(2051, 12, 31),
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

    final overlaps = await _repo.hasOverlappingPeriod(
      year: year,
      form: _form!,
      startDate: _startDate!,
      endDate: _endDate!,
      excludingId: widget.existing?.id,
    );
    if (overlaps) {
      setState(
        () => _error =
            'This term overlaps another period in the same academic year.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = {
        'academicyear': year,
        'term': _term,
        'termname': _term,
        'form': _form,
        'startdate': _startDate!.toIso8601String().substring(0, 10),
        'enddate': _endDate!.toIso8601String().substring(0, 10),
      };

      if (_isEdit) {
        await _repo.updateAcademicYear(widget.existing!.id, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Academic year updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _repo.createAcademicYear(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Academic year created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academic Year'),
        content: const Text(
          'Are you sure you want to delete this academic year? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.deleteAcademicYear(widget.existing!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Academic year deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Academic Year' : 'Create Academic Year'),
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
                  labelText: 'Starting year',
                  helperText:
                      'For example, 2026 creates academic year 2026/2027.',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setState(() {});
                },
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

              DropdownButtonFormField<String>(
                initialValue: _form,
                decoration: const InputDecoration(labelText: 'Form *'),
                items: const [
                  DropdownMenuItem(value: 'FORM_1', child: Text('Form 1')),
                  DropdownMenuItem(value: 'FORM_2', child: Text('Form 2')),
                  DropdownMenuItem(value: 'FORM_3', child: Text('Form 3')),
                  DropdownMenuItem(value: 'FORM_4', child: Text('Form 4')),
                ],
                validator: (value) => value == null
                    ? 'Select the form this period applies to.'
                    : null,
                onChanged: (value) => setState(() => _form = value),
              ),
              const SizedBox(height: 16),

              if (int.tryParse(_yearCtrl.text) case final int year)
                ListTile(
                  title: const Text('Academic year'),
                  subtitle: Text(formatAcademicYear(year)),
                ),
              DropdownButtonFormField<String>(
                initialValue: _term,
                decoration: const InputDecoration(labelText: 'Term *'),
                items: const [
                  DropdownMenuItem(value: 'TERM_1', child: Text('Term 1')),
                  DropdownMenuItem(value: 'TERM_2', child: Text('Term 2')),
                  DropdownMenuItem(value: 'TERM_3', child: Text('Term 3')),
                ],
                onChanged: (value) => setState(() => _term = value!),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
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
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Academic Year'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
