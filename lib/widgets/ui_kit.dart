// lib/widgets/ui_kit.dart
// Shared building blocks for the redesigned screens (see docs/UI_REDESIGN_HANDOFF.md).
// Every page uses these instead of hand-rolled cards so the 66 screens stay consistent.

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

// ── Layout helpers ──────────────────────────────────────────────────────────

/// Scrollable page body: centred, max width, 24px padding (16px on phones).
class UiPage extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const UiPage({super.key, required this.children, this.maxWidth = 1240});

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    // Transparent Material so inputs and ink work even without a Scaffold.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(phone ? 16 : 24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Page chrome for screens whose body manages its own scrolling (lists,
/// calendars, tab views): the redesigned [PageHead] on top, [body] fills the rest.
class PageFrame extends StatelessWidget {
  final String? kicker;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final double maxWidth;

  const PageFrame({
    super.key,
    this.kicker,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.body,
    this.maxWidth = 1240,
  });

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    final pad = phone ? 16.0 : 24.0;
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHead(
                  kicker: kicker,
                  title: title,
                  subtitle: subtitle,
                  actions: actions,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width grid that collapses with the available width.
/// [columns] on wide layouts, [mediumColumns] on tablets, [phoneColumns] below 560px.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final int mediumColumns;
  final int phoneColumns;
  final double gap;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.columns = 4,
    this.mediumColumns = 2,
    this.phoneColumns = 1,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 900
            ? columns
            : width >= 560
            ? mediumColumns.clamp(1, columns)
            : phoneColumns;
        final itemWidth = (width - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Two-column layout (main + side) that stacks below [breakpoint].
/// Defaults match the mockup form layout: 1.55fr / .8fr.
class SplitLayout extends StatelessWidget {
  final Widget main;
  final Widget side;
  final int mainFlex;
  final int sideFlex;
  final double breakpoint;
  final double gap;

  const SplitLayout({
    super.key,
    required this.main,
    required this.side,
    this.mainFlex = 155,
    this.sideFlex = 80,
    this.breakpoint = 900,
    this.gap = 14,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, SizedBox(height: gap), side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: mainFlex, child: main),
            SizedBox(width: gap),
            Expanded(flex: sideFlex, child: side),
          ],
        );
      },
    );
  }
}

// ── Page head & buttons ─────────────────────────────────────────────────────

/// Kicker + title + subtitle on the left, action buttons on the right.
class PageHead extends StatelessWidget {
  final String? kicker;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHead({
    super.key,
    this.kicker,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker != null)
          Text(
            kicker!.toUpperCase(),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppColors.primary,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: phone ? 21 : 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            height: 1.15,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
    final actionRow = actions.isEmpty
        ? null
        : Wrap(spacing: 8, runSpacing: 8, children: actions);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: phone || actionRow == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                if (actionRow != null) ...[const SizedBox(height: 12), actionRow],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 16),
                actionRow,
              ],
            ),
    );
  }
}

enum UiButtonKind { primary, secondary, danger }

/// 40px action button. Primary = blue-700, secondary = blue-100.
class UiButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final UiButtonKind kind;
  final bool expand;

  const UiButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.kind = UiButtonKind.primary,
    this.expand = false,
  });

  const UiButton.secondary(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.expand = false,
  }) : kind = UiButtonKind.secondary;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (kind) {
      UiButtonKind.primary => (AppColors.primary, Colors.white),
      UiButtonKind.secondary => (AppColors.primarySurface, AppColors.primaryDark),
      UiButtonKind.danger => (AppColors.dangerSurface, AppColors.danger),
    };
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: AppColors.surfaceVariant,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

