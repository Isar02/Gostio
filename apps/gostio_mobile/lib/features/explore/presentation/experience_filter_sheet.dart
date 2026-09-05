import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/day_window.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/day_window_picker.dart';
import '../../../core/widgets/discard_guard.dart';
import '../data/experience_filters.dart';
import '../data/filter_options.dart';
import 'filter_amounts.dart';
import 'filter_choices.dart';
import 'filter_options_notifier.dart';
import 'filter_sheet.dart';

// Everything the experience catalogue can be narrowed by. It reads like the
// stay sheet and asks different questions: a term is an afternoon with places
// left on it rather than a run of nights nobody else holds.
abstract final class ExperienceFilterSheet {
  // Bands rather than a slider, because a reader asking for something to do
  // this afternoon is choosing between a morning and a day out, not between
  // 195 minutes and 200.
  static const List<int> lengths = <int>[120, 180, 240, 360];

  static Future<ExperienceFilters?> show(
    BuildContext context, {
    required ExperienceFilters current,
    required FilterOptionsNotifier options,
  }) => AppSheet.show<ExperienceFilters>(
    context,
    title: 'Filter experiences',
    isScrollable: false,
    // A sheet is a route of its own, so what it draws is handed to it rather
    // than read out of the tree the screen behind it was composed in. The
    // choices are watched because they may still be on their way.
    builder: (BuildContext context) => ListenableBuilder(
      listenable: options,
      builder: (BuildContext context, Widget? _) => _ExperienceFilterForm(
        current: current,
        options: options.options,
        optionsFailure: options.failureMessage,
      ),
    ),
  );
}

class _ExperienceFilterForm extends StatefulWidget {
  const _ExperienceFilterForm({
    required this.current,
    required this.options,
    this.optionsFailure,
  });

  final ExperienceFilters current;
  final FilterOptions options;
  final String? optionsFailure;

  @override
  State<_ExperienceFilterForm> createState() => _ExperienceFilterFormState();
}

class _ExperienceFilterFormState extends State<_ExperienceFilterForm> {
  late ExperienceFilters _draft = widget.current;
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
            label: 'Days',
            detail: 'The days you are free',
            child: FilterOpener(
              placeholder: 'Any day',
              value: _daysLabel,
              onOpen: _chooseDays,
              onClear: () => _keep(_draft.replacing(days: null)),
            ),
          ),
          FilterGroup(
            label: 'Places',
            detail: 'Terms with at least this many left',
            child: CountPicker(
              value: _draft.places,
              noun: 'place',
              onChanged: (int? places) =>
                  _keep(_draft.replacing(places: places)),
            ),
          ),
          FilterGroup(
            label: 'Price per person',
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
          if (options.experienceCategories.isNotEmpty)
            FilterGroup(
              label: 'Category',
              child: PickOne<LookupItem>(
                options: options.experienceCategories,
                nameOf: (LookupItem category) => category.name,
                selected: _draft.category,
                onChosen: (LookupItem? category) =>
                    _keep(_draft.replacing(category: category)),
              ),
            ),
          FilterGroup(
            label: 'Length',
            child: PickOne<int>(
              options: ExperienceFilterSheet.lengths,
              nameOf: (int minutes) => 'Up to ${AppDurations.inWords(minutes)}',
              selected: _draft.longestMinutes,
              onChosen: (int? minutes) =>
                  _keep(_draft.replacing(longestMinutes: minutes)),
            ),
          ),
        ],
      ),
    );
  }

  String? get _daysLabel {
    final DayWindow? days = _draft.days;

    if (days == null) {
      return null;
    }

    return days.isOneDay
        ? AppDates.day(days.from)
        : '${AppDates.day(days.from)} to ${AppDates.day(days.to)}';
  }

  void _keep(ExperienceFilters draft) => setState(() => _draft = draft);

  void _clear() => setState(() {
    _draft = _draft.cleared;
    _generation++;
  });

  Future<void> _chooseDays() async {
    final DayWindow? chosen = await DayWindowPicker.show(
      context,
      selected: _draft.days,
    );

    if (chosen != null) {
      _keep(_draft.replacing(days: chosen));
    }
  }
}
