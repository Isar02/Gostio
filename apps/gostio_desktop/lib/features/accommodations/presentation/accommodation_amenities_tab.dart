import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/screen_states.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../data/accommodation_amenities_repository.dart';
import 'accommodation_amenities_notifier.dart';

class AccommodationAmenitiesTab extends StatelessWidget {
  const AccommodationAmenitiesTab({required this.accommodationId, super.key});

  final int accommodationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccommodationAmenitiesNotifier>(
      create: (BuildContext context) {
        final AccommodationAmenitiesNotifier amenities =
            AccommodationAmenitiesNotifier(
              context.read<AccommodationAmenitiesRepository>(),
              context.read<ReferenceRepository>(),
              accommodationId: accommodationId,
            );
        unawaited(amenities.load());

        return amenities;
      },
      child: const _Amenities(),
    );
  }
}

class _Amenities extends StatelessWidget {
  const _Amenities();

  @override
  Widget build(BuildContext context) {
    final AccommodationAmenitiesNotifier amenities = context
        .watch<AccommodationAmenitiesNotifier>();

    if (amenities.isLoading) {
      return const LoadingState(message: 'Reading the amenities');
    }

    if (amenities.failureMessage case final String message
        when !amenities.isLoaded) {
      return ErrorState(
        message: message,
        onRetry: amenities.load,
        traceId: amenities.failureTraceId,
      );
    }

    if (amenities.vocabulary.isEmpty) {
      return const EmptyState(
        title: 'No amenities to offer',
        message:
            'Nothing has been added to the amenities table yet. Add them '
            'under Reference data first.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Summary(amenities: amenities),
          if (amenities.failureMessage case final String message) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(message),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _Wall(amenities: amenities)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.amenities});

  final AccommodationAmenitiesNotifier amenities;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(_line, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: AppSpacing.lg),
        TextButton(
          onPressed: amenities.hasChanges && !amenities.isSaving
              ? amenities.discard
              : null,
          child: const Text('Discard'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Save(amenities: amenities),
      ],
    );
  }

  String get _line {
    final String held =
        '${amenities.chosenCount} of ${amenities.vocabulary.length} offered';

    final List<String> pending = <String>[
      if (amenities.added.isNotEmpty) '${amenities.added.length} to add',
      if (amenities.removed.isNotEmpty) '${amenities.removed.length} to remove',
    ];

    return pending.isEmpty ? held : '$held · ${pending.join(' · ')}';
  }
}

class _Save extends StatelessWidget {
  const _Save({required this.amenities});

  final AccommodationAmenitiesNotifier amenities;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      onPressed: amenities.hasChanges && !amenities.isSaving
          ? amenities.save
          : null,
      child: Text(amenities.isSaving ? 'Saving' : 'Save amenities'),
    );

    return amenities.hasChanges
        ? button
        : Tooltip(message: 'Nothing has changed yet.', child: button);
  }
}

class _Wall extends StatelessWidget {
  const _Wall({required this.amenities});

  final AccommodationAmenitiesNotifier amenities;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          for (final LookupItem amenity in amenities.vocabulary)
            _Offering(
              amenity: amenity,
              isChosen: amenities.isChosen(amenity.id),
              isEnabled: !amenities.isSaving,
              onToggle: () => amenities.toggle(amenity.id),
            ),
        ],
      ),
    );
  }
}

class _Offering extends StatefulWidget {
  const _Offering({
    required this.amenity,
    required this.isChosen,
    required this.isEnabled,
    required this.onToggle,
  });

  final LookupItem amenity;
  final bool isChosen;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  State<_Offering> createState() => _OfferingState();
}

class _OfferingState extends State<_Offering> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isEnabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (PointerEnterEvent event) => setState(() => _isHovered = true),
      onExit: (PointerExitEvent event) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isEnabled ? widget.onToggle : null,
        child: AnimatedContainer(
          duration: _rise,
          curve: Curves.easeOutCubic,
          height: AppSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: _ground,
            borderRadius: AppRadii.pill,
            // The width never changes with the state, or every label would
            // step sideways as its own amenity is turned on.
            border: Border.all(color: _edge, width: AppSizes.focusRing),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                widget.isChosen ? Icons.check : Icons.add,
                size: AppSizes.iconSmall,
                color: _ink,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.amenity.name,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: _ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isLive => _isHovered && widget.isEnabled;

  Color get _ground {
    if (widget.isChosen) {
      return AppColors.selected;
    }

    return _isLive ? AppColors.hover : AppColors.surface;
  }

  Color get _edge {
    if (widget.isChosen) {
      return AppColors.indigo;
    }

    return _isLive ? AppColors.borderStrong : AppColors.border;
  }

  Color get _ink {
    if (widget.isChosen) {
      return AppColors.indigoDeep;
    }

    return _isLive ? AppColors.ink : AppColors.inkMuted;
  }
}

const Duration _rise = Duration(milliseconds: 160);
