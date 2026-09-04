import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/filter_bar.dart';
import '../data/conversation_query.dart';

class ConversationFilters extends StatelessWidget {
  const ConversationFilters({
    required this.applied,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  final ConversationQuery applied;
  final bool isLoading;
  final ValueChanged<ConversationQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      onClear: applied.isEmpty || isLoading
          ? null
          : () => onChanged(applied.withType(null)),
      filters: <Widget>[
        FilterField(
          label: 'Kind',
          width: AppSizes.filterFieldNarrow,
          child: AppOptionalDropdown<ConversationType>(
            value: applied.type,
            values: ConversationType.asked,
            labels: (ConversationType type) => type.label,
            onChanged: (ConversationType? type) =>
                onChanged(applied.withType(type)),
          ),
        ),
      ],
    );
  }
}
