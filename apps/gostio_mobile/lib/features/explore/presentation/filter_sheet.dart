import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';

// The frame both filter sheets are drawn in. What is being chosen scrolls and
// the two gestures that close the sheet stay under the thumb, because a reader
// who has scrolled to the last group should not have to scroll back to apply.
class FilterSheetLayout extends StatelessWidget {
  const FilterSheetLayout({
    required this.children,
    required this.onApply,
    this.onClear,
    this.notice,
    super.key,
  });

  final List<Widget> children;
  final VoidCallback onApply;

  // Absent while nothing is set, so the sheet does not offer to undo nothing.
  final VoidCallback? onClear;

  final String? notice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (notice case final String notice) ...<Widget>[
                  AppNotice(notice, tone: Tone.attention),
                  const SizedBox(height: AppSpacing.xl),
                ],
                ...children,
              ],
            ),
          ),
        ),
        BottomActionBar(
          secondary: TextButton(onPressed: onClear, child: const Text('Clear')),
          action: FilledButton(
            onPressed: onApply,
            child: const Text('Show results'),
          ),
        ),
      ],
    );
  }
}

// One filter and what it is called. The name sits above the control rather
// than beside it: a chip row is as wide as the sheet, and a label sharing that
// line would take the room the choices need.
class FilterGroup extends StatelessWidget {
  const FilterGroup({
    required this.label,
    required this.child,
    this.detail,
    super.key,
  });

  final String label;
  final String? detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: text.titleSmall),
          if (detail case final String detail) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// A filter chosen somewhere else — a calendar drawn over the sheet — said as
// the value it holds rather than as the control that sets it. Taking it off is
// a control of its own, because the calendar has no gesture for "no dates".
class FilterOpener extends StatelessWidget {
  const FilterOpener({
    required this.placeholder,
    required this.onOpen,
    this.value,
    this.onClear,
    super.key,
  });

  final String placeholder;
  final String? value;
  final VoidCallback onOpen;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final String? value = this.value;

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: AppSizes.iconSmall,
            ),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value ?? placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: value == null
                    ? Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.inkMuted)
                    : null,
              ),
            ),
          ),
        ),
        if (value != null && onClear != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
            tooltip: 'Clear $placeholder',
          ),
        ],
      ],
    );
  }
}
