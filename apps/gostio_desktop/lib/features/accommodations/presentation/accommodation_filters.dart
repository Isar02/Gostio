import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/multi_select_field.dart';
import '../../listings/presentation/listing_status.dart';
import '../data/accommodation_query.dart';
import 'accommodation_filter_options.dart';

class AccommodationFilters extends StatefulWidget {
  const AccommodationFilters({
    required this.options,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    this.trailing,
    super.key,
  });

  final AccommodationFilterOptions options;

  // The query the rows on screen were fetched under, which is what these
  // controls have to describe once a request has settled.
  final AccommodationQuery applied;

  final bool isLoading;
  final ValueChanged<AccommodationQuery> onChanged;
  final Widget? trailing;

  @override
  State<AccommodationFilters> createState() => _AccommodationFiltersState();
}

class _AccommodationFiltersState extends State<AccommodationFilters> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _minPrice = TextEditingController();
  final TextEditingController _maxPrice = TextEditingController();
  final TextEditingController _minGuests = TextEditingController();

  LookupItem? _city;
  LookupItem? _type;
  LookupItem? _category;
  Set<LookupItem> _amenities = <LookupItem>{};
  ListingStatus _status = ListingStatus.any;

  AccommodationQuery _announced = const AccommodationQuery();
  int _editRevision = 0;
  int _announcedRevision = 0;

  // A request that did not take leaves the rows on the query before it, so the
  // controls go back to that one rather than labelling old rows with a filter
  // that never loaded.
  @override
  void didUpdateWidget(AccommodationFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading &&
        widget.applied != _announced &&
        _editRevision == _announcedRevision) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(AccommodationQuery query) {
    _title.text = query.title ?? '';
    _minPrice.text = _written(query.minPrice);
    _maxPrice.text = _written(query.maxPrice);
    _minGuests.text = _written(query.minGuests);
    _city = _itemFor(widget.options.cities, query.cityId);
    _type = _itemFor(widget.options.types, query.accommodationTypeId);
    _category = _itemFor(
      widget.options.categories,
      query.accommodationCategoryId,
    );
    _amenities = widget.options.amenities
        .where((LookupItem amenity) => query.amenityIds.contains(amenity.id))
        .toSet();
    _status = ListingStatus.values.firstWhere(
      (ListingStatus status) => status.isActive == query.isActive,
    );
    _announced = query;
    _announcedRevision = _editRevision;
  }

  void _announce() {
    _announced = AccommodationQuery(
      title: _title.text,
      cityId: _city?.id,
      accommodationTypeId: _type?.id,
      accommodationCategoryId: _category?.id,
      minPrice: double.tryParse(_minPrice.text),
      maxPrice: double.tryParse(_maxPrice.text),
      minGuests: int.tryParse(_minGuests.text),
      amenityIds: _amenities
          .map((LookupItem amenity) => amenity.id)
          .toList(growable: false),
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
    _minGuests.clear();
    _city = null;
    _type = null;
    _category = null;
    _amenities = <LookupItem>{};
    _status = ListingStatus.any;
  });

  @override
  void dispose() {
    _title.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    _minGuests.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccommodationFilterOptions options = widget.options;

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
          label: 'Type',
          child: _lookup(
            value: _type,
            values: options.types,
            onChanged: (LookupItem? type) => _change(() => _type = type),
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
          label: 'Guests at least',
          width: AppSizes.filterFieldNarrow,
          child: FilterTextField(
            controller: _minGuests,
            formatters: <TextInputFormatter>[InputFormats.whole],
            onEdited: _edited,
            onChanged: (String _) => _announce(),
          ),
        ),
        FilterField(
          label: 'Amenities',
          child: MultiSelectField<LookupItem>(
            values: options.amenities,
            selected: _amenities,
            labels: (LookupItem amenity) => amenity.name,
            onChanged: (Set<LookupItem> chosen) =>
                _change(() => _amenities = chosen),
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
