import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import 'session_check.dart';
import 'shell/app_shell.dart';

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
      ],
      child: MaterialApp(
        title: 'Gostio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: SessionCheck(
          child: Consumer<Session>(
            builder: (BuildContext context, Session session, Widget? child) =>
                session.isSignedIn ? const AppShell() : const SignInScreen(),
          ),
        ),
      ),
    );
  }
}
