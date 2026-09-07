import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_settings.dart';
import '../core/push/firebase_push_messaging.dart';
import '../core/push/push_messaging.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import 'session_check.dart';
import 'signed_in_app.dart';

class GostioApp extends StatelessWidget {
  const GostioApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppSettings>.value(value: settings),
        Provider<ApiClient>(
          create: (BuildContext context) =>
              ApiClient(baseUrl: settings.apiBaseUrl),
          dispose: (BuildContext context, ApiClient client) => client.close(),
        ),
        ChangeNotifierProvider<Session>(
          create: (BuildContext context) => Session(context.read<ApiClient>()),
        ),
        Provider<AuthRepository>(
          create: (BuildContext context) =>
              AuthRepository(context.read<ApiClient>()),
        ),
        // The phone's own delivery service, which belongs to the device rather
        // than to whoever is signed in on it. What is tied to a session is the
        // registration that says this device is theirs, and that is made with
        // the session further in.
        Provider<PushMessaging>(
          create: (BuildContext context) => FirebasePushMessaging(),
          dispose: (BuildContext context, PushMessaging messaging) =>
              unawaited(messaging.close()),
        ),
      ],
      child: MaterialApp(
        title: 'Gostio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: SessionCheck(
          child: Consumer<Session>(
            builder: (BuildContext context, Session session, Widget? child) =>
                session.isSignedIn ? const SignedInApp() : const SignInScreen(),
          ),
        ),
      ),
    );
  }
}