/// Bordered white card, radius 14. Optionally tappable with an ink ripple.
class UiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Titled card: bold title on the left, small muted [trailing] on the right.
class Panel extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Small muted caption used in panel headers ("View all", "Current year").
class PanelNote extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const PanelNote(this.text, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: onTap == null ? FontWeight.w600 : FontWeight.w800,
        color: onTap == null ? AppColors.textSecondary : AppColors.primary,
      ),
    );
    return onTap == null ? label : InkWell(onTap: onTap, child: label);
  }
}

/// Icon chip + label + big value + note. [value] may be null while loading.
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? note;
  final StatusTone noteTone;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.note,
    this.noteTone = StatusTone.success,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return UiCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.blue800),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value ?? '…',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: noteTone.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status pills ────────────────────────────────────────────────────────────

/// Semantic tones. Green / amber / red are reserved for state, never decoration.
enum StatusTone {
  success(AppColors.success, AppColors.successSurface),
  warning(AppColors.warning, AppColors.warningSurface),
  danger(AppColors.danger, AppColors.dangerSurface),
  info(AppColors.primaryDark, AppColors.primarySurface),
  neutral(AppColors.textSecondary, AppColors.surfaceVariant);

  final Color foreground;
  final Color background;
  const StatusTone(this.foreground, this.background);

  /// Guess a tone from a status word ("Active", "Failed", "Pending", ...).
  static StatusTone fromLabel(String label) {
    final s = label.toLowerCase();
    if (RegExp(
      r'active|current|sent|approved|paid|published|verified|enrolled|posted|complete|promot|valid|available|open',
    ).hasMatch(s)) {
      return StatusTone.success;
    }
    if (RegExp(
      r'fail|reject|inactive|suspend|revers|overdue|unpaid|withdrawn|weed|blocked|error|closed|archived',
    ).hasMatch(s)) {
      return StatusTone.danger;
    }
    if (RegExp(r'draft|info|queued|new').hasMatch(s)) return StatusTone.info;
    return StatusTone.warning;
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const StatusPill(this.label, {super.key, this.tone = StatusTone.info});

  /// Picks the tone from the label text.
  StatusPill.auto(this.label, {super.key}) : tone = StatusTone.fromLabel(label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tone.foreground,
        ),
      ),
    );
  }
}

// ── People ──────────────────────────────────────────────────────────────────

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "17 Oct 2026", the date style used across the redesigned screens.
String formatUiDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

/// "MWK 150,000.00" - grouped thousands, fixed decimals, negatives kept.
String formatMwk(num value, {int decimals = 2}) {
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  return '${value < 0 ? '-' : ''}MWK $body';
}

String initialsOf(String name, {int max = 2}) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(max).map((p) => p[0]).join().toUpperCase();
}

/// Rounded-square initials chip used in table rows.
class MiniAvatar extends StatelessWidget {
  final String name;
  final double size;
  const MiniAvatar(this.name, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// Avatar + name + muted second line (first column of most tables).
class PersonCell extends StatelessWidget {
  final String name;
  final String? subtitle;
  const PersonCell(this.name, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MiniAvatar(name),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Navy hero block at the top of profile / detail screens.
class ProfileHero extends StatelessWidget {
  final String name;
  final String? subtitle;
  final Widget? pill;
  final List<Widget> actions;

  const ProfileHero({
    super.key,
    required this.name,
    this.subtitle,
    this.pill,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 4,
              ),
            ),
            child: Text(
              initialsOf(name),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB9D7F8),
                      ),
                    ),
                  ),
                if (pill != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: pill,
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
        ],
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────────────────────

/// Underlined tab strip. Controlled: keep [index] in the parent State.
class TabsBar extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  const TabsBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                  margin: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: i == index
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: i == index
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Lists, queues, detail rows ──────────────────────────────────────────────

/// Pale-blue row used for queues / to-dos: icon chip, title, subtitle, pill.
class QueueItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? pill;
  final VoidCallback? onTap;

  const QueueItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.pill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (pill != null) ...[const SizedBox(width: 8), pill!],
                if (onTap != null && pill == null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical stack of [QueueItem]s with 9px gaps.
class QueueList extends StatelessWidget {
  final List<Widget> items;
  const QueueList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          items[i],
        ],
      ],
    );
  }
}

