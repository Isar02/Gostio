import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_settings.dart';
import '../core/push/push_messaging.dart';
import '../features/booking/data/booking_repository.dart';
import '../features/explore/data/catalogue_repository.dart';
import '../features/explore/data/filter_options_repository.dart';
import '../features/favorites/data/favorites_repository.dart';
import '../features/host_application/data/host_application_repository.dart';
import '../features/listing/data/listing_repository.dart';
import '../features/listing/presentation/favorite_edits.dart';
import '../features/messages/data/chat_hub.dart';
import '../features/messages/data/conversations_repository.dart';
import '../features/messages/data/messages_repository.dart';
import '../features/messages/data/signalr_chat_hub.dart';
import '../features/messages/presentation/chat_nudge.dart';
import '../features/messages/presentation/unread_messages.dart';
import '../features/news/data/news_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/data/push_registration.dart';
import '../features/notifications/presentation/unread_notices.dart';
import '../features/payment/data/card_sheet.dart';
import '../features/payment/data/payment_repository.dart';
import '../features/payment/data/stripe_card_sheet.dart';
import '../features/profile/data/image_picker_pictures.dart';
import '../features/profile/data/picture_source.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/presentation/profile_write_lock.dart';
import '../features/recommendations/data/recommendations_repository.dart';
import '../features/reviews/data/reviews_repository.dart';
import '../features/trips/data/trips_repository.dart';
import 'shell/app_shell.dart';

// What only an account has. The unread count is created here rather than above
// the session so that it begins when a session does and ends with it: nothing
// asks the server what an account that is not signed in has waiting.
//
// The repositories a tab reads through are made here for the same reason: a
// screen composes the state it holds, and what that state reads is handed to
// it, so a test draws the screen over an answer instead of over a socket.
class SignedInApp extends StatelessWidget {
  const SignedInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<CatalogueRepository>(
          create: (BuildContext context) =>
              CatalogueRepository(context.read<ApiClient>()),
        ),
        Provider<FilterOptionsRepository>(
          create: (BuildContext context) =>
              FilterOptionsRepository(context.read<ApiClient>()),
        ),
        Provider<ListingRepository>(
          create: (BuildContext context) =>
              ListingRepository(context.read<ApiClient>()),
        ),
        Provider<BookingRepository>(
          create: (BuildContext context) =>
              BookingRepository(context.read<ApiClient>()),
        ),
        // What has been saved and unsaved since a list was read. It sits above
        // the tabs because the list that shows a heart and the screen that
        // turns one are in different places.
        ChangeNotifierProvider<FavoriteEdits>(
          create: (BuildContext context) => FavoriteEdits(),
        ),
        Provider<FavoritesRepository>(
          create: (BuildContext context) =>
              FavoritesRepository(context.read<ApiClient>()),
        ),
        Provider<PaymentRepository>(
          create: (BuildContext context) =>
              PaymentRepository(context.read<ApiClient>()),
        ),
        // The card sheet is composed here like a repository, because that is
        // what it is: the one thing on this client that talks to the card
        // processor. A screen is handed it rather than reaching for it, so a
        // test draws paying without a processor behind it.
        Provider<CardSheet>(
          create: (BuildContext context) => const StripeCardSheet(),
        ),
        Provider<ProfileRepository>(
          create: (BuildContext context) =>
              ProfileRepository(context.read<ApiClient>()),
        ),
        // The camera and the gallery are composed here like a repository,
        // because that is what they are to this client: the one thing on it
        // that reads a file off the phone.
        Provider<PictureSource>(
          create: (BuildContext context) => ImagePickerPictures(),
        ),
        // The three writes an account makes about itself are on three routes
        // rather than on one screen, so what holds them apart is above all
        // three and lives as long as the session does.
        ChangeNotifierProvider<ProfileWriteLock>(
          create: (BuildContext context) => ProfileWriteLock(),
        ),
        Provider<HostApplicationRepository>(
          create: (BuildContext context) =>
              HostApplicationRepository(context.read<ApiClient>()),
        ),
        Provider<TripsRepository>(
          create: (BuildContext context) =>
              TripsRepository(context.read<ApiClient>()),
        ),
        Provider<ReviewsRepository>(
          create: (BuildContext context) =>
              ReviewsRepository(context.read<ApiClient>()),
        ),
        Provider<RecommendationsRepository>(
          create: (BuildContext context) =>
              RecommendationsRepository(context.read<ApiClient>()),
        ),
        Provider<NotificationsRepository>(
          create: (BuildContext context) =>
              NotificationsRepository(context.read<ApiClient>()),
        ),
        // Where this device says it can be reached, made with the session and
        // given up with it. It is asked for as the client opens rather than
        // when something first reads it: a registration nobody has read is
        // still the one a push is delivered to.
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
          dispose: (BuildContext context, PushRegistration registration) =>
              unawaited(registration.close()),
        ),
        ChangeNotifierProvider<UnreadNotices>(
          create: (BuildContext context) => UnreadNotices(
            context.read<NotificationsRepository>(),
            messaging: context.read<PushMessaging>(),
          ),
        ),
        Provider<NewsRepository>(
          create: (BuildContext context) =>
              NewsRepository(context.read<ApiClient>()),
        ),
        Provider<ConversationsRepository>(
          create: (BuildContext context) =>
              ConversationsRepository(context.read<ApiClient>()),
        ),
        Provider<MessagesRepository>(
          create: (BuildContext context) =>
              MessagesRepository(context.read<ApiClient>()),
        ),
        // The one socket this client opens, made with the session and given up
        // with it: a thread listens through it and nothing else does.
        Provider<ChatHub>(
          create: (BuildContext context) => SignalRChatHub(
            context.read<ApiClient>(),
            baseUrl: context.read<AppSettings>().apiBaseUrl,
          ),
          dispose: (BuildContext context, ChatHub hub) => hub.close(),
        ),
        // What is waiting in the inbox is drawn over the tab from every screen
        // in the client, so it is counted here beside the bell's count and for
        // the same reason.
        Provider<ChatNudge>(
          create: (BuildContext context) => ChatNudge(context.read<ChatHub>()),
          dispose: (BuildContext context, ChatNudge nudge) => nudge.dispose(),
        ),
        ChangeNotifierProvider<UnreadMessages>(
          create: (BuildContext context) => UnreadMessages(
            context.read<MessagesRepository>(),
            nudge: context.read<ChatNudge>(),
          ),
        ),
      ],
      child: const AppShell(),
    );
  }
}
