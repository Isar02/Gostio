import 'package:flutter/material.dart';

import '../models/paged_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
    super.key,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  int get _totalPages =>
      PagedResult.pagesFor(totalCount: totalCount, pageSize: pageSize);

  int get _firstOnPage => (page - 1) * pageSize + 1;

  int get _lastOnPage =>
      page * pageSize < totalCount ? page * pageSize : totalCount;

  @override
  Widget build(BuildContext context) {
    final TextStyle? counts = Theme.of(context).textTheme.bodySmall;

    return Container(
      height: AppSizes.footerRow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            totalCount == 0
                ? 'No rows'
                : '$_firstOnPage–$_lastOnPage of $totalCount',
            style: counts,
          ),
          const Spacer(),
          IconButton(
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          Text('$page of $_totalPages', style: counts),
          IconButton(
            onPressed: page < _totalPages
                ? () => onPageChanged(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
