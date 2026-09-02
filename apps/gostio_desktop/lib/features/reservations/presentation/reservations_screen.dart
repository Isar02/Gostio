import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experiences_repository.dart';
import '../../reference/data/reference_repository.dart';
import '../data/reservation.dart';
import '../data/reservations_repository.dart';
import 'reservation_detail_screen.dart';
import 'reservation_filter_options.dart';
import 'reservation_filters.dart';
import 'reservation_standing.dart';
import 'reservations_notifier.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({this.hostId, super.key});

  final int? hostId;

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  late final Future<ReservationFilterOptions> _options;

  @override
  void initState() {
    super.initState();
    _options = ReservationFilterOptions.load(
      context.read<ReferenceRepository>(),
      context.read<AccommodationsRepository>(),
      context.read<ExperiencesRepository>(),
      hostId: widget.hostId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReservationsNotifier>(
      create: (BuildContext context) {
        final ReservationsNotifier reservations = ReservationsNotifier(
          context.read<ReservationsRepository>(),
          hostId: widget.hostId,
        );
        unawaited(reservations.reload());

        return reservations;
      },
      child: _Body(options: _options),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options});

  final Future<ReservationFilterOptions> options;

  @override
  Widget build(BuildContext context) {
    final ReservationsNotifier reservations = context
        .watch<ReservationsNotifier>();
    final String? failure = reservations.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FutureBuilder<ReservationFilterOptions>(
            future: options,
            builder: (
              BuildContext context,
              AsyncSnapshot<ReservationFilterOptions> snapshot,
            ) => _filters(context, snapshot, reservations),
          ),
          if (failure != null && reservations.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: reservations.isLoading
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: RecordTable<Reservation>(
              columns: _columns,
              rows: reservations.items,
              onRowOpen: (Reservation row) =>
                  _open(context, reservations, row.id),
              empty: _Nothing(reservations: reservations),
              footer: PaginationFooter(
                page: reservations.page,
                pageSize: reservations.pageSize,
                totalCount: reservations.totalCount,
                onPageChanged: reservations.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A list that did not arrive leaves its dropdown holding nothing.
  Widget _filters(
    BuildContext context,
    AsyncSnapshot<ReservationFilterOptions> snapshot,
    ReservationsNotifier reservations,
  ) {
    final Widget filters = ReservationFilters(
      options: snapshot.data ?? ReservationFilterOptions.none,
      applied: reservations.query,
      isLoading: reservations.isLoading,
      onChanged: reservations.apply,
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

  // Nothing is created here: the guest makes the booking. The list reloads
  // only when the detail hands one back that something moved.
  Future<void> _open(
    BuildContext context,
    ReservationsNotifier reservations,
    int id,
  ) async {
    final Reservation? moved = await Navigator.of(context).push<Reservation>(
      MaterialPageRoute<Reservation>(
        builder: (BuildContext context) =>
            ReservationDetailScreen(reservationId: id),
      ),
    );

    if (moved != null) {
      await reservations.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.reservations});

  final ReservationsNotifier reservations;

  @override
  Widget build(BuildContext context) {
    if (reservations.isLoading) {
      return const LoadingState();
    }

    if (reservations.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: reservations.reload,
        traceId: reservations.failureTraceId,
      );
    }

    return reservations.query.isEmpty
        ? const EmptyState(
            title: 'No bookings',
            message:
                'Bookings appear here as guests take places. Nothing is '
                'booked from this side.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message:
                'No booking answers every filter set above. Only a stay '
                'arrives and departs — a term is asked after through the '
                'window.',
          );
  }
}

// The listing reads longest; the guest's name is the other half of a row.
const int _listingShare = 3;
const int _guestShare = 2;

final List<TableColumn<Reservation>> _columns = <TableColumn<Reservation>>[
  TableColumn<Reservation>.text(
    label: 'Guest',
    read: (Reservation row) => row.guestName,
    flex: _guestShare,
  ),
  TableColumn<Reservation>.text(
    label: 'Listing',
    read: (Reservation row) => row.listingTitle,
    flex: _listingShare,
  ),
  // A term names a slot rather than two dates, and the booking carries nothing
  // about when that slot runs, so the detail is where a term says when it is.
  TableColumn<Reservation>.text(
    label: 'Check-in',
    read: (Reservation row) => _day(row.checkInDate),
    width: AppSizes.dateColumn,
  ),
  TableColumn<Reservation>.text(
    label: 'Check-out',
    read: (Reservation row) => _day(row.checkOutDate),
    width: AppSizes.dateColumn,
  ),
  TableColumn<Reservation>.number(
    label: 'Guests',
    read: (Reservation row) => '${row.guestCount}',
    width: AppSizes.compactColumn,
  ),
  TableColumn<Reservation>.number(
    label: 'Total',
    read: (Reservation row) => AppNumbers.money(row.totalPrice),
  ),
  TableColumn<Reservation>.text(
    label: 'Settled',
    read: (Reservation row) => row.isPaid ? 'Paid' : 'Not paid',
    width: AppSizes.compactColumn,
  ),
  TableColumn<Reservation>(
    label: 'Status',
    width: AppSizes.statusColumn,
    cell: (BuildContext context, Reservation row) =>
        StatusChip(row.status, tone: ReservationStanding.toneOf(row.standing)),
  ),
  TableColumn<Reservation>.text(
    label: 'Booked',
    read: (Reservation row) => AppDates.date(row.createdAt),
    width: AppSizes.dateColumn,
  ),
];

String _day(DateTime? value) => value == null ? '—' : AppDates.day(value);
