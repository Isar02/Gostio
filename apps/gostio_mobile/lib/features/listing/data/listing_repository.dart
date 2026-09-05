import 'package:gostio_core/gostio_core.dart';

import 'listing_detail.dart';

// One listing and everything that hangs off it. The row is a route and so is
// every collection under it, because a list carries what it needs to be drawn
// and nothing else: the pictures, the amenities, the calendar and the reviews
// are all asked for separately.
class ListingRepository {
  const ListingRepository(this._client);

  final ApiClient _client;

  // The row and its collections do not depend on each other, so asking for
  // them one after another would spend three round trips on one screen.
  Future<ListingOverview> read(ListingAddress address) async {
    final Future<ListingDetail> detail = _detail(address);
    final Future<List<ListingPhoto>> photos = _photos(address);
    final Future<List<LookupItem>> amenities = _amenities(address);

    await Future.wait(<Future<void>>[detail, photos, amenities]);

    return ListingOverview(
      detail: await detail,
      photos: await photos,
      amenities: await amenities,
    );
  }

  // What a guest may still book over a window, and what each night costs. The
  // API bounds the window rather than paging it, so it answers a document.
  //
  // Only a stay has one, so this takes the accommodation's own id rather than
  // a `ListingAddress`: an address carries either kind, and half of what it
  // could carry has no calendar to ask for.
  Future<List<StayCalendarDay>> calendar(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final ListingAddress listing = ListingAddress(
      ListingKind.accommodation,
      accommodationId,
    );

    final List<dynamic> days = await _client.getList(
      '${listing.path}/calendar',
      query: <String, dynamic>{
        'from': CalendarDays.write(from),
        'to': CalendarDays.write(to),
      },
    );

    return <StayCalendarDay>[
      for (final dynamic day in days) StayCalendarDay.fromJson(day as JsonMap),
    ];
  }

  Future<PagedResult<Review>> reviews(
    ListingAddress address, {
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '/reviews',
      query: <String, dynamic>{
        switch (address.kind) {
          ListingKind.accommodation => 'accommodationId',
          ListingKind.experience => 'experienceId',
        }: address.id,
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Review>.fromJson(
      body,
      (Object? item) => Review.fromJson(item! as JsonMap),
    );
  }

  // Saving is a write against the listing rather than a row the client builds,
  // so what comes back is the server's own and nothing here reads it.
  Future<void> addFavorite(ListingAddress address) =>
      _client.putNoContent(address.favorite);

  Future<void> removeFavorite(ListingAddress address) =>
      _client.delete(address.favorite);

  Future<ListingDetail> _detail(ListingAddress address) async {
    final JsonMap body = await _client.get(address.path);

    return switch (address.kind) {
      ListingKind.accommodation => StayDetail(Accommodation.fromJson(body)),
      ListingKind.experience => ExperienceDetail(Experience.fromJson(body)),
    };
  }

  // A gallery is the whole set rather than its first page, and the API caps a
  // page at a hundred rows.
  Future<List<ListingPhoto>> _photos(ListingAddress address) =>
      readEveryPage<ListingPhoto>(
        _client,
        address.photos,
        read: ListingPhoto.fromJson,
      );

  // Only a stay has amenities. A term answers with none rather than being
  // asked for a route it does not have.
  Future<List<LookupItem>> _amenities(ListingAddress address) =>
      switch (address.kind) {
        ListingKind.accommodation => readEveryPage<LookupItem>(
          _client,
          '${address.path}/amenities',
          read: LookupItem.fromJson,
        ),
        ListingKind.experience => Future<List<LookupItem>>.value(
          const <LookupItem>[],
        ),
      };
}
