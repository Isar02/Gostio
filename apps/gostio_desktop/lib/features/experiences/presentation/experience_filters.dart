import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../listings/presentation/listing_status.dart';
import '../data/experience_query.dart';
import 'experience_filter_options.dart';

class ExperienceFilters extends StatefulWidget {
  const ExperienceFilters({
    required this.options,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final ExperienceFilterOptions options;

  // The query the rows on screen were fetched under, which is what these
  // controls have to describe once a request has settled.
  final ExperienceQuery applied;

  final bool isLoading;
  final ValueChanged<ExperienceQuery> onChanged;
  final Widget? trailing;

  @override
  State<ExperienceFilters> createState() => _ExperienceFiltersState();
}

class _ExperienceFiltersState extends State<ExperienceFilters> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _minPrice = TextEditingController();
  final TextEditingController _maxPrice = TextEditingController();
  final TextEditingController _maxDuration = TextEditingController();

  LookupItem? _city;
  LookupItem? _category;
  ListingStatus _status = ListingStatus.any;

  ExperienceQuery _announced = const ExperienceQuery();
  int _editRevision = 0;
  int _announcedRevision = 0;

  // A request that did not take leaves the rows on the query before it, so the
  // controls go back to that one rather than labelling old rows with a filter
  // that never loaded.
  @override
  void didUpdateWidget(ExperienceFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading &&
        widget.applied != _announced &&
        _editRevision == _announcedRevision) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(ExperienceQuery query) {
    _title.text = query.title ?? '';
    _minPrice.text = _written(query.minPrice);
    _maxPrice.text = _written(query.maxPrice);
    _maxDuration.text = _written(query.maxDurationMinutes);
    _city = _itemFor(widget.options.cities, query.cityId);
    _category = _itemFor(widget.options.categories, query.experienceCategoryId);
    _status = ListingStatus.values.firstWhere(
      (ListingStatus status) => status.isActive == query.isActive,
    );
    _announced = query;
    _announcedRevision = _editRevision;
  }

  void _announce() {
    _announced = ExperienceQuery(
      title: _title.text,
      cityId: _city?.id,
      experienceCategoryId: _category?.id,
      minPrice: double.tryParse(_minPrice.text),
      maxPrice: double.tryParse(_maxPrice.text),
      maxDurationMinutes: int.tryParse(_maxDuration.text),
      isActive: _status.isActive,
    );
    _announcedRevision = _editRevision;

    widget.onChanged(_announced);
  }

  static String _written(num? value) =>
      value == null ? '' : AppNumbers.typed(value);

  static LookupItem? _itemFor(List<LookupItem> values, int? id) {
    for (final LookupItem value in values) {
      if (value.id == id) {
        return value;
      }
    }

    return null;
  }

  void _change(VoidCallback edit) {
    setState(edit);
    _edited();
    _announce();
  }

  void _edited() => _editRevision++;

  void _clear() => _change(() {
    _title.clear();
    _minPrice.clear();
    _maxPrice.clear();
    _maxDuration.clear();
    _city = null;
    _category = null;
    _status = ListingStatus.any;
  });

  @override
  void dispose() {
    _title.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    _maxDuration.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExperienceFilterOptions options = widget.options;

    return FilterBar(
      onClear: _clear,
      trailing: widget.trailing,
      filters: <Widget>[
        FilterField(
          label: 'Title',
          child: FilterTextField(
            controller: _title,
            hint: 'Search titles',
            onEdited: _edited,
            onChanged: (String _) => _announce(),
          ),
        ),
        FilterField(
          label: 'City',
          child: _lookup(
            value: _city,
            values: options.cities,
            onChanged: (LookupItem? city) => _change(() => _city = city),
          ),
        ),
        FilterField(
          label: 'Category',
          child: _lookup(
            value: _category,
            values: options.categories,
            onChanged: (LookupItem? category) =>
                _change(() => _category = category),
          ),
        ),
        FilterField(
          label: 'Price from',
          width: AppSizes.filterFieldNarrow,
          child: _amount(_minPrice),
        ),
        FilterField(
          label: 'Price to',
          width: AppSizes.filterFieldNarrow,
          child: _amount(_maxPrice),
        ),
        FilterField(
          label: 'Minutes at most',
          width: AppSizes.filterFieldNarrow,
          child: FilterTextField(
            controller: _maxDuration,
            formatters: <TextInputFormatter>[InputFormats.whole],
            onEdited: _edited,
            onChanged: (String _) => _announce(),
          ),
        ),
        FilterField(
          label: 'Status',
          child: AppDropdown<ListingStatus>(
            value: _status,
            values: ListingStatus.values,
            labels: (ListingStatus status) => status.label,
            onChanged: (ListingStatus status) =>
                _change(() => _status = status),
          ),
        ),
      ],
    );
  }

  Widget _lookup({
    required LookupItem? value,
    required List<LookupItem> values,
    required ValueChanged<LookupItem?> onChanged,
  }) => AppOptionalDropdown<LookupItem>(
    value: value,
    values: values,
    labels: (LookupItem item) => item.name,
    onChanged: onChanged,
  );

  Widget _amount(TextEditingController controller) => FilterTextField(
    controller: controller,
    formatters: <TextInputFormatter>[InputFormats.amount],
    onEdited: _edited,
    onChanged: (String _) => _announce(),
  );
}