/// Checklist row. Shows a tick (checked), a number, or an empty box.
class CheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final String? number;
  final Widget? trailing;
  final ValueChanged<bool>? onChanged;

  const CheckRow({
    super.key,
    required this.label,
    this.checked = false,
    this.number,
    this.trailing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked || number != null
            ? AppColors.primary
            : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked || number != null
              ? AppColors.primary
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : number != null
          ? Text(
              number!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            )
          : null,
    );
    return Semantics(
      checked: checked,
      label: label,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!checked),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                box,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label on the left (muted), value on the right (bold), hairline underneath.
class DetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const DetailLine(
    this.label,
    this.value, {
    super.key,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

// ── Forms ───────────────────────────────────────────────────────────────────

/// Card that holds a form section ("Required information").
class FormPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const FormPanel({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Uppercase 10px field label that sits above an input.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: Color(0xFF31445E),
        ),
      ),
    );
  }
}

/// A label with any input widget under it.
class UiField extends StatelessWidget {
  final String label;
  final Widget child;
  const UiField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [FieldLabel(label), child],
    );
  }
}

/// Two-column grid of fields; one column on phones. Wrap a field in [FullWidth]
/// to make it span both columns.
class FieldGrid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const FieldGrid({super.key, required this.children, this.gap = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final two = constraints.maxWidth >= 480;
        final half = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: !two || child is FullWidth
                    ? constraints.maxWidth
                    : half,
                child: child is FullWidth ? child.child : child,
              ),
          ],
        );
      },
    );
  }
}

/// Marker for a [FieldGrid] child that spans the full row.
class FullWidth extends StatelessWidget {
  final Widget child;
  const FullWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Blue-100 note with a 3px blue-700 left border.
class InlineGuide extends StatelessWidget {
  final String? title;
  final String text;
  const InlineGuide({super.key, this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (title != null)
              TextSpan(
                text: '$title ',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            TextSpan(text: text),
          ],
        ),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3C5572),
          height: 1.45,
        ),
      ),
    );
  }
}

/// Inline banner for form errors / notices. Tone picks the colours.
class UiNotice extends StatelessWidget {
  final String text;
  final StatusTone tone;
  final IconData? icon;

  const UiNotice(
    this.text, {
    super.key,
    this.tone = StatusTone.danger,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: tone.foreground),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: tone.foreground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The standard add / edit screen: page head with Cancel + Save, a form panel on
/// the left and a summary panel on the right (stacked on phones).
class FormPageLayout extends StatelessWidget {
  final String? kicker;
  final String title;
  final String? subtitle;
  final String formTitle;
  final Widget form;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final String saveLabel;
  final bool saving;
  final String? error;
  final String? guideTitle;
  final String? guide;
  final String sideTitle;
  final List<Widget> side;

  const FormPageLayout({
    super.key,
    this.kicker,
    required this.title,
    this.subtitle,
    required this.formTitle,
    required this.form,
    required this.onSave,
    this.onCancel,
    this.saveLabel = 'Save changes',
    this.saving = false,
    this.error,
    this.guideTitle,
    this.guide,
    this.sideTitle = 'Record summary',
    this.side = const [],
  });

  @override
  Widget build(BuildContext context) {
    final formColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        form,
        if (error != null) UiNotice(error!, icon: Icons.error_outline),
        if (guide != null) InlineGuide(title: guideTitle, text: guide!),
      ],
    );
    return UiPage(
      children: [
        PageHead(
          kicker: kicker,
          title: title,
          subtitle: subtitle,
          actions: [
            UiButton.secondary(
              'Cancel',
              onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
            ),
            UiButton(
              saving ? 'Saving…' : saveLabel,
              onPressed: saving ? null : onSave,
            ),
          ],
        ),
        if (side.isEmpty)
          FormPanel(title: formTitle, child: formColumn)
        else
          SplitLayout(
            main: FormPanel(title: formTitle, child: formColumn),
            side: FormPanel(
              title: sideTitle,
              child: QueueList(items: side),
            ),
          ),
      ],
    );
  }
}

