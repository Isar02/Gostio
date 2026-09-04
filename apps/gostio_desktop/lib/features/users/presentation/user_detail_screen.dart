import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reference/data/reference_repository.dart';
import '../data/users_repository.dart';
import 'account_state.dart';
import 'user_detail_notifier.dart';
import 'user_form.dart';

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({
    required this.signedInUserId,
    this.userId,
    super.key,
  });

  final int signedInUserId;

  // Absent means the screen is making an account rather than editing one.
  final int? userId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserDetailNotifier>(
      create: (BuildContext context) {
        final UserDetailNotifier notifier = UserDetailNotifier(
          context.read<UsersRepository>(),
          context.read<ReferenceRepository>(),
          userId: userId,
          signedInUserId: signedInUserId,
        );
        unawaited(notifier.load());

        return notifier;
      },
      child: const _Detail(),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final UserDetailNotifier notifier = context.watch<UserDetailNotifier>();

    if (notifier.isLoading) {
      return const LoadingState(message: 'Reading the account');
    }

    // What the API said comes before anything this screen concludes: a load
    // that failed leaves the roles empty, which is not the same as a table
    // that has nothing in it.
    if (notifier.failureMessage case final String message) {
      return ErrorState(
        message: message,
        onRetry: notifier.load,
        traceId: notifier.failureTraceId,
      );
    }

    if (notifier.user == null && !notifier.isCreating) {
      return ErrorState(
        message: 'This account could not be read.',
        onRetry: notifier.load,
      );
    }

    if (notifier.roles.isEmpty) {
      return const _Unready();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(notifier: notifier),
        Expanded(
          child: UserForm(
            notifier: notifier,
            onSaved: (User saved) => _saved(context, notifier, saved),
            onDeleted: (User deleted) =>
                _leave(context, deleted, '${deleted.fullName} was deleted.'),
          ),
        ),
      ],
    );
  }

  // An edited account is already on the page the list is showing, so the
  // screen goes back to it. A created one is ordered by surname like every
  // other and no page can be promised to hold it, so the form stays and
  // empties instead.
  static void _saved(
    BuildContext context,
    UserDetailNotifier notifier,
    User saved,
  ) {
    if (!notifier.isCreating) {
      _leave(context, saved, '${saved.fullName} was updated.');

      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${saved.fullName} was created.')));
  }

  static void _leave(BuildContext context, User account, String said) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
    Navigator.of(context).pop(account);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifier});

  final UserDetailNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final User? account = notifier.isCreating ? null : notifier.user;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          // A save in flight has not said what it did yet, and it may still be
          // several writes from done, so leaving now would hand the list a row
          // that is about to be wrong.
          IconButton(
            onPressed: notifier.isSaving
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(notifier.hasChanged ? notifier.user : null),
            icon: const Icon(Icons.arrow_back),
            tooltip: notifier.isSaving
                ? 'The write in flight has to land first.'
                : 'Back to the list',
          ),
          const SizedBox(width: AppSpacing.sm),
          if (account case final User account) ...<Widget>[
            AccountAvatar(
              userId: account.id,
              name: account.fullName,
              hasImage: account.hasProfileImage,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  account?.fullName ?? 'New account',
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (account case final User account)
                  Text(
                    '@${account.username} · joined '
                    '${AppDates.date(account.createdAt)}',
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (account case final User account) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            StatusChip(
              AccountState.of(account.isActive).label,
              tone: account.isActive ? Tone.positive : Tone.neutral,
            ),
          ],
        ],
      ),
    );
  }
}

class _Unready extends StatelessWidget {
  const _Unready();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to the list',
            ),
          ),
        ),
        const Expanded(
          child: EmptyState(
            title: 'No roles to give',
            message:
                'An account holds at least one role, and the roles table is '
                'empty. Add one under Reference data first.',
          ),
        ),
      ],
    );
  }
}
