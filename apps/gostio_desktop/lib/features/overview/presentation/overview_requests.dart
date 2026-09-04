import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';

// The accounts asking to let something out, oldest waiting first on the screen
// that answers them. Nothing is decided from here: the overview says there is
// something to look at, and the section that owns the decision takes it.
class OverviewRequests extends StatelessWidget {
  const OverviewRequests({required this.requests, super.key});

  final List<HostApplication> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const EmptyState(
        title: 'Nobody is waiting',
        message: 'Every request to host has been answered.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: requests.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: AppSizes.hairline),
      itemBuilder: (BuildContext context, int index) =>
          _Request(request: requests[index]),
    );
  }
}

class _Request extends StatelessWidget {
  const _Request({required this.request});

  final HostApplication request;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  request.applicantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMedium,
                ),
                Text(
                  request.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(AppDates.age(request.submittedAt), style: type.bodySmall),
        ],
      ),
    );
  }
}
