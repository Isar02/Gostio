import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../reference/data/reference_repository.dart';
import '../data/users_repository.dart';
import 'account_state.dart';
import 'user_detail_screen.dart';
import 'user_filter_options.dart';
import 'user_filters.dart';
import 'users_notifier.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({required this.signedInUserId, super.key});

  final int signedInUserId;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final Future<UserFilterOptions> _options;

  @override
  void initState() {
    super.initState();
    _options = UserFilterOptions.load(context.read<ReferenceRepository>());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UsersNotifier>(
      create: (BuildContext context) {
        final UsersNotifier users = UsersNotifier(
          context.read<UsersRepository>(),
        );
        unawaited(users.reload());

        return users;
      },
      child: _Body(options: _options, signedInUserId: widget.signedInUserId),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options, required this.signedInUserId});

  final Future<UserFilterOptions> options;
  final int signedInUserId;

  @override
  Widget build(BuildContext context) {
    final UsersNotifier users = context.watch<UsersNotifier>();
    final String? failure = users.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FutureBuilder<UserFilterOptions>(
            future: options,
            builder: (
              BuildContext context,
              AsyncSnapshot<UserFilterOptions> snapshot,
            ) => _filters(context, snapshot, users),
          ),
          if (failure != null && users.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: users.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RecordTable<User>(
              columns: _columns,
              rows: users.items,
              onRowOpen: (User row) => _open(context, users, id: row.id),
              empty: _Nothing(users: users),
              footer: PaginationFooter(
                page: users.page,
                pageSize: users.pageSize,
                totalCount: users.totalCount,
                onPageChanged: users.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A filter list that did not arrive leaves its dropdown holding nothing,
  // which is worth saying rather than showing as an empty menu.
  Widget _filters(
    BuildContext context,
    AsyncSnapshot<UserFilterOptions> snapshot,
    UsersNotifier users,
  ) {
    final Widget filters = UserFilters(
      options: snapshot.data ?? UserFilterOptions.none,
      applied: users.query,
      isLoading: users.isLoading,
      onChanged: users.apply,
      trailing: FilledButton.icon(
        onPressed: () => _open(context, users),
        icon: const Icon(Icons.add, size: AppSizes.iconSmall),
        label: const Text('New account'),
      ),
    );

    if (snapshot.error case final Object failure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNotice('The filter lists could not be read. $failure'),
          const SizedBox(height: AppSpacing.md),
          filters,
        ],
      );
    }

    return filters;
  }

  // The detail is pushed over the list rather than beside it, and the list
  // reloads only when it hands back the row it wrote.
  Future<void> _open(
    BuildContext context,
    UsersNotifier users, {
    int? id,
  }) async {
    final User? changed = await Navigator.of(context).push<User>(
      MaterialPageRoute<User>(
        builder: (BuildContext context) =>
            UserDetailScreen(signedInUserId: signedInUserId, userId: id),
      ),
    );

    if (changed != null) {
      await users.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.users});

  final UsersNotifier users;

  @override
  Widget build(BuildContext context) {
    if (users.isLoading) {
      return const LoadingState();
    }

    if (users.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: users.reload,
        traceId: users.failureTraceId,
      );
    }

    return users.query.isEmpty
        ? const EmptyState(
            title: 'No accounts',
            message: 'Guests register themselves; anybody else is made here.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No account answers every filter set above.',
          );
  }
}

// The name reads longest, and the address beside it is the next longest.
const int _nameShare = 3;
const int _emailShare = 3;
const int _roleShare = 2;

final List<TableColumn<User>> _columns = <TableColumn<User>>[
  TableColumn<User>(
    label: 'Name',
    flex: _nameShare,
    cell: (BuildContext context, User row) => Row(
      children: <Widget>[
        AccountAvatar(
          userId: row.id,
          name: row.fullName,
          hasImage: row.hasProfileImage,
          size: AppSizes.thumbnail,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(row.fullName)),
      ],
    ),
  ),
  TableColumn<User>.text(
    label: 'Username',
    read: (User row) => row.username,
    flex: _roleShare,
  ),
  TableColumn<User>.text(
    label: 'Email',
    read: (User row) => row.email,
    flex: _emailShare,
  ),
  TableColumn<User>.text(
    label: 'Roles',
    read: (User row) => row.roles.join(', '),
    flex: _roleShare,
  ),
  TableColumn<User>(
    label: 'Status',
    width: AppSizes.statusColumn,
    cell: (BuildContext context, User row) => StatusChip(
      AccountState.of(row.isActive).label,
      tone: row.isActive ? Tone.positive : Tone.neutral,
    ),
  ),
  TableColumn<User>.text(
    label: 'Joined',
    read: (User row) => AppDates.date(row.createdAt),
    width: AppSizes.dateColumn,
  ),
];
