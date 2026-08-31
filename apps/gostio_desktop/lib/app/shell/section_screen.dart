import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session/session.dart';
import '../../core/widgets/screen_states.dart';
import '../../features/accommodations/presentation/accommodations_screen.dart';
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
        hostId: _hostId(context),
      ),
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
