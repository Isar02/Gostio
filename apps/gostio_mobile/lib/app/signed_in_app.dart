import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../features/notifications/data/notifications_repository.dart';
import '../features/notifications/presentation/unread_notices.dart';
import 'shell/app_shell.dart';

// What only an account has. The unread count is created here rather than above
// the session so that it begins when a session does and ends with it: nothing
// asks the server what an account that is not signed in has waiting.
class SignedInApp extends StatelessWidget {
  const SignedInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
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
