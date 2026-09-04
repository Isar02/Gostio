import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/filter_bar.dart';
import '../data/report_range.dart';
import 'reports_notifier.dart';

class ReportFilters extends StatelessWidget {
  const ReportFilters({
    required this.kind,
    required this.range,
    required this.catalogue,
    required this.onShowReport,
    required this.onApplyRange,
    required this.onApplyCatalogue,
    this.trailing,
    super.key,
  });

  final ReportKind kind;
  final ReportRange range;
  final ListingKind catalogue;
  final ValueChanged<ReportKind> onShowReport;
  final ValueChanged<ReportRange> onApplyRange;
  final ValueChanged<ListingKind> onApplyCatalogue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return FilterBar(
      trailing: trailing,
      filters: <Widget>[
        FilterField(
          label: 'Report',
          width: AppSizes.filterFieldWide,
          child: AppDropdown<ReportKind>(
            value: kind,
            values: ReportKind.values,
            labels: (ReportKind value) => value.title,
            onChanged: onShowReport,
          ),
        ),
        FilterField(
          label: 'From',
          child: DateField(
            value: range.from,
            isClearable: false,
            onChanged: (DateTime? day) {
              if (day != null) {
                onApplyRange(range.startingOn(day));
              }
            },
          ),
        ),
        FilterField(
          label: 'To',
          child: DateField(
            value: range.to,
            isClearable: false,
            errorText: range.refusal,
            onChanged: (DateTime? day) {
              if (day != null) {
                onApplyRange(range.endingOn(day));
              }
            },
          ),
        ),
        if (kind == ReportKind.listings)
          FilterField(
            label: 'Catalogue',
            child: AppDropdown<ListingKind>(
              value: catalogue,
              values: ListingKind.values,
              labels: (ListingKind value) => value.catalogueName,
              onChanged: onApplyCatalogue,
            ),
          ),
      ],
    );
  }
}
