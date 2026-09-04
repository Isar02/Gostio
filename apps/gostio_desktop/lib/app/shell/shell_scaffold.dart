import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../core/config/app_settings.dart';
import '../../features/messages/data/chat_hub.dart';
import '../../features/messages/data/messages_repository.dart';
import '../../features/messages/data/signalr_chat_hub.dart';
import '../../features/messages/presentation/chat_unread_notifier.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/notifications/presentation/notifications_notifier.dart';
import '../no_workspace_screen.dart';
import 'app_section.dart';
import 'section_host.dart';
import 'shell_navigation.dart';
import 'shell_top_bar.dart';
import 'workspace.dart';
import 'workspace_mode.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );
    if (account == null) {
      return const Scaffold();
    }

    final List<WorkspaceMode> modes = WorkspaceMode.forAccount(account);
    if (modes.isEmpty) {
      return const NoWorkspaceScreen();
    }

    return MultiProvider(
      providers: <SingleChildWidget>[
        // The hub belongs to the signed in session rather than to the
        // application: it authenticates with the token in force when it
        // connects, and signing out has to take the socket with it.
        Provider<ChatHub>(
          create: (BuildContext context) => SignalRChatHub(
            context.read<ApiClient>(),
            baseUrl: context.read<AppSettings>().apiBaseUrl,
          ),
          dispose: (BuildContext context, ChatHub hub) => hub.close(),
        ),
        ChangeNotifierProvider<Workspace>(
          create: (BuildContext context) => Workspace(modes),
        ),
        ChangeNotifierProvider<NotificationsNotifier>(
          create: (BuildContext context) =>
              NotificationsNotifier(context.read<NotificationsRepository>()),
        ),
        ChangeNotifierProvider<ChatUnreadNotifier>(
          create: (BuildContext context) =>
              ChatUnreadNotifier(context.read<MessagesRepository>()),
        ),
      ],
      child: _ShellFrame(account: account),
    );
  }
}

class _ShellFrame extends StatelessWidget {
  const _ShellFrame({required this.account});

  final User account;

  @override
  Widget build(BuildContext context) {
    final WorkspaceMode mode = context.select<Workspace, WorkspaceMode>(
      (Workspace workspace) => workspace.mode,
    );
    final AppSection section = context.select<Workspace, AppSection>(
      (Workspace workspace) => workspace.section,
    );

    return Scaffold(
      body: Row(
        children: <Widget>[
          const ShellNavigation(),
          Expanded(
            child: Column(
              children: <Widget>[
                ShellTopBar(account: account),
                Expanded(
                  child: SectionHost(
                    mode: mode,
                    section: section,
                    account: account,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
