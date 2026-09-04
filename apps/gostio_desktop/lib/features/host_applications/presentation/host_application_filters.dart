import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../data/host_application_query.dart';

class HostApplicationFilters extends StatefulWidget {
  const HostApplicationFilters({
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  // The query the rows on screen were fetched under.
  final HostApplicationQuery applied;

  final bool isLoading;
  final ValueChanged<HostApplicationQuery> onChanged;

  @override
  State<HostApplicationFilters> createState() => _HostApplicationFiltersState();
}

class _HostApplicationFiltersState extends State<HostApplicationFilters> {
  HostApplicationStatus? _status;

  HostApplicationQuery _announced = const HostApplicationQuery();

  @override
  void initState() {
    super.initState();
    _adopt(widget.applied);
  }

  // Nothing here is typed into, so the control announces the moment it is
  // touched. A request that did not take leaves the rows on the query before
  // it, and the control goes back to that one.
  @override
  void didUpdateWidget(HostApplicationFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading && widget.applied != _announced) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(HostApplicationQuery query) {
    _status = query.status;
    _announced = query;
  }

  void _change(HostApplicationStatus? status) {
    setState(() => _status = status);

    _announced = HostApplicationQuery(status: status);
    widget.onChanged(_announced);
  }

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: () => _change(null),
      filters: <Widget>[
        FilterField(
          label: 'Status',
          child: AppOptionalDropdown<HostApplicationStatus>(
            anyLabel: 'All',
            value: _status,
            values: HostApplicationStatus.values,
            labels: (HostApplicationStatus standing) => standing.label,
            onChanged: _change,
          ),
        ),
      ],
    );
  }
}
