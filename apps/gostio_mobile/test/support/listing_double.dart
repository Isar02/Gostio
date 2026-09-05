import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/listing/data/listing_detail.dart';
import 'package:gostio_mobile/features/listing/data/listing_repository.dart';

import 'listing_fixture.dart';

// One listing answered without a socket. Every call records what it was asked
// for, so a test says what it expects the screen to have sent rather than
// reading the request back off the screen.
class ListingDouble implements ListingRepository {
  ListingDouble({
    ListingDetail? detail,
    this.photos = const <ListingPhoto>[],
    this.amenities = const <LookupItem>[],
    this.reviewRows = const <Review>[],
    this.nights = const <StayCalendarDay>[],
    this.failure,
    this.favoriteFailure,
    this.calendarFailure,
    this.holdsTheCall = false,
  }) : detail = detail ?? StayDetail(stay());

  final ListingDetail detail;
  final List<ListingPhoto> photos;
  final List<LookupItem> amenities;
  final List<Review> reviewRows;
  final List<StayCalendarDay> nights;
  final ApiException? failure;
  final ApiException? favoriteFailure;
  final ApiException? calendarFailure;
  final bool holdsTheCall;

  final List<ListingAddress> reads = <ListingAddress>[];
  final List<ListingAddress> saved = <ListingAddress>[];
  final List<ListingAddress> unsaved = <ListingAddress>[];
  final List<DateTime> monthsAsked = <DateTime>[];
  final List<int> reviewPagesAsked = <int>[];

  final Completer<void> _answer = Completer<void>();

  void answer() => _answer.complete();

  @override
  Future<ListingOverview> read(ListingAddress address) async {
    await _held();
    reads.add(address);

    if (failure case final ApiException refused) {
      throw refused;
    }

    return ListingOverview(
      detail: detail,
      photos: photos,
      amenities: amenities,
    );
  }

  @override
  Future<List<StayCalendarDay>> calendar(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    monthsAsked.add(from);

    if (calendarFailure case final ApiException refused) {
      throw refused;
    }

    return <StayCalendarDay>[
      for (final StayCalendarDay night in nights)
        if (!night.date.isBefore(from) && !night.date.isAfter(to)) night,
    ];
  }

  @override
  Future<PagedResult<Review>> reviews(
    ListingAddress address, {
    required int page,
    required int pageSize,
  }) async {
    reviewPagesAsked.add(page);

    final int from = ((page - 1) * pageSize).clamp(0, reviewRows.length);
    final int to = (from + pageSize).clamp(0, reviewRows.length);

    return PagedResult<Review>(
      items: reviewRows.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: reviewRows.length,
    );
  }

  @override
  Future<void> addFavorite(ListingAddress address) async {
    if (favoriteFailure case final ApiException refused) {
      throw refused;
    }

    saved.add(address);
  }

  @override
  Future<void> removeFavorite(ListingAddress address) async {
    if (favoriteFailure case final ApiException refused) {
      throw refused;
    }

    unsaved.add(address);
  }

  Future<void> _held() => holdsTheCall ? _answer.future : Future<void>.value();
}
