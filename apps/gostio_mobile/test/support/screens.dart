import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/push/push_messaging.dart';
import 'package:gostio_mobile/core/theme/app_theme.dart';
import 'package:gostio_mobile/features/auth/data/auth_repository.dart';
import 'package:gostio_mobile/features/booking/data/booking_repository.dart';
import 'package:gostio_mobile/features/explore/data/catalogue_repository.dart';
import 'package:gostio_mobile/features/explore/data/filter_options_repository.dart';
import 'package:gostio_mobile/features/favorites/data/favorites_repository.dart';
import 'package:gostio_mobile/features/host_application/data/host_application_repository.dart';
import 'package:gostio_mobile/features/listing/data/listing_repository.dart';
import 'package:gostio_mobile/features/listing/presentation/favorite_edits.dart';
import 'package:gostio_mobile/features/messages/data/chat_hub.dart';
import 'package:gostio_mobile/features/messages/data/conversations_repository.dart';
import 'package:gostio_mobile/features/messages/data/messages_repository.dart';
import 'package:gostio_mobile/features/messages/presentation/chat_nudge.dart';
import 'package:gostio_mobile/features/messages/presentation/unread_messages.dart';
import 'package:gostio_mobile/features/news/data/news_repository.dart';
import 'package:gostio_mobile/features/notifications/data/notifications_repository.dart';
import 'package:gostio_mobile/features/notifications/data/push_registration.dart';
import 'package:gostio_mobile/features/notifications/presentation/unread_notices.dart';
import 'package:gostio_mobile/features/payment/data/card_sheet.dart';
import 'package:gostio_mobile/features/payment/data/payment_repository.dart';
import 'package:gostio_mobile/features/profile/data/picture_source.dart';
import 'package:gostio_mobile/features/profile/data/profile_repository.dart';
import 'package:gostio_mobile/features/profile/presentation/profile_write_lock.dart';
import 'package:gostio_mobile/features/recommendations/data/recommendations_repository.dart';
import 'package:gostio_mobile/features/reviews/data/reviews_repository.dart';
import 'package:gostio_mobile/features/trips/data/trips_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'picture_double.dart';
import 'profile_double.dart';
import 'push_double.dart';

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
  NewsRepository? news,
  PushMessaging? messaging,
  CatalogueRepository? catalogue,
  FilterOptionsRepository? filterOptions,
  ListingRepository? listings,
  BookingRepository? bookings,
  PaymentRepository? payments,
  CardSheet? cardSheet,
  TripsRepository? trips,
  ReviewsRepository? reviews,
  FavoritesRepository? saved,
  RecommendationsRepository? suggestions,
  ConversationsRepository? conversations,
  MessagesRepository? messages,
  ChatHub? chat,
  FavoriteEdits? favorites,
  ProfileRepository? profile,
  PictureSource? pictures,
  ProfileWriteLock? profileWrites,
  HostApplicationRepository? hostApplications,
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
    // The account is somebody signed in rather than a screen's subject, so
    // what reads and writes it is composed wherever the profile can be
    // reached. Nothing is behind either double until a test puts it there.
    Provider<ProfileRepository>.value(value: profile ?? ProfileDouble()),
    Provider<PictureSource>.value(value: pictures ?? PictureSourceDouble()),
    ChangeNotifierProvider<ProfileWriteLock>.value(
      value: profileWrites ?? ProfileWriteLock(),
    ),
    if (hostApplications case final HostApplicationRepository repository)
      Provider<HostApplicationRepository>.value(value: repository),
    if (reviews case final ReviewsRepository repository)
      Provider<ReviewsRepository>.value(value: repository),
    if (saved case final FavoritesRepository repository)
      Provider<FavoritesRepository>.value(value: repository),
    if (suggestions case final RecommendationsRepository repository)
      Provider<RecommendationsRepository>.value(value: repository),
    // Every card draws a heart, so what has been saved is composed above the
    // whole client rather than beside the screens that write it.
    ChangeNotifierProvider<FavoriteEdits>.value(
      value: favorites ?? FavoriteEdits(),
    ),
    // A screen that draws no bell is composed without one, so nothing polls
    // behind a test that is not about the count. The count is created by the
    // provider rather than handed to it, because what created it is what ends
    // its poll when the tree goes.
    // The phone's delivery service is device machinery rather than a screen's,
    // so one is always composed. Nothing is behind the double: a test that is
    // not about push simply never makes it deliver anything.
    Provider<PushMessaging>.value(value: messaging ?? PushMessagingDouble()),
    if (notifications
        case final NotificationsRepository repository) ...<SingleChildWidget>[
      Provider<NotificationsRepository>.value(value: repository),
      // Started as the client starts it, so a test of signing out is a test of
      // a device that was actually registered.
      Provider<PushRegistration>(
        lazy: false,
        create: (BuildContext context) {
          final PushRegistration registration = PushRegistration(
            context.read<NotificationsRepository>(),
            context.read<PushMessaging>(),
          );
          unawaited(registration.start());

          return registration;
        },
      ),
      ChangeNotifierProvider<UnreadNotices>(
        create: (BuildContext context) => UnreadNotices(
          context.read<NotificationsRepository>(),
          messaging: context.read<PushMessaging>(),
        ),
      ),
    ],
    if (news case final NewsRepository repository)
      Provider<NewsRepository>.value(value: repository),
    if (conversations case final ConversationsRepository repository)
      Provider<ConversationsRepository>.value(value: repository),
    // A thread listens through the hub, so one is composed wherever a thread
    // can be opened. Nothing else in the client reaches for it.
    if (chat case final ChatHub hub) ...<SingleChildWidget>[
      Provider<ChatHub>.value(value: hub),
      Provider<ChatNudge>(
        create: (BuildContext context) => ChatNudge(hub),
        dispose: (BuildContext context, ChatNudge nudge) => nudge.dispose(),
      ),
    ],
    // The count over the inbox tab is created by the provider for the same
    // reason the bell's is: what created it is what ends its poll when the
    // tree goes.
    if (messages
        case final MessagesRepository repository) ...<SingleChildWidget>[
      Provider<MessagesRepository>.value(value: repository),
      ChangeNotifierProvider<UnreadMessages>(
        create: (BuildContext context) => UnreadMessages(
          context.read<MessagesRepository>(),
          nudge: context.read<ChatNudge?>(),
        ),
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
  FavoritesRepository? saved,
  ConversationsRepository? conversations,
  MessagesRepository? messages,
  NotificationsRepository? notifications,
  PushMessaging? messaging,
  ChatHub? chat,
  FavoriteEdits? favorites,
  ProfileRepository? profile,
  PictureSource? pictures,
  ProfileWriteLock? profileWrites,
  HostApplicationRepository? hostApplications,
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
      saved: saved,
      conversations: conversations,
      messages: messages,
      notifications: notifications,
      messaging: messaging,
      chat: chat,
      favorites: favorites,
      profile: profile,
      pictures: pictures,
      profileWrites: profileWrites,
      hostApplications: hostApplications,
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
