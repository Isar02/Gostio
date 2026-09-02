import 'package:flutter/material.dart';

import '../../../core/widgets/filter_bar.dart';
import '../data/reference_query.dart';

// One term, the only filter any of the eight endpoints takes beyond the page.
class ReferenceFilters extends StatefulWidget {
  const ReferenceFilters({
    required this.plural,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final String plural;

  // The query the rows on screen were fetched under, which is what this
  // control has to describe once a request has settled.
  final ReferenceQuery applied;

  final bool isLoading;
  final ValueChanged<ReferenceQuery> onChanged;
  final Widget? trailing;

  @override
  State<ReferenceFilters> createState() => _ReferenceFiltersState();
}

class _ReferenceFiltersState extends State<ReferenceFilters> {
  final TextEditingController _name = TextEditingController();

  ReferenceQuery _announced = const ReferenceQuery();
  int _editRevision = 0;
  int _announcedRevision = 0;

  // A request that did not take leaves the rows on the query before it, so the
  // field goes back to that one rather than labelling old rows with a term
  // that never loaded. A field being typed into is left alone.
  @override
  void didUpdateWidget(ReferenceFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading &&
        widget.applied != _announced &&
        _editRevision == _announcedRevision) {
      setState(() {
        _name.text = widget.applied.name ?? '';
        _announced = widget.applied;
        _announcedRevision = _editRevision;
      });
    }
  }

  void _announce() {
    _announced = ReferenceQuery(name: _name.text);
    _announcedRevision = _editRevision;

    widget.onChanged(_announced);
  }

  void _clear() {
    setState(_name.clear);
    _editRevision++;
    _announce();
  }

  @override
  void dispose() {
    _name.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: _clear,
      trailing: widget.trailing,
      filters: <Widget>[
        FilterField(
          label: 'Name',
          child: FilterTextField(
            controller: _name,
            hint: 'Search ${widget.plural}',
            onEdited: () => _editRevision++,
            onChanged: (String _) => _announce(),
          ),
        ),
      ],
    );
  }
}
