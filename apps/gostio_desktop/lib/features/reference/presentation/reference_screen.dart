import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/reference_repository.dart';
import '../data/reference_row.dart';
import '../data/reference_rows_repository.dart';
import '../data/reference_table.dart';
import 'reference_filters.dart';
import 'reference_layout.dart';
import 'reference_notifier.dart';
import 'reference_row_dialog.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({required this.table, super.key});

  final ReferenceTable table;

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  late final ReferenceLayout _layout = ReferenceLayout.of(widget.table);

  List<LookupItem> _choices = List<LookupItem>.empty();
  String? _choicesFailure;

  @override
  void initState() {
    super.initState();
    unawaited(_readChoices(context.read<ReferenceRepository>()));
  }

  Future<void> _readChoices(ReferenceRepository reference) async {
    if (_layout.choices case final ChoiceReader read) {
      try {
        final List<LookupItem> choices = await read(reference);

        if (mounted) {
          setState(() => _choices = choices);
        }
      } on ApiException catch (failure) {
        if (mounted) {
          setState(() => _choicesFailure = failure.message);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReferenceNotifier>(
      create: (BuildContext context) {
        final ReferenceNotifier rows = ReferenceNotifier(
          context.read<ReferenceRowsRepository>(),
          table: widget.table,
        );
        unawaited(rows.reload());

        return rows;
      },
      child: _Body(
        table: widget.table,
        layout: _layout,
        choices: _choices,
        choicesFailure: _choicesFailure,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.table,
    required this.layout,
    required this.choices,
    required this.choicesFailure,
  });

  final ReferenceTable table;
  final ReferenceLayout layout;
  final List<LookupItem> choices;
  final String? choicesFailure;

  @override
  Widget build(BuildContext context) {
    final ReferenceNotifier rows = context.watch<ReferenceNotifier>();
    final String? shut = _writingIsShut(rows);
    final String? failure = rows.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (shut case final String reason) ...<Widget>[
            AppNotice(reason, tone: Tone.attention),
            const SizedBox(height: AppSpacing.md),
          ],
          ReferenceFilters(
            plural: table.plural,
            applied: rows.query,
            isLoading: rows.isLoading,
            onChanged: rows.apply,
            trailing: Tooltip(
              message: shut ?? 'Add a ${table.noun} to this table.',
              child: FilledButton.icon(
                onPressed: shut == null ? () => _open(context, rows) : null,
                icon: const Icon(Icons.add, size: AppSizes.iconSmall),
                label: Text('New ${table.noun}'),
              ),
            ),
          ),
          if (failure != null && rows.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: rows.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RecordTable<ReferenceRow>(
              columns: _columns,
              rows: rows.items,
              onRowOpen: shut == null
                  ? (ReferenceRow row) => _open(context, rows, row)
                  : null,
              empty: _Nothing(table: table, rows: rows),
              footer: PaginationFooter(
                page: rows.page,
                pageSize: rows.pageSize,
                totalCount: rows.totalCount,
                onPageChanged: rows.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _writingIsShut(ReferenceNotifier rows) {
    if (rows.isStale) {
      return 'A change was written and the table could not be read again '
          'afterwards, so what stands here may be behind the server. Read it '
          'again before writing anything else.';
    }

    if (layout.choices == null || choices.isNotEmpty) {
      return null;
    }

    final String noun = _choiceLabel.toLowerCase();

    return switch (choicesFailure) {
      final String failure =>
        'The $noun list could not be read, so no $noun can be chosen for a '
            '${table.noun}. $failure',
      null => 'Reading the $noun a ${table.noun} is placed in.',
    };
  }

  String get _choiceLabel => layout.fields
      .firstWhere(
        (ReferenceField field) => field.kind == ReferenceFieldKind.choice,
      )
      .label;

  List<TableColumn<ReferenceRow>> get _columns => <TableColumn<ReferenceRow>>[
    TableColumn<ReferenceRow>.text(
      label: 'Name',
      read: (ReferenceRow row) => row.name,
      flex: _nameShare,
    ),
    for (final ReferenceColumn column in layout.columns)
      TableColumn<ReferenceRow>.text(
        label: column.label,
        read: (ReferenceRow row) => _orDash(row.text(column.key)),
        width: column.width,
        flex: column.flex,
      ),
  ];

  Future<void> _open(
    BuildContext context,
    ReferenceNotifier rows, [
    ReferenceRow? row,
  ]) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? written = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => ReferenceRowDialog(
        noun: table.noun,
        layout: layout,
        row: row,
        choices: choices,
        save: (JsonMap body) =>
            row == null ? rows.add(body) : rows.save(row.id, body),
        remove: row == null ? null : () => rows.remove(row.id),
      ),
    );

    if (written case final String said) {
      messenger.showSnackBar(SnackBar(content: Text(said)));
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.table, required this.rows});

  final ReferenceTable table;
  final ReferenceNotifier rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isLoading) {
      return const LoadingState();
    }

    if (rows.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: rows.reload,
        traceId: rows.failureTraceId,
      );
    }

    return rows.query.isEmpty
        ? EmptyState(
            title: 'No ${table.plural}',
            message:
                'Nothing stands in this table yet. What is added here is what '
                'the rest of the platform is filled in from.',
          )
        : EmptyState(
            title: 'Nothing matches',
            message: 'No ${table.noun} answers the term above.',
          );
  }
}

String _orDash(String value) => value.isEmpty ? '—' : value;

const int _nameShare = 2;
