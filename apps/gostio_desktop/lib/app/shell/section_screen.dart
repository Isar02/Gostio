import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session/session.dart';
import '../../core/widgets/screen_states.dart';
import '../../features/accommodations/presentation/accommodations_screen.dart';
import '../../features/experiences/presentation/experiences_screen.dart';
import '../../features/reservations/presentation/reservations_screen.dart';
import 'app_section.dart';
import 'workspace_mode.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({required this.mode, required this.section, super.key});

  final WorkspaceMode mode;
  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AppSection.accommodations => AccommodationsScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId(context),
      ),
      AppSection.experiences => ExperiencesScreen(
        asAdministrator: mode == WorkspaceMode.administrator,
        hostId: _hostId(context),
      ),
      // Nothing about this list is the administrator's alone: what a booking
      // can be told is the server's to allow, and it allows the same two moves
      // to the host of the listing and to an administrator over both.
      AppSection.reservations => ReservationsScreen(hostId: _hostId(context)),
      _ => EmptyState(
        title: section.label,
        message: 'This section has not been built yet.',
      ),
    };
  }

  // The host panel reads the same table from the caller's own angle.
  int? _hostId(BuildContext context) =>
      mode == WorkspaceMode.host ? context.read<Session>().account?.id : null;
}
