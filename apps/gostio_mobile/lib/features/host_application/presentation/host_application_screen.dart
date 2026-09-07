import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/host_application_repository.dart';
import 'application_standing.dart';
import 'host_application_notifier.dart';

// The one screen in this client that reads a role. What it reads it for is
// what to say and what to offer; whether an application may be made stays the
// server's answer, and a refusal is drawn beside the button that asked.
//
// The standing is read as the screen opens because it is answered somewhere
// else entirely: an administrator on the other client decides it, and nothing
// tells this one.
class HostApplicationScreen extends StatelessWidget {
  const HostApplicationScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const HostApplicationScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HostApplicationNotifier>(
      create: (BuildContext context) {
        final HostApplicationNotifier applications = HostApplicationNotifier(
          context.read<HostApplicationRepository>(),
        );
        unawaited(applications.read());

        return applications;
      },
      child: const _HostApplication(),
    );
  }
}

class _HostApplication extends StatelessWidget {
  const _HostApplication();

  @override
  Widget build(BuildContext context) {
    final HostApplicationNotifier applications = context
        .watch<HostApplicationNotifier>();
    final bool hosts = context.select<Session, bool>(
      (Session session) => session.isHost,
    );
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(hosts ? 'Hosting on Gostio' : 'Become a host'),
      ),
      body: SafeArea(
        child: _body(context, applications, hosts: hosts, account: account),
      ),
      // Nothing is offered over a standing that has not been read: an account
      // already waiting on an answer would be invited to ask again.
      bottomNavigationBar:
          applications.hasRead &&
              !hosts &&
              ApplicationStanding.canApplyAfter(applications.application)
          ? _ApplyBar(applications)
          : null,
    );
  }

  Widget _body(
    BuildContext context,
    HostApplicationNotifier applications, {
    required bool hosts,
    required User? account,
  }) {
    if (!applications.hasRead) {
      if (applications.readFailureMessage case final String message) {
        return ErrorState(
          message: message,
          traceId: applications.readFailureTraceId,
          onRetry: () => unawaited(applications.read()),
        );
      }

      return const LoadingState(message: 'Reading where you stand.');
    }

    final HostApplication? application = applications.application;
    final _Words words = _Words.of(application, hosts: hosts);

    return RefreshIndicator(
      onRefresh: applications.read,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          // A refused refresh leaves the standing that was read standing. It
          // is older rather than wrong, and throwing it away to show an error
          // would tell the reader less than the row already does.
          if (applications.readFailureMessage case final String message) ...[
            AppNotice(message, tone: Tone.attention),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(words.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          _Paragraph(words.message),
          const SizedBox(height: AppSpacing.xl),
          if (application case final HostApplication application) ...<Widget>[
            _ApplicationCard(application),
            if (words.afterword case final String afterword) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Paragraph(afterword, isFootnote: true),
            ],
          ] else if (account case final User account) ...<Widget>[
            const SectionHeader(
              'What is sent',
              subtitle:
                  'An application carries this account and nothing else. '
                  'There is no form behind the button.',
            ),
            _AccountCard(account),
            const SizedBox(height: AppSpacing.md),
            const _Paragraph(
              'You will be told here and in your notifications when it is '
              'answered.',
              isFootnote: true,
            ),
          ],
          // The sentence sits with the button that earned it rather than at
          // the head of the screen, and it stays after a refusal has taken
          // that button away — which is the refusal that most needs reading.
          if (applications.refusal case final String refusal) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            AppNotice(refusal),
          ],
        ],
      ),
    );
  }
}

// What each standing is called at the top of the screen, written for the
// person waiting rather than for the one deciding.
class _Words {
  const _Words({required this.title, required this.message, this.afterword});

  factory _Words.of(HostApplication? application, {required bool hosts}) {
    if (hosts) {
      return const _Words(
        title: 'You host on Gostio',
        message:
            'Your listings, the dates they are free and the bookings against '
            'them are managed in the Gostio desktop application. This one '
            'stays the client you book on as a guest.',
      );
    }

    if (application == null) {
      return const _Words(
        title: 'Put your own place on Gostio',
        message:
            'A verified host lists an apartment, a house or an experience of '
            'their own, says what it costs and which dates it is free, and '
            'takes bookings against it.',
      );
    }

    return switch (application.standing) {
      HostApplicationStatus.pending => const _Words(
        title: 'Your application is being read',
        message:
            'An administrator answers every application. Nothing on this '
            'account changes until one of them has.',
        afterword:
            'An approval changes what this account may do, so you will be '
            'asked to sign in once more when it arrives.',
      ),
      HostApplicationStatus.rejected => const _Words(
        title: 'Your application was turned down',
        message:
            'Applying again is open to you, and what was said about the last '
            'one is below.',
      ),
      // Approved and still without the role is the moment between the two:
      // hosting was granted to the account rather than to the token this
      // client is holding.
      HostApplicationStatus.approved => const _Words(
        title: 'Your application was approved',
        message:
            'Sign in again to pick up what this account may now do. The token '
            'this phone is holding was issued before the answer.',
      ),
      // A standing this build does not know. What it means is the server's to
      // say, and the row below says it in the server's own word, so nothing
      // here guesses on its behalf.
      null => const _Words(
        title: 'Your application',
        message: 'Where it stands is below, as the server describes it.',
      ),
    };
  }

  final String title;
  final String message;
  final String? afterword;
}

// The application as the server holds it: when it was made, when it was
// answered, and what was said. The reason is the whole of what a reader who
// was turned down came here for, so it is drawn in full.
//
// The card is not titled. The line above it already names what it is, and a
// heading that repeats the sentence over it takes the room the standing needs
// to be spelled out in words rather than in one.
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard(this.application);

  final HostApplication application;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatusChip(
            ApplicationStanding.labelOf(application),
            tone: ApplicationStanding.toneOf(application),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Fact(label: 'Sent', value: AppDates.date(application.submittedAt)),
          if (application.reviewedAt case final DateTime answered) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _Fact(label: 'Answered', value: AppDates.date(answered)),
          ],
          if (application.decisionReason case final String reason) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(reason, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

// What an administrator will read, drawn as they will read it. The account is
// the application, so showing the account is showing the whole of what is
// sent.
class _AccountCard extends StatelessWidget {
  const _AccountCard(this.account);

  final User account;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: <Widget>[
          AccountAvatar(
            userId: account.id,
            name: account.fullName,
            hasImage: account.hasProfileImage,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(account.fullName, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  account.username,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar(this.applications);

  final HostApplicationNotifier applications;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      action: FilledButton(
        onPressed: applications.isBusy
            ? null
            : () => unawaited(_send(context, applications)),
        child: Text(applications.isBusy ? 'Sending' : 'Send your application'),
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    HostApplicationNotifier applications,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (await applications.apply()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Your application was sent.')),
      );
    }
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.words, {this.isFootnote = false});

  final String words;
  final bool isFootnote;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Text(
      words,
      style: isFootnote
          ? text.bodySmall?.copyWith(color: AppColors.inkFaint)
          : text.bodyMedium?.copyWith(color: AppColors.inkMuted),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(value, style: text.bodyMedium),
      ],
    );
  }
}
