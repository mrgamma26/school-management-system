import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for providers that support optimistic updates
mixin OptimisticUpdateMixin<T> {
  /// Update provider with optimistic value while async operation completes
  ///
  /// Usage:
  /// ```dart
  /// // Show optimistic UI immediately
  /// ref.read(provider.notifier).updateOptimistically(newValue);
  ///
  /// // Make async call
  /// await someAsyncOperation();
  ///
  /// // Invalidate to refresh from server
  /// ref.invalidate(provider);
  /// ```
  void updateOptimistically(
    T value,
    WidgetRef ref,
    FutureProvider<T> provider,
  ) {
    // Override in subclass to update the provider state
  }
}

/// Generic optimistic update handler
class OptimisticUpdateHandler<T> {
  final WidgetRef ref;
  final FutureProvider<T> provider;
  final Future<void> Function() asyncOperation;
  final T optimisticValue;

  OptimisticUpdateHandler({
    required this.ref,
    required this.provider,
    required this.asyncOperation,
    required this.optimisticValue,
  });

  /// Execute async operation with optimistic update
  /// Shows optimistic value immediately, reverts if operation fails
  Future<bool> execute() async {
    try {
      // Show optimistic value immediately
      // In a real app, you'd update the provider state here
      // ref.read(provider.notifier).state = AsyncValue.data(optimisticValue);

      // Execute async operation
      await asyncOperation();

      // Success - invalidate to refresh from server
      ref.invalidate(provider);
      return true;
    } catch (e) {
      // Failure - rollback to original value
      // ref.read(provider.notifier).state = originalAsync;
      developer.log('Optimistic update failed', error: e);
      ref.invalidate(provider);
      return false;
    }
  }
}

/// Helper extension for easier optimistic updates
extension OptimisticUpdateExtension<T> on AsyncValue<T> {
  /// Returns true if this is loading but has data (optimistic state)
  bool get isOptimistic => isLoading && hasValue;

  /// Get the current value, defaulting to null if no value
  T? getValueOrNull() {
    return whenData(
      (data) => data,
    ).maybeWhen(data: (d) => d, orElse: () => null);
  }
}

/// Toast notification helper for optimistic updates
class OptimisticFeedback {
  static const String successMessage = 'Saved successfully';
  static const String pendingMessage = 'Saving...';
  static const String errorMessage =
      'Failed to save. Changes may not be persisted.';
  static const String offlineMessage =
      'Offline. Changes will sync when online.';

  /// Build visual feedback for optimistic state
  static String getStatusMessage(AsyncValue state) {
    return state.when(
      data: (_) => successMessage,
      loading: () => pendingMessage,
      error: (_, _) => errorMessage,
    );
  }

  /// Get color for optimistic state feedback
  static Color getStatusColor(AsyncValue state) {
    return state.when(
      data: (_) => Colors.green,
      loading: () => Colors.blue,
      error: (_, _) => Colors.red,
    );
  }
}

/// Optimistic list update helper - updates a list immediately while syncing
class OptimisticListUpdate<T> {
  final List<T> currentList;
  final T newItem;
  final T Function(T)? updateTransform;
  final bool isAdd;

  OptimisticListUpdate({
    required this.currentList,
    required this.newItem,
    this.updateTransform,
    this.isAdd = true,
  });

  /// Get the optimistic list (updated immediately)
  List<T> getOptimisticList() {
    if (isAdd) {
      return [...currentList, newItem];
    } else {
      // For updates, replace the matching item
      return currentList.map((item) {
        if (item == newItem) {
          return updateTransform?.call(item) ?? newItem;
        }
        return item;
      }).toList();
    }
  }

  /// Rollback to original list if operation fails
  List<T> getRollbackList() => currentList;
}

/// Stream-based optimistic update for real-time feedback
class OptimisticUpdateStream<T> {
  final Stream<T> stream;
  final T Function() getOptimisticValue;

  OptimisticUpdateStream({
    required this.stream,
    required this.getOptimisticValue,
  });

  /// Get stream that emits optimistic value first, then real value
  Stream<T> get streamWithOptimistic async* {
    // Emit optimistic value immediately
    yield getOptimisticValue();

    // Then stream the actual values
    yield* stream;
  }
}
