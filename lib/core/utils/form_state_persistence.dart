import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistence of form state to local storage
class FormStatePersistence {
  static const String _prefix = 'form_state_';

  /// Save form data to local storage
  ///
  /// Example:
  /// ```dart
  /// await FormStatePersistence.saveFormState('user_form', {
  ///   'firstName': 'John',
  ///   'lastName': 'Doe',
  ///   'email': 'john@example.com',
  /// });
  /// ```
  static Future<bool> saveFormState(
    String formId,
    Map<String, dynamic> formData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$formId';
      final json = jsonEncode(formData);
      return await prefs.setString(key, json);
    } catch (e) {
      developer.log('Error saving form state for $formId', error: e);
      return false;
    }
  }

  /// Load form data from local storage
  ///
  /// Returns null if no saved state exists
  static Future<Map<String, dynamic>?> loadFormState(String formId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$formId';
      final json = prefs.getString(key);

      if (json == null) return null;

      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Error loading form state for $formId', error: e);
      return null;
    }
  }

  /// Clear saved form state
  static Future<bool> clearFormState(String formId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$formId';
      return await prefs.remove(key);
    } catch (e) {
      developer.log('Error clearing form state for $formId', error: e);
      return false;
    }
  }

  /// Clear all saved form states
  static Future<bool> clearAllFormStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
      return true;
    } catch (e) {
      developer.log('Error clearing all form states', error: e);
      return false;
    }
  }

  /// Get last saved timestamp for form state
  static Future<DateTime?> getLastSavedTime(String formId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix${formId}_timestamp';
      final timestamp = prefs.getInt(key);

      if (timestamp == null) return null;

      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      developer.log('Error getting last saved time for $formId', error: e);
      return null;
    }
  }

  /// Save form state with timestamp
  static Future<bool> saveFormStateWithTimestamp(
    String formId,
    Map<String, dynamic> formData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$formId';
      final timestampKey = '$_prefix${formId}_timestamp';

      final json = jsonEncode(formData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(key, json);
      await prefs.setInt(timestampKey, timestamp);

      return true;
    } catch (e) {
      developer.log(
        'Error saving form state with timestamp for $formId',
        error: e,
      );
      return false;
    }
  }
}

/// Mixin for form widgets to automatically persist state
mixin FormStatePersistenceMixin {
  String get formId;
  Map<String, dynamic> getFormData();
  Future<void> restoreFormData(Map<String, dynamic> data);

  /// Initialize form persistence
  Future<void> initFormPersistence() async {
    final savedData = await FormStatePersistence.loadFormState(formId);
    if (savedData != null) {
      await restoreFormData(savedData);
    }
  }

  /// Auto-save form state periodically
  /// Call this from initState or during form changes
  void autoSaveFormState() {
    FormStatePersistence.saveFormStateWithTimestamp(formId, getFormData());
  }

  /// Clear saved state (call on successful submit)
  Future<void> clearSavedFormState() async {
    await FormStatePersistence.clearFormState(formId);
  }
}

/// Widget wrapper for form state persistence with auto-save
class FormStatePreserver extends StatefulWidget {
  final String formId;
  final Duration autoSaveDuration;
  final Widget Function(BuildContext, FormStateController) builder;
  final VoidCallback? onStateRestored;
  final VoidCallback? onStateSaved;

  const FormStatePreserver({
    required this.formId,
    required this.builder,
    this.autoSaveDuration = const Duration(seconds: 5),
    this.onStateRestored,
    this.onStateSaved,
    super.key,
  });

  @override
  State<FormStatePreserver> createState() => _FormStatePreserverState();
}

class _FormStatePreserverState extends State<FormStatePreserver> {
  late final FormStateController _controller;
  late final Future<Map<String, dynamic>?> _restoredData;

  @override
  void initState() {
    super.initState();
    _controller = FormStateController(
      formId: widget.formId,
      onSaved: widget.onStateSaved,
    );
    _restoredData = FormStatePersistence.loadFormState(widget.formId).then((
      data,
    ) {
      if (data != null) {
        widget.onStateRestored?.call();
      }
      return data;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _restoredData,
      builder: (context, snapshot) {
        return widget.builder(context, _controller);
      },
    );
  }
}

/// Controller for managing form state persistence
class FormStateController {
  final String formId;
  final VoidCallback? onSaved;

  FormStateController({required this.formId, this.onSaved});

  void dispose() {
    // Cleanup if needed
  }

  /// Save current form state
  Future<bool> saveState(Map<String, dynamic> formData) async {
    final success = await FormStatePersistence.saveFormStateWithTimestamp(
      formId,
      formData,
    );
    if (success) {
      onSaved?.call();
    }
    return success;
  }

  /// Load saved state
  Future<Map<String, dynamic>?> loadState() async {
    return FormStatePersistence.loadFormState(formId);
  }

  /// Clear saved state
  Future<bool> clearState() async {
    return FormStatePersistence.clearFormState(formId);
  }

  /// Get timestamp of last save
  Future<DateTime?> getLastSaveTime() async {
    return FormStatePersistence.getLastSavedTime(formId);
  }
}

/// Auto-save debouncer to prevent excessive writes
class AutoSaveDebouncer {
  final Duration duration;
  Timer? _timer;
  final Future<void> Function() onSave;

  AutoSaveDebouncer({
    required this.onSave,
    this.duration = const Duration(seconds: 3),
  });

  /// Trigger auto-save with debounce
  void save() {
    _timer?.cancel();
    _timer = Timer(duration, () async {
      await onSave();
    });
  }

  /// Cancel pending auto-save
  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Show indicator that form is being auto-saved
class AutoSaveIndicator extends StatelessWidget {
  final bool isSaving;
  final DateTime? lastSavedTime;

  const AutoSaveIndicator({
    this.isSaving = false,
    this.lastSavedTime,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('Saving...', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
    }

    if (lastSavedTime != null) {
      final now = DateTime.now();
      final diff = now.difference(lastSavedTime!);

      String timeStr;
      if (diff.inSeconds < 60) {
        timeStr = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeStr = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeStr = '${diff.inHours}h ago';
      } else {
        timeStr = '${diff.inDays}d ago';
      }

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'Saved $timeStr',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.green.shade600),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
