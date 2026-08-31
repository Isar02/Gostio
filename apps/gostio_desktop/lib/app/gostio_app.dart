import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_settings.dart';
import '../core/network/api_client.dart';
import '../core/session/session.dart';
import '../core/theme/app_theme.dart';
import '../features/accommodations/data/accommodations_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/reference/data/reference_repository.dart';
import 'shell/shell_scaffold.dart';

class GostioApp extends StatelessWidget {
  const GostioApp({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
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
        Provider<NotificationsRepository>(
          create: (BuildContext context) =>
              NotificationsRepository(context.read<ApiClient>()),
        ),
        Provider<ReferenceRepository>(
          create: (BuildContext context) =>
              ReferenceRepository(context.read<ApiClient>()),
        ),
        Provider<AccommodationsRepository>(
          create: (BuildContext context) =>
              AccommodationsRepository(context.read<ApiClient>()),
        ),
      ],
      child: MaterialApp(
        title: 'Gostio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Consumer<Session>(
          builder: (BuildContext context, Session session, Widget? child) =>
              session.isSignedIn ? const ShellScaffold() : const SignInScreen(),
        ),
      ),
    );
  }
}
