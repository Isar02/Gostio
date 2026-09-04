import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../listings/data/listing_choice.dart';
import '../data/reservation_query.dart';
import 'reservation_filter_options.dart';
import 'reservation_hold.dart';

class ReservationFilters extends StatefulWidget {
  const ReservationFilters({
    required this.options,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  final ReservationFilterOptions options;

  // The query the rows on screen were fetched under.
  final ReservationQuery applied;

  final bool isLoading;
  final ValueChanged<ReservationQuery> onChanged;

  @override
  State<ReservationFilters> createState() => _ReservationFiltersState();
}

class _ReservationFiltersState extends State<ReservationFilters> {
  ListingChoice? _listing;
  LookupItem? _status;
  ReservationHold _hold = ReservationHold.any;
  DateTime? _from;
  DateTime? _to;
  DateTime? _arrivesOn;
  DateTime? _departsOn;

  ReservationQuery _announced = const ReservationQuery();

  @override
  void initState() {
    super.initState();
    _adopt(widget.applied);
  }

  // Nothing here is typed into, so a control announces the moment it is
  // touched. A request that did not take leaves the rows on the query before
  // it, and the controls go back to that one.
  @override
  void didUpdateWidget(ReservationFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading && widget.applied != _announced) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(ReservationQuery query) {
    _listing = _listingFor(query.listing);
    _status = _statusFor(query.reservationStatusId);
    _hold = ReservationHold.values.firstWhere(
      (ReservationHold hold) => hold.isActive == query.isActive,
    );
    _from = query.from;
    _to = query.to;
    _arrivesOn = query.arrivesOn;
    _departsOn = query.departsOn;
    _announced = query;
  }

  void _announce() {
    _announced = ReservationQuery(
      listing: _listing?.address,
      reservationStatusId: _status?.id,
      isActive: _hold.isActive,
      from: _from,
      to: _to,
      arrivesOn: _arrivesOn,
      departsOn: _departsOn,
    );

    widget.onChanged(_announced);
  }

  void _change(VoidCallback edit) {
    setState(edit);
    _announce();
  }

  void _clear() => _change(() {
    _listing = null;
    _status = null;
    _hold = ReservationHold.any;
    _from = null;
    _to = null;
    _arrivesOn = null;
    _departsOn = null;
  });

  ListingChoice? _listingFor(ListingAddress? address) {
    for (final ListingChoice candidate in widget.options.listings) {
      if (candidate.address == address) {
        return candidate;
      }
    }

    return null;
  }

  LookupItem? _statusFor(int? id) {
    for (final LookupItem candidate in widget.options.statuses) {
      if (candidate.id == id) {
        return candidate;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: _clear,
      filters: <Widget>[
        FilterField(
          label: 'Listing',
          width: AppSizes.filterFieldWide,
          child: AppOptionalDropdown<ListingChoice>(
            anyLabel: 'Any listing',
            value: _listing,
            values: widget.options.listings,
            labels: (ListingChoice booked) => booked.title,
            onChanged: (ListingChoice? booked) =>
                _change(() => _listing = booked),
          ),
        ),
        FilterField(
          label: 'Status',
          child: AppOptionalDropdown<LookupItem>(
            value: _status,
            values: widget.options.statuses,
            labels: (LookupItem status) => status.name,
            onChanged: (LookupItem? status) => _change(() => _status = status),
          ),
        ),
        FilterField(
          label: 'Holds a place',
          child: AppDropdown<ReservationHold>(
            value: _hold,
            values: ReservationHold.values,
            labels: (ReservationHold hold) => hold.label,
            onChanged: (ReservationHold hold) => _change(() => _hold = hold),
          ),
        ),
        // The two edges bound each other's picker: a window that ends before
        // it starts is one the API refuses.
        FilterField(
          label: 'Taken from',
          child: DateField(
            value: _from,
            hint: 'Any day',
            lastDate: _to,
            onChanged: (DateTime? from) => _change(() => _from = from),
          ),
        ),
        FilterField(
          label: 'Taken to',
          child: DateField(
            value: _to,
            hint: 'Any day',
            firstDate: _from,
            onChanged: (DateTime? to) => _change(() => _to = to),
          ),
        ),
        FilterField(
          label: 'Arrives on',
          child: DateField(
            value: _arrivesOn,
            hint: 'Any day',
            onChanged: (DateTime? day) => _change(() => _arrivesOn = day),
          ),
        ),
        FilterField(
          label: 'Departs on',
          child: DateField(
            value: _departsOn,
            hint: 'Any day',
            onChanged: (DateTime? day) => _change(() => _departsOn = day),
          ),
        ),
      ],
    );
  }
}
