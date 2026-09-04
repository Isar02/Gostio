import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_metrics.dart';
import '../core/widgets/brand_mark.dart';
import '../features/auth/presentation/sign_out.dart';

// What an account sees once it is in, until the tabs are built.
class SignedInScreen extends StatelessWidget {
  const SignedInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final User? account = context.select<Session, User?>(
      (Session session) => session.account,
    );

    if (account == null) {
      return const Scaffold();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(alignment: Alignment.centerLeft, child: BrandMark()),
              const SizedBox(height: AppSpacing.xl),
              Text(account.fullName, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                account.email,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => signOut(context),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
