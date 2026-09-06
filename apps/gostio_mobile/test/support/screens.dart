import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/theme/app_theme.dart';
import 'package:gostio_mobile/features/auth/data/auth_repository.dart';
import 'package:gostio_mobile/features/booking/data/booking_repository.dart';
import 'package:gostio_mobile/features/explore/data/catalogue_repository.dart';
import 'package:gostio_mobile/features/explore/data/filter_options_repository.dart';
import 'package:gostio_mobile/features/listing/data/listing_repository.dart';
import 'package:gostio_mobile/features/listing/presentation/favorite_edits.dart';
import 'package:gostio_mobile/features/notifications/data/notifications_repository.dart';
import 'package:gostio_mobile/features/notifications/presentation/unread_notices.dart';
import 'package:gostio_mobile/features/payment/data/card_sheet.dart';
import 'package:gostio_mobile/features/payment/data/payment_repository.dart';
import 'package:gostio_mobile/features/reviews/data/reviews_repository.dart';
import 'package:gostio_mobile/features/trips/data/trips_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

ApiClient testClient() => ApiClient(baseUrl: Uri.parse('http://10.0.2.2:5000'));

Session signedOutSession() => Session(testClient());

// One screen under the providers the client composes above it, drawn in the
// theme it is actually read in.
Widget underTest(
  Widget screen, {
  required AuthRepository auth,
  Session? session,
  ApiClient? client,
  GlobalKey<NavigatorState>? navigator,
  NotificationsRepository? notifications,
  CatalogueRepository? catalogue,
  FilterOptionsRepository? filterOptions,
  ListingRepository? listings,
  BookingRepository? bookings,
  PaymentRepository? payments,
  CardSheet? cardSheet,
  TripsRepository? trips,
  ReviewsRepository? reviews,
  FavoriteEdits? favorites,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    // Every picture is fetched through the client, so a screen holding a card
    // or a gallery is composed over one whether or not it has an address to
    // ask for yet.
    Provider<ApiClient>.value(value: client ?? testClient()),
    ChangeNotifierProvider<Session>.value(value: session ?? signedOutSession()),
    Provider<AuthRepository>.value(value: auth),
    // The catalogues are composed above the shell rather than inside the tab
    // that reads them, so a test draws that tab over rows it wrote itself.
    if (catalogue case final CatalogueRepository repository)
      Provider<CatalogueRepository>.value(value: repository),
    if (filterOptions case final FilterOptionsRepository repository)
      Provider<FilterOptionsRepository>.value(value: repository),
    if (listings case final ListingRepository repository)
      Provider<ListingRepository>.value(value: repository),
    if (bookings case final BookingRepository repository)
      Provider<BookingRepository>.value(value: repository),
    if (payments case final PaymentRepository repository)
      Provider<PaymentRepository>.value(value: repository),
    if (cardSheet case final CardSheet sheet)
      Provider<CardSheet>.value(value: sheet),
    if (trips case final TripsRepository repository)
      Provider<TripsRepository>.value(value: repository),
    if (reviews case final ReviewsRepository repository)
      Provider<ReviewsRepository>.value(value: repository),
    // Every card draws a heart, so what has been saved is composed above the
    // whole client rather than beside the screens that write it.
    ChangeNotifierProvider<FavoriteEdits>.value(
      value: favorites ?? FavoriteEdits(),
    ),
    // A screen that draws no bell is composed without one, so nothing polls
    // behind a test that is not about the count. The count is created by the
    // provider rather than handed to it, because what created it is what ends
    // its poll when the tree goes.
    if (notifications
        case final NotificationsRepository repository) ...<SingleChildWidget>[
      Provider<NotificationsRepository>.value(value: repository),
      ChangeNotifierProvider<UnreadNotices>(
        create: (BuildContext context) =>
            UnreadNotices(context.read<NotificationsRepository>()),
      ),
    ],
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    navigatorKey: navigator,
    home: screen,
  ),
);

// A screen the client only ever reaches by pushing it is drawn over something
// here too, so the arrow in its bar and the gesture behind it both exist.
Future<GlobalKey<NavigatorState>> pushOnto(
  WidgetTester tester,
  Widget screen, {
  required AuthRepository auth,
  Session? session,
  ListingRepository? listings,
  BookingRepository? bookings,
  PaymentRepository? payments,
  CardSheet? cardSheet,
  TripsRepository? trips,
  ReviewsRepository? reviews,
}) async {
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  await tester.pumpWidget(
    underTest(
      const Scaffold(),
      auth: auth,
      session: session,
      navigator: navigator,
      listings: listings,
      bookings: bookings,
      payments: payments,
      cardSheet: cardSheet,
      trips: trips,
      reviews: reviews,
    ),
  );

  unawaited(
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    ),
  );

  await tester.pumpAndSettle();

  return navigator;
}
