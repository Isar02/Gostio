import 'package:flutter/material.dart';

import '../../core/widgets/screen_states.dart';
import 'app_section.dart';

// Each section replaces this with its own screen as its unit of work lands.
class SectionScreen extends StatelessWidget {
  const SectionScreen({required this.section, super.key});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: section.label,
      message: 'This section has not been built yet.',
    );
  }
}
