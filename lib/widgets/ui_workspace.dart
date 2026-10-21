// lib/widgets/ui_workspace.dart
// Building blocks for the consolidated task workspaces (student admission,
// staff onboarding, class setup): numbered stage bar, selectable pick rows,
// the live "what this submission creates" side panel and a rules box.
// Built on top of ui_kit.dart; no business logic lives here.

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'ui_kit.dart';

/// One stage of a workspace: a short title and a muted second line.
class WorkspaceStep {
  final String title;
  final String subtitle;
  const WorkspaceStep(this.title, this.subtitle);
}

/// Numbered stage bar. Stages up to [maxReached] can be tapped to jump back
/// or forward; later stages stay disabled until the user gets there.
class WorkspaceStepper extends StatelessWidget {
  final List<WorkspaceStep> steps;
  final int current;
  final int maxReached;

  /// Stages that show a tick. Defaults to every reached stage but [current].
  final Set<int>? completed;

  /// When true every stage can be selected (single-page workspaces where all
  /// stages are on screen and the stepper just scrolls to them).
  final bool freeNavigation;
  final ValueChanged<int>? onSelect;

  const WorkspaceStepper({
    super.key,
    required this.steps,
    required this.current,
    int? maxReached,
    this.completed,
    this.freeNavigation = false,
    this.onSelect,
  }) : maxReached = maxReached ?? current;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: _StepTile(
                    index: i,
                    step: steps[i],
                    current: i == current,
                    done:
                        completed?.contains(i) ??
                        (i < current || (i != current && i < maxReached)),
                    enabled:
                        (freeNavigation || i <= maxReached) && onSelect != null,
                    compact: compact,
                    onTap: () => onSelect?.call(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final WorkspaceStep step;
  final bool current;
  final bool done;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  const _StepTile({
    required this.index,
    required this.step,
    required this.current,
    required this.done,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current || done;
    final circle = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
    );
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: current ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
        Text(
          step.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      selected: current,
      enabled: enabled,
      label: 'Stage ${index + 1}: ${step.title}. ${step.subtitle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: current ? AppColors.primarySurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              circle,
              if (!compact || current) ...[
                const SizedBox(width: 9),
                Expanded(child: label),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable row used to choose one thing from a list (a guardian, a class,
/// a role): avatar, title, muted subtitle, optional pills and a tick.
class WorkspacePickRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatar;
  final bool selected;
  final bool enabled;
  final List<Widget> pills;
  final VoidCallback? onTap;

  const WorkspacePickRow({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.selected = false,
    this.enabled = true,
    this.pills = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: subtitle == null ? title : '$title. $subtitle',
      child: Material(
        color: selected ? AppColors.primarySurface : AppColors.background,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (avatar != null) ...[
                  MiniAvatar(avatar!),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: pills),
                ],
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: selected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.primary,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of the live side summary: a filled tick once it is ready.
class WorkspaceBuildItem {
  final String label;
  final bool ready;
  const WorkspaceBuildItem(this.label, this.ready);
}

/// Side panel that lists what the final submission will create and ticks each
/// line as the form fills in. [rules] renders the short "Rules in force" box.
class WorkspaceSummary extends StatelessWidget {
  final String title;
  final List<WorkspaceBuildItem> items;
  final List<Widget> details;
  final List<String> rules;

  const WorkspaceSummary({
    super.key,
    required this.title,
    required this.items,
    this.details = const [],
    this.rules = const [],
  });

  @override
  Widget build(BuildContext context) {
    return FormPanel(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.ready
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: item.ready
                        ? AppColors.success
                        : AppColors.textDisabled,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: item.ready
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...details,
          if (rules.isNotEmpty) WorkspaceRules(rules),
        ],
      ),
    );
  }
}

/// "Rules in force" box: short statements of what the system enforces.
class WorkspaceRules extends StatelessWidget {
  final List<String> rules;
  final String title;
  const WorkspaceRules(this.rules, {super.key, this.title = 'Rules in force'});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5, right: 7),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C5572),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Back on the left, the stage's primary action on the right.
class WorkspaceFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget primary;
  const WorkspaceFooter({super.key, this.onBack, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            UiButton.secondary(
              'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            )
          else
            const SizedBox.shrink(),
          Flexible(child: primary),
        ],
      ),
    );
  }
}

/// Wrapping toggle chips (subjects offered by a class).
class WorkspaceChoiceChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;
  const WorkspaceChoiceChip({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: Material(
        color: on ? AppColors.primarySurface : AppColors.background,
        shape: StadiumBorder(
          side: BorderSide(
            color: on ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  on ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: on ? AppColors.primaryDark : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: on ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
