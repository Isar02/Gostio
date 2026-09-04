import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/writing_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import 'rating_stars.dart';

class ReviewDialog extends StatefulWidget {
  const ReviewDialog({required this.review, required this.takeDown, super.key});

  final Review review;
  final Future<WriteOutcome> Function() takeDown;

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  bool _isWriting = false;
  ApiException? _failure;

  @override
  Widget build(BuildContext context) {
    final Review review = widget.review;
    final TextTheme text = Theme.of(context).textTheme;

    // A refusal is said here, so a write in flight holds the dialog open.
    return PopScope<Object?>(
      canPop: !_isWriting,
      child: AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text(review.listingTitle, style: text.titleLarge)),
            if (review.listingKind case final ListingKind kind) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              StatusChip(_kindLabel(kind), tone: Tone.informative),
            ],
          ],
        ),
        content: SizedBox(
          width: AppSizes.readingColumn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_failure case final ApiException failure) ...<Widget>[
                AppNotice(failure.message),
                const SizedBox(height: AppSpacing.lg),
              ],
              Row(
                children: <Widget>[
                  RatingStars(review.rating, size: AppSizes.icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(_written, style: text.bodySmall)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Comment(comment: review.comment),
            ],
          ),
        ),
        // The row of actions is an OverflowBar, which takes no Spacer.
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          Tooltip(
            message: 'Take this review off the listing.',
            child: TextButton(
              onPressed: _isWriting ? null : _confirmTakeDown,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(_isWriting ? 'Taking down' : 'Take down'),
            ),
          ),
          TextButton(
            onPressed: _isWriting ? null : () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String get _written {
    final Review review = widget.review;
    final String wrote =
        '${review.guestName} · ${AppDates.date(review.createdAt)}';

    return switch (review.modifiedAt) {
      final DateTime edited => '$wrote · edited ${AppDates.date(edited)}',
      null => wrote,
    };
  }

  Future<void> _confirmTakeDown() async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Take this review down?',
      message:
          'It goes from the listing, whose rating and review count are '
          'figured again without it. The guest may write another one for the '
          'same booking. This cannot be undone.',
      confirmLabel: 'Take down',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    setState(() {
      _failure = null;
      _isWriting = true;
    });

    final WriteOutcome outcome = await widget.takeDown();

    if (!mounted) {
      return;
    }

    if (outcome.wasWritten) {
      const String said = 'The review was taken down.';

      Navigator.of(context).pop(
        outcome.viewSettled ? said : '$said The list could not be read again.',
      );

      return;
    }

    setState(() {
      _failure = outcome.refusal;
      _isWriting = false;
    });
  }

  static String _kindLabel(ListingKind kind) => switch (kind) {
    ListingKind.accommodation => 'Accommodation',
    ListingKind.experience => 'Experience',
  };
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment});

  final String? comment;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (comment == null) {
      return Text(
        'A rating was left without a word beside it.',
        style: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: AppSizes.panelHeight),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: AppRadii.medium,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: SingleChildScrollView(
        child: SelectableText(comment!, style: text.bodyMedium),
      ),
    );
  }
}
