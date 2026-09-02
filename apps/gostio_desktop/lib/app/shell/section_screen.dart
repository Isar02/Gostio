import 'package:flutter/material.dart';

import '../../core/models/user.dart';
import '../../core/widgets/screen_states.dart';
import '../../features/accommodations/presentation/accommodations_screen.dart';
import '../../features/experiences/presentation/experiences_screen.dart';
import '../../features/reservations/presentation/reservations_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import 'app_section.dart';
import 'workspace_mode.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({
    required this.mode,
    required this.section,
    required this.account,
    super.key,
  });

  final WorkspaceMode mode;
  final AppSection section;
  final User account;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AppSection.accommodations => AccommodationsScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId,
      ),
      AppSection.experiences => ExperiencesScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId,
      ),
      // Nothing about this list is the administrator's alone: what a booking
      // can be told is the server's to allow, and it allows the same two moves
      // to the host of the listing and to an administrator over both.
      AppSection.reservations => ReservationsScreen(hostId: _hostId),
      // Reached from the administrator's navigation alone, and the account is
      // passed because three writes on it are refused against the caller's
      // own.
      AppSection.users => UsersScreen(signedInUserId: account.id),
      _ => EmptyState(
        title: section.label,
        message: 'This section has not been built yet.',
      ),
    };
  }

  // The host panel reads the same table from the caller's own angle.
  int? get _hostId => mode == WorkspaceMode.host ? account.id : null;
}
