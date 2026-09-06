import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/rating_input.dart';
import 'booking_review_notifier.dart';

// What a guest says about what they booked: a rating, and the words they may
// leave out. Leaving a review and changing one are the same form, because the
// server holds one review per booking either way.
abstract final class ReviewSheet {
  static Future<void> show(
    BuildContext context, {
    required String listingTitle,
  }) {
    final BookingReviewNotifier review = context.read<BookingReviewNotifier>();

    return AppSheet.show<void>(
      context,
      title: review.review == null ? 'Write a review' : 'Edit your review',
      isScrollable: false,
      // The notifier belongs to the route that draws the booking and outlives
      // this sheet. The sheet borrows it so a write that finishes after this
      // closes still reaches whatever is showing the review.
      builder: (BuildContext context) =>
          ChangeNotifierProvider<BookingReviewNotifier>.value(
            value: review,
            child: _ReviewForm(listingTitle),
          ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm(this.listingTitle);

  final String listingTitle;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm>
    with FormValidation<_ReviewForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>['comment']);
  final TextEditingController _comment = TextEditingController();

  int? _rating;
  int? _openedOnRating;
  String _openedOnComment = '';

  @override
  void initState() {
    super.initState();

    // The review as it stands is what the form opens on, so changing one is
    // editing what is there rather than writing it out again.
    final Review? written = context.read<BookingReviewNotifier>().review;
    _rating = written?.rating;
    _openedOnRating = written?.rating;
    _openedOnComment = written?.comment ?? '';
    _comment
      ..text = _openedOnComment
      ..addListener(_typingChanged);
  }

  @override
  void dispose() {
    _comment
      ..removeListener(_typingChanged)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BookingReviewNotifier review = context.watch<BookingReviewNotifier>();
    final TextTheme text = Theme.of(context).textTheme;

    return DiscardGuard(
      hasInput: _hasInput && !review.isBusy,
      title: 'Leave this review?',
      message: 'What you have written will not be kept.',
      child: Column(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(widget.listingTitle, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Only the guest who booked says how it was, and what you '
                    'write is shown with your name on the listing.',
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  RatingInput(rating: _rating, onChanged: _rate),
                  // The server is the authority on what it will take, and the
                  // stars have no error slot of their own to say so in.
                  if (review.messageFor('rating') case final String fault)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        fault,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Form(
                    key: _form,
                    autovalidateMode: validation,
                    child: TextFormField(
                      key: _fields['comment'],
                      controller: _comment,
                      enabled: !review.isBusy,
                      minLines: 3,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Comment',
                        alignLabelWithHint: true,
                        helperText: 'Optional.',
                        errorText: review.messageFor('comment'),
                      ),
                      validator: Validators.reviewComment,
                      onChanged: (_) => review.clearFailureFor('comment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (review.refusal case final String refusal)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: AppNotice(refusal),
            ),
          BottomActionBar(
            // A review is its rating, so nothing is sent until one is given.
            // A button that has to be pressed to learn that is a button that
            // lied.
            action: FilledButton(
              onPressed: _rating == null || review.isBusy ? null : _submit,
              child: Text(review.isBusy ? 'Sending' : _sendLabel(review)),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasInput =>
      _rating != _openedOnRating || _comment.text != _openedOnComment;

  String _sendLabel(BookingReviewNotifier review) =>
      review.review == null ? 'Post review' : 'Save changes';

  void _rate(int rating) {
    setState(() => _rating = rating);
    context.read<BookingReviewNotifier>().clearFailureFor('rating');
  }

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    final int? rating = _rating;
    if (rating == null || !validate(_form, _fields)) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? sheet = ModalRoute.of(context);
    final BookingReviewNotifier review = context.read<BookingReviewNotifier>();
    final String written = _comment.text.trim();

    final bool sent = await review.save(
      rating: rating,
      comment: written.isEmpty ? null : written,
    );

    if (!sent) {
      final ApiException? refused = review.failure;
      if ((sheet?.isCurrent ?? false) && refused != null) {
        _fields.revealFault(refused);
      }

      return;
    }

    // The notifier has already handed the row to its owner. This closes only
    // the sheet, and only where the reader has not already left.
    if (sheet?.isCurrent ?? false) {
      navigator.pop();
    }
  }
}
