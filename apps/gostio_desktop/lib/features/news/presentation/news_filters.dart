import 'package:flutter/material.dart';

import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/filter_bar.dart';
import '../data/news_query.dart';

class NewsFilters extends StatefulWidget {
  const NewsFilters({
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  // The query the rows on screen were fetched under.
  final NewsQuery applied;

  final bool isLoading;
  final ValueChanged<NewsQuery> onChanged;
  final Widget? trailing;

  @override
  State<NewsFilters> createState() => _NewsFiltersState();
}

class _NewsFiltersState extends State<NewsFilters> {
  final TextEditingController _title = TextEditingController();

  DateTime? _from;
  DateTime? _to;

  NewsQuery _announced = const NewsQuery();
  int _editRevision = 0;
  int _announcedRevision = 0;

  @override
  void initState() {
    super.initState();
    _adopt(widget.applied);
  }

  // A request that did not take leaves the rows on the query before it. A
  // field being typed into is left alone.
  @override
  void didUpdateWidget(NewsFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading &&
        widget.applied != _announced &&
        _editRevision == _announcedRevision) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(NewsQuery query) {
    _title.text = query.title ?? '';
    _from = query.publishedFrom;
    _to = query.publishedTo;
    _announced = query;
    _announcedRevision = _editRevision;
  }

  void _announce() {
    _announced = NewsQuery(
      title: _title.text,
      publishedFrom: _from,
      publishedTo: _to,
    );
    _announcedRevision = _editRevision;

    widget.onChanged(_announced);
  }

  void _change(VoidCallback edit) {
    setState(edit);
    _announce();
  }

  void _clear() {
    _editRevision++;
    _change(() {
      _title.clear();
      _from = null;
      _to = null;
    });
  }

  @override
  void dispose() {
    _title.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: _clear,
      trailing: widget.trailing,
      filters: <Widget>[
        FilterField(
          label: 'Title',
          child: FilterTextField(
            controller: _title,
            hint: 'Search articles',
            onEdited: () => _editRevision++,
            onChanged: (String _) => _announce(),
          ),
        ),
        // The two edges bound each other's picker.
        FilterField(
          label: 'Published from',
          child: DateField(
            value: _from,
            lastDate: _to,
            onChanged: (DateTime? from) => _change(() => _from = from),
          ),
        ),
        FilterField(
          label: 'Published to',
          child: DateField(
            value: _to,
            firstDate: _from,
            onChanged: (DateTime? to) => _change(() => _to = to),
          ),
        ),
      ],
    );
  }
}