// ── Toolbar ─────────────────────────────────────────────────────────────────

/// White bar above tables: a search box that grows, plus filter chips.
class UiToolbar extends StatelessWidget {
  final String searchHint;
  final ValueChanged<String>? onSearch;
  final TextEditingController? controller;
  final List<Widget> trailing;

  const UiToolbar({
    super.key,
    this.searchHint = 'Search',
    this.onSearch,
    this.controller,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: controller,
                onChanged: onSearch,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: searchHint,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// Bordered filter chip. Pass [onTap] to make it clickable.
class FilterChipBox extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const FilterChipBox(this.label, {super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primaryDark : const Color(0xFF53657B),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Table ───────────────────────────────────────────────────────────────────

class UiColumn {
  final String label;
  final int flex;
  final double? width;
  final bool hideOnPhone;
  const UiColumn(
    this.label, {
    this.flex = 10,
    this.width,
    this.hideOnPhone = false,
  });
}

class UiTableRow {
  final List<Widget> cells;
  final VoidCallback? onTap;
  const UiTableRow(this.cells, {this.onTap});
}

/// Card containing a header row and data rows. Text cells should use [UiCellText].
class DataTableCard extends StatelessWidget {
  final List<UiColumn> columns;
  final List<UiTableRow> rows;
  final Widget? empty;

  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.mobile;
    final visible = [
      for (var i = 0; i < columns.length; i++)
        if (!(phone && columns[i].hideOnPhone)) i,
    ];

    Widget rowOf(List<Widget> cells) => Row(
      children: [
        for (final i in visible) ...[
          if (i != visible.first) const SizedBox(width: 10),
          columns[i].width != null
              ? SizedBox(width: columns[i].width, child: cells[i])
              : Expanded(flex: columns[i].flex, child: cells[i]),
        ],
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.background,
            alignment: Alignment.centerLeft,
            child: rowOf([
              for (final c in columns)
                Text(
                  c.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    color: AppColors.textSecondary,
                  ),
                ),
            ]),
          ),
          if (rows.isEmpty)
            empty ??
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Nothing to show yet.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
          for (final row in rows)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: InkWell(
                onTap: row.onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  alignment: Alignment.centerLeft,
                  child: rowOf(row.cells),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Plain text cell for [DataTableCard].
class UiCellText extends StatelessWidget {
  final String text;
  final bool bold;
  const UiCellText(this.text, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// "Showing 1-25 of 140" with previous / next, for client-side paging of tables.
class PagerBar extends StatelessWidget {
  final int total;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPage;

  const PagerBar({
    super.key,
    required this.total,
    required this.page,
    required this.onPage,
    this.pageSize = 25,
  });

  /// Rows of [items] that belong on [page] (0-based).
  static List<T> slice<T>(List<T> items, int page, int pageSize) {
    final start = (page * pageSize).clamp(0, items.length);
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    if (total <= pageSize) return const SizedBox.shrink();
    final pages = (total / pageSize).ceil();
    final from = page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $from–$to of $total',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${page + 1} / $pages',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

/// Withheld-content state: red lock, message, amber balance pill and actions.
/// Used when a guardian's results are blocked by an outstanding balance.
class LockedState extends StatelessWidget {
  final String title;
  final String message;
  final String? balanceLabel;
  final List<Widget> actions;

  const LockedState({
    super.key,
    required this.title,
    required this.message,
    this.balanceLabel,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  color: AppColors.dangerSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (balanceLabel != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    balanceLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centred icon + title + hint, used inside panels and tables.
class UiEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const UiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
