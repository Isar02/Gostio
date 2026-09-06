import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/paged_list.dart';
import '../data/trip_window.dart';
import '../data/trips_repository.dart';
import 'trip_card.dart';
import 'trip_screen.dart';
import 'trips_notifier.dart';

// What this account has booked, in two lists over one toggle: what is still
// ahead of the reader, and what is behind them. Both are kept alive rather
// than rebuilt on each switch, so a list read halfway down is where it was
// left when the reader comes back to it.
//
// This is the tab's body rather than its screen: the bar over it is the
// shell's, because the bell in it belongs to every tab and not to this one.
typedef TripOpener = Future<void> Function(
  BuildContext context,
  Reservation booking,
  ValueChanged<Reservation> onChanged,
);

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    required this.guestId,
    this.openTrip = _openTrip,
    super.key,
  });

  final int guestId;
  final TripOpener openTrip;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<UpcomingTrips>(
          create: (BuildContext context) =>
              UpcomingTrips(context.read<TripsRepository>(), guestId),
        ),
        ChangeNotifierProvider<PastTrips>(
          create: (BuildContext context) =>
              PastTrips(context.read<TripsRepository>(), guestId),
        ),
      ],
      child: _Trips(openTrip: openTrip),
    );
  }
}

class _Trips extends StatefulWidget {
  const _Trips({required this.openTrip});

  final TripOpener openTrip;

  @override
  State<_Trips> createState() => _TripsState();
}

class _TripsState extends State<_Trips> {
  TripWindow _window = TripWindow.upcoming;

  @override
  void initState() {
    super.initState();

    // The list in front reads itself; the one behind waits until it is shown,
    // because a reader who never looks back should not have paid for the read.
    //
    // It is asked after the frame that mounts this rather than during it: a
    // notifier that published from inside initState would be dirtying the tree
    // it is being built into.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _read(_window);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Toggle(window: _window, onChosen: _reveal),
        Expanded(
          child: IndexedStack(
            index: _window.index,
            children: <Widget>[
              _TripList(
                context.read<UpcomingTrips>(),
                openTrip: widget.openTrip,
              ),
              _TripList(context.read<PastTrips>(), openTrip: widget.openTrip),
            ],
          ),
        ),
      ],
    );
  }

  void _reveal(TripWindow window) {
    setState(() => _window = window);
    _read(window);
  }

  void _read(TripWindow window) => unawaited(_of(window).readOnce());

  TripsNotifier _of(TripWindow window) => switch (window) {
    TripWindow.upcoming => context.read<UpcomingTrips>(),
    TripWindow.past => context.read<PastTrips>(),
  };
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.window, required this.onChosen});

  final TripWindow window;
  final ValueChanged<TripWindow> onChosen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<TripWindow>(
          segments: <ButtonSegment<TripWindow>>[
            for (final TripWindow option in TripWindow.values)
              ButtonSegment<TripWindow>(
                value: option,
                label: Text(option.label),
              ),
          ],
          selected: <TripWindow>{window},
          showSelectedIcon: false,
          onSelectionChanged: (Set<TripWindow> chosen) =>
              onChosen(chosen.single),
        ),
      ),
    );
  }
}

// One side of the split, drawn as the paged card list every other list on this
// client is drawn as. A card opens the booking it stands for, and what that
// screen changes comes back here as the one row it changed.
class _TripList extends StatelessWidget {
  const _TripList(this.trips, {required this.openTrip});

  final TripsNotifier trips;
  final TripOpener openTrip;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: trips,
      builder: (BuildContext context, Widget? _) => PagedList<Reservation>(
        items: trips.items,
        totalCount: trips.totalCount,
        noun: 'bookings',
        isLoading: trips.isLoading,
        isAppending: trips.isAppending,
        failureMessage: trips.failureMessage,
        failureTraceId: trips.failureTraceId,
        onMore: trips.more,
        onRetry: trips.retry,
        onRefresh: trips.reload,
        emptyTitle: trips.window.emptyTitle,
        emptyMessage: trips.window.emptyMessage,
        itemBuilder: (BuildContext context, Reservation booking) => TripCard(
          booking,
          onTap: () => unawaited(openTrip(context, booking, trips.tripChanged)),
        ),
      ),
    );
  }
}

Future<void> _openTrip(
  BuildContext context,
  Reservation booking,
  ValueChanged<Reservation> onChanged,
) => TripScreen.open(context, booking, onChanged: onChanged);
