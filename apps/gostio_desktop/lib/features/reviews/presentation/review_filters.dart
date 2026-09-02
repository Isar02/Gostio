import 'package:flutter/material.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../listings/data/listing_address.dart';
import '../../listings/data/listing_choice.dart';
import '../data/review_query.dart';
import '../data/review_stars.dart';
import 'review_filter_options.dart';

class ReviewFilters extends StatefulWidget {
  const ReviewFilters({
    required this.options,
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  final ReviewFilterOptions options;

  // The query the rows on screen were fetched under.
  final ReviewQuery applied;

  final bool isLoading;
  final ValueChanged<ReviewQuery> onChanged;

  @override
  State<ReviewFilters> createState() => _ReviewFiltersState();
}

class _ReviewFiltersState extends State<ReviewFilters> {
  ListingChoice? _listing;
  int? _lowest;
  int? _highest;

  ReviewQuery _announced = const ReviewQuery();

  @override
  void initState() {
    super.initState();
    _adopt(widget.applied);
  }

  // A request that did not take leaves the rows on the query before it.
  @override
  void didUpdateWidget(ReviewFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLoading && widget.applied != _announced) {
      setState(() => _adopt(widget.applied));
    }
  }

  void _adopt(ReviewQuery query) {
    _listing = _listingFor(query.listing);
    _lowest = query.lowestRating;
    _highest = query.highestRating;
    _announced = query;
  }

  void _announce() {
    _announced = ReviewQuery(
      listing: _listing?.address,
      lowestRating: _lowest,
      highestRating: _highest,
    );

    widget.onChanged(_announced);
  }

  void _change(VoidCallback edit) {
    setState(edit);
    _announce();
  }

  void _clear() => _change(() {
    _listing = null;
    _lowest = null;
    _highest = null;
  });

  ListingChoice? _listingFor(ListingAddress? address) {
    for (final ListingChoice candidate in widget.options.listings) {
      if (candidate.address == address) {
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
            labels: (ListingChoice reviewed) => reviewed.title,
            onChanged: (ListingChoice? reviewed) =>
                _change(() => _listing = reviewed),
          ),
        ),
        // The two edges bound each other's list.
        FilterField(
          label: 'Rating from',
          width: AppSizes.filterFieldNarrow,
          child: AppOptionalDropdown<int>(
            anyLabel: 'Any',
            value: _lowest,
            values: _upTo(_highest),
            labels: _stars,
            onChanged: (int? lowest) => _change(() => _lowest = lowest),
          ),
        ),
        FilterField(
          label: 'Rating to',
          width: AppSizes.filterFieldNarrow,
          child: AppOptionalDropdown<int>(
            anyLabel: 'Any',
            value: _highest,
            values: _from(_lowest),
            labels: _stars,
            onChanged: (int? highest) => _change(() => _highest = highest),
          ),
        ),
      ],
    );
  }

  static List<int> _upTo(int? highest) => ReviewStars.all
      .where((int star) => highest == null || star <= highest)
      .toList(growable: false);

  static List<int> _from(int? lowest) => ReviewStars.all
      .where((int star) => lowest == null || star >= lowest)
      .toList(growable: false);

  static String _stars(int rating) => rating == 1 ? '1 star' : '$rating stars';
}
