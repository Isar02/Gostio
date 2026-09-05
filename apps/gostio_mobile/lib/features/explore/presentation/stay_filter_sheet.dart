import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/date_range.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/date_range_picker.dart';
import '../../../core/widgets/discard_guard.dart';
import '../data/filter_options.dart';
import '../data/stay_filters.dart';
import 'filter_amounts.dart';
import 'filter_choices.dart';
import 'filter_options_notifier.dart';
import 'filter_sheet.dart';

// Everything the stay catalogue can be narrowed by, in one sheet. Nothing here
// reaches the server until the sheet is closed on its button: a reader picking
// a city, then dates, then a price would otherwise be searching three times
// for one answer, and the recommender would hear all three.
abstract final class StayFilterSheet {
  static Future<StayFilters?> show(
    BuildContext context, {
    required StayFilters current,
    required FilterOptionsNotifier options,
  }) => AppSheet.show<StayFilters>(
    context,
    title: 'Filter stays',
    isScrollable: false,
    // A sheet is a route of its own, so what it draws is handed to it rather
    // than read out of the tree the screen behind it was composed in. The
    // choices are watched because they may still be on their way.
    builder: (BuildContext context) => ListenableBuilder(
      listenable: options,
      builder: (BuildContext context, Widget? _) => _StayFilterForm(
        current: current,
        options: options.options,
        optionsFailure: options.failureMessage,
      ),
    ),
  );
}

class _StayFilterForm extends StatefulWidget {
  const _StayFilterForm({
    required this.current,
    required this.options,
    this.optionsFailure,
  });

  final StayFilters current;
  final FilterOptions options;
  final String? optionsFailure;

  @override
  State<_StayFilterForm> createState() => _StayFilterFormState();
}

class _StayFilterFormState extends State<_StayFilterForm> {
  late StayFilters _draft = widget.current;

  // Clearing empties two typed fields, which hold their own text. Rebuilding
  // them under a new key is what puts that text back in step with the draft.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final FilterOptions options = widget.options;

    // Nothing here reaches the results until the sheet is closed on its
    // button, so leaving it any other way loses what was chosen. That is worth
    // one question and no more than one: the calendar over this sheet hands
    // its answer here rather than holding one of its own.
    return DiscardGuard(
      hasInput: _draft != widget.current,
      title: 'Leave these filters?',
      message: 'What you chose here will not be applied.',
      child: FilterSheetLayout(
        notice: widget.optionsFailure,
        onApply: () => Navigator.of(context).pop(_draft),
        onClear: _draft.isFiltered ? _clear : null,
        children: <Widget>[
          FilterGroup(
            label: 'Dates',
            detail: 'The nights you need free',
            child: FilterOpener(
              placeholder: 'Any dates',
              value: _nightsLabel,
              onOpen: _chooseNights,
              onClear: () => _keep(_draft.replacing(nights: null)),
            ),
          ),
          FilterGroup(
            label: 'Guests',
            detail: 'Stays that sleep at least this many',
            child: CountPicker(
              value: _draft.guests,
              noun: 'guest',
              onChanged: (int? guests) =>
                  _keep(_draft.replacing(guests: guests)),
            ),
          ),
          FilterGroup(
            label: 'Price per night',
            child: PriceBand(
              key: ValueKey<int>(_generation),
              least: _draft.minPrice,
              most: _draft.maxPrice,
              onChanged: (double? least, double? most) =>
                  _keep(_draft.replacing(minPrice: least, maxPrice: most)),
            ),
          ),
          if (options.cities.isNotEmpty)
            FilterGroup(
              label: 'City',
              child: PickOne<LookupItem>(
                options: options.cities,
                nameOf: (LookupItem city) => city.name,
                selected: _draft.city,
                onChosen: (LookupItem? city) =>
                    _keep(_draft.replacing(city: city)),
              ),
            ),
          if (options.stayTypes.isNotEmpty)
            FilterGroup(
              label: 'Type',
              child: PickOne<LookupItem>(
                options: options.stayTypes,
                nameOf: (LookupItem type) => type.name,
                selected: _draft.type,
                onChosen: (LookupItem? type) =>
                    _keep(_draft.replacing(type: type)),
              ),
            ),
          if (options.stayCategories.isNotEmpty)
            FilterGroup(
              label: 'Category',
              child: PickOne<LookupItem>(
                options: options.stayCategories,
                nameOf: (LookupItem category) => category.name,
                selected: _draft.category,
                onChosen: (LookupItem? category) =>
                    _keep(_draft.replacing(category: category)),
              ),
            ),
          if (options.amenities.isNotEmpty)
            FilterGroup(
              label: 'Amenities',
              detail: 'Only stays offering all of these',
              child: PickMany<LookupItem>(
                options: options.amenities,
                nameOf: (LookupItem amenity) => amenity.name,
                chosen: _draft.amenities,
                onChanged: (List<LookupItem> amenities) =>
                    _keep(_draft.replacing(amenities: amenities)),
              ),
            ),
        ],
      ),
    );
  }

  String? get _nightsLabel {
    final DateRange? nights = _draft.nights;

    return nights == null
        ? null
        : '${AppDates.day(nights.from)} to ${AppDates.day(nights.to)}';
  }

  void _keep(StayFilters draft) => setState(() => _draft = draft);

  // What was typed in the field is kept: clearing the filters is not the same
  // gesture as abandoning the search that opened the sheet.
  void _clear() => setState(() {
    _draft = _draft.cleared;
    _generation++;
  });

  Future<void> _chooseNights() async {
    final DateRange? chosen = await DateRangePicker.show(
      context,
      selected: _draft.nights,
    );

    if (chosen != null) {
      _keep(_draft.replacing(nights: chosen));
    }
  }
}
