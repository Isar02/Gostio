import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../features/explore/data/catalogue_repository.dart';
import '../features/explore/data/filter_options_repository.dart';
import '../features/listing/data/listing_repository.dart';
import '../features/listing/presentation/favorite_edits.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/presentation/unread_notices.dart';
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
        // What has been saved and unsaved since a list was read. It sits above
        // the tabs because the list that shows a heart and the screen that
        // turns one are in different places.
        ChangeNotifierProvider<FavoriteEdits>(
          create: (BuildContext context) => FavoriteEdits(),
        ),
        Provider<NotificationsRepository>(
          create: (BuildContext context) =>
              NotificationsRepository(context.read<ApiClient>()),
        ),
        ChangeNotifierProvider<UnreadNotices>(
          create: (BuildContext context) =>
              UnreadNotices(context.read<NotificationsRepository>()),
        ),
      ],
      child: const AppShell(),
    );
  }
}
