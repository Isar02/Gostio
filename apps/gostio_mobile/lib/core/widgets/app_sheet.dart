import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A sheet rather than a dialog wherever the reader is choosing rather than
// answering: it opens under the thumb, and it may be as tall as its content
// needs without becoming a screen with a shadow on it.
abstract final class AppSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required WidgetBuilder builder,
    Widget? footer,
    bool isDismissible = true,
    bool isScrollable = true,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.ink.withValues(alpha: 0.32),
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
    builder: (BuildContext context) => _Sheet(
      title: title,
      footer: footer,
      isDismissible: isDismissible,
      isScrollable: isScrollable,
      child: builder(context),
    ),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.child,
    required this.isDismissible,
    required this.isScrollable,
    this.footer,
  });

  final String title;
  final Widget child;
  final bool isDismissible;
  final bool isScrollable;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);

    return ConstrainedBox(
      // Leaving the top of the screen uncovered is what says this is a sheet
      // and that what opened it is still behind.
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const _Handle(),
          _Title(title: title, canClose: isDismissible),
          const Divider(),
          // A child that scrolls something of its own, or pins a bar under
          // it, is given the room and left to lay itself out.
          Flexible(
            child: isScrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: child,
                  )
                : child,
          ),
          if (footer case final Widget footer) footer,
          // The keyboard, when a field inside the sheet has taken it.
          SizedBox(height: media.viewInsets.bottom),
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.sheetHandle,
      height: AppSizes.stroke * 2,
      margin: const EdgeInsets.only(top: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.borderStrong,
        borderRadius: AppRadii.pill,
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.canClose});

  final String title;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (canClose)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}
