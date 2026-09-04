import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/models/image_upload.dart';
import '../../../core/models/user.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/profile_repository.dart';
import 'profile_details_form.dart';
import 'profile_notifier.dart';
import 'profile_password_form.dart';
import 'profile_picture_field.dart';

// The one screen an account is the subject of rather than the caller. Both
// panels reach it, because both are somebody signed in.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileNotifier>(
      create: (BuildContext context) {
        final ProfileNotifier profile = ProfileNotifier(
          context.read<ProfileRepository>(),
          context.read<Session>(),
        );
        unawaited(profile.load());

        return profile;
      },
      child: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  Widget build(BuildContext context) {
    final ProfileNotifier profile = context.watch<ProfileNotifier>();

    if (profile.isLoading) {
      return const LoadingState(message: 'Reading your account');
    }

    final User? account = profile.account;

    if (account == null) {
      return ErrorState(
        message: profile.failureMessage ?? 'Your account could not be read.',
        traceId: profile.failureTraceId,
        onRetry: profile.load,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ProfilePictureField(
                account: account,
                isBusy: profile.isWriting,
                onChosen: _setPicture,
                onCleared: _clearPicture,
                errorText: profile.pictureFailureMessage,
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: _Identity(account: account)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _Section(
                  title: 'Your details',
                  caption: 'What the people you host see beside your name.',
                  child: ProfileDetailsForm(
                    notifier: profile,
                    account: account,
                    onSaved: () => _say('Your details were saved.'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(
                child: _Section(
                  title: 'Password',
                  caption: 'Changing it needs the one you sign in with now.',
                  child: ProfilePasswordForm(
                    notifier: profile,
                    onChanged: () => _say('Your password was changed.'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setPicture(ImageUpload picture) async {
    final ProfileNotifier profile = context.read<ProfileNotifier>();

    await _afterPicture(
      () => profile.setPicture(picture),
      said: 'Your picture was updated.',
    );
  }

  Future<void> _clearPicture() async {
    final ProfileNotifier profile = context.read<ProfileNotifier>();

    await _afterPicture(
      profile.clearPicture,
      said: 'Your picture was removed.',
    );
  }

  // The bytes at that address have changed, and neither the cache nor an
  // avatar already showing the old ones can see that on their own.
  Future<void> _afterPicture(
    Future<bool> Function() write, {
    required String said,
  }) async {
    final int? id = context.read<ProfileNotifier>().account?.id;
    final bool written = await write();

    if (!written || !mounted || id == null) {
      return;
    }

    await ApiImage.forget(context, '/users/$id/image');

    if (mounted) {
      _say(said);
    }
  }

  void _say(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _Identity extends StatelessWidget {
  const _Identity({required this.account});

  final User account;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(account.fullName, style: text.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          account.username,
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        // Neither is written from here: a username is written once, and what
        // an account may reach is an administrator's to say.
        _Fact(label: 'Roles', value: account.roles.join(' · ')),
        const SizedBox(height: AppSpacing.xs),
        _Fact(label: 'Joined', value: AppDates.date(account.createdAt)),
      ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: AppSizes.labelColumn,
          child: Text(
            label,
            style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(value, style: text.bodySmall)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.caption,
    required this.child,
  });

  final String title;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption,
              style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}
