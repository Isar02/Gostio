import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/formatting/app_durations.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/input_formats.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/map_point_field.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/presentation/add_city_dialog.dart';
import '../../reference/presentation/city_field.dart';
import '../data/experience.dart';
import '../data/experience_draft.dart';
import 'experience_detail_notifier.dart';

class ExperienceForm extends StatefulWidget {
  const ExperienceForm({
    required this.notifier,
    required this.onSaved,
    required this.onDeleted,
    super.key,
  });

  final ExperienceDetailNotifier notifier;
  final ValueChanged<Experience> onSaved;
  final ValueChanged<Experience> onDeleted;

  @override
  State<ExperienceForm> createState() => _ExperienceFormState();
}

class _ExperienceFormState extends State<ExperienceForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _meetingPoint = TextEditingController();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _price = TextEditingController();

  LookupItem? _category;
  LookupItem? _city;
  User? _host;
  LatLng? _point;
  bool _isActive = true;

  // A dropdown and the map cannot fault themselves through Form, so what they
  // are missing is held here and written under the control it belongs to.
  final Map<String, String> _faults = <String, String>{};

  @override
  void initState() {
    super.initState();

    final Experience? experience = widget.notifier.experience;
    if (experience == null) {
      return;
    }

    _title.text = experience.title;
    _description.text = experience.description;
    _meetingPoint.text = experience.meetingPoint;
    _duration.text = '${experience.durationMinutes}';
    _price.text = AppNumbers.typed(experience.pricePerPerson);
    _isActive = experience.isActive;
    _point = LatLng(experience.latitude, experience.longitude);

    _category = _itemFor(
      widget.notifier.options.categories,
      experience.experienceCategoryId,
    );
    _city = _itemFor(widget.notifier.options.cities, experience.cityId);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _description,
      _meetingPoint,
      _duration,
      _price,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExperienceDetailNotifier notifier = widget.notifier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (notifier.failureMessage case final String message) ...<Widget>[
              AppNotice(message),
              const SizedBox(height: AppSpacing.lg),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _describe(notifier)),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: _place(notifier)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _Actions(
              notifier: notifier,
              onSave: _submit,
              onDelete: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _describe(ExperienceDetailNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextFormField(
        controller: _title,
        decoration: InputDecoration(
          labelText: 'Title',
          errorText: notifier.messageFor('title'),
        ),
        validator: Validators.title,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextFormField(
        controller: _description,
        minLines: 6,
        maxLines: 10,
        decoration: InputDecoration(
          labelText: 'Description',
          alignLabelWithHint: true,
          errorText: notifier.messageFor('description'),
        ),
        validator: Validators.description,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppOptionalDropdown<LookupItem>(
        label: 'Category',
        anyLabel: 'Choose a category',
        errorText:
            _faults['category'] ?? notifier.messageFor('experienceCategoryId'),
        value: _category,
        values: notifier.options.categories,
        labels: (LookupItem category) => category.name,
        onChanged: (LookupItem? category) =>
            setState(() => _category = category),
      ),
      if (!notifier.isCreating) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        _Published(
          isActive: _isActive,
          onChanged: (bool published) => setState(() => _isActive = published),
        ),
      ],
    ],
  );

  Widget _place(ExperienceDetailNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (notifier.isCreating && notifier.asAdministrator) ...<Widget>[
        AppOptionalDropdown<User>(
          label: 'Host',
          anyLabel: 'Choose a host',
          errorText: _faults['host'] ?? notifier.messageFor('hostId'),
          value: _host,
          values: notifier.options.hosts,
          labels: (User host) => host.fullName,
          onChanged: (User? host) => setState(() => _host = host),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      CityField(
        city: _city,
        cities: notifier.options.cities,
        errorText: _faults['city'] ?? notifier.messageFor('cityId'),
        canAdd: notifier.asAdministrator,
        onChanged: (LookupItem? city) => setState(() => _city = city),
        onAdd: _addCity,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextFormField(
        controller: _meetingPoint,
        decoration: InputDecoration(
          labelText: 'Meeting point',
          helperText: 'Where the group gathers before it sets off.',
          errorText: notifier.messageFor('meetingPoint'),
        ),
        validator: Validators.meetingPoint,
      ),
      const SizedBox(height: AppSpacing.lg),
      MapPointField(
        point: _point,
        errorText:
            _faults['point'] ??
            notifier.messageFor('latitude') ??
            notifier.messageFor('longitude'),
        onChanged: (LatLng point) => setState(() => _point = point),
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: _durationField(notifier)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextFormField(
              controller: _price,
              inputFormatters: <TextInputFormatter>[InputFormats.amount],
              decoration: InputDecoration(
                labelText: 'Price per person',
                suffixText: AppNumbers.currency,
                errorText: notifier.messageFor('pricePerPerson'),
              ),
              validator: Validators.pricePerPerson,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _durationField(ExperienceDetailNotifier notifier) => TextFormField(
    controller: _duration,
    inputFormatters: <TextInputFormatter>[InputFormats.whole],
    decoration: InputDecoration(
      labelText: 'Duration',
      suffixText: 'min',
      helperText: _durationInWords,
      errorText: notifier.messageFor('durationMinutes'),
    ),
    validator: Validators.duration,
    onChanged: (String _) => setState(() {}),
  );

  String? get _durationInWords {
    final int? minutes = int.tryParse(_duration.text.trim());

    return minutes == null || minutes < 1
        ? null
        : AppDurations.inWords(minutes);
  }

  Future<void> _addCity() async {
    final LookupItem? added = await showDialog<LookupItem>(
      context: context,
      builder: (BuildContext context) => AddCityDialog(
        countries: widget.notifier.options.countries,
        add: widget.notifier.addCity,
      ),
    );

    if (added != null && mounted) {
      setState(() => _city = added);
    }
  }

  Future<void> _submit() async {
    final bool written = _form.currentState?.validate() ?? false;

    setState(() {
      _faults
        ..clear()
        ..addAll(<String, String>{
          if (_category == null)
            'category': 'Choose the category this experience belongs to.',
          if (_city == null)
            'city': 'Choose the city this experience takes place in.',
          if (_point == null) 'point': 'Choose the place on the map.',
          if (widget.notifier.isCreating &&
              widget.notifier.asAdministrator &&
              _host == null)
            'host': 'Choose the host this experience belongs to.',
        });
    });

    if (!written || _faults.isNotEmpty) {
      return;
    }

    final Experience? saved = await widget.notifier.save(
      ExperienceDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        experienceCategoryId: _category!.id,
        cityId: _city!.id,
        meetingPoint: _meetingPoint.text.trim(),
        latitude: _point!.latitude,
        longitude: _point!.longitude,
        durationMinutes: int.parse(_duration.text.trim()),
        pricePerPerson: double.parse(_price.text.trim()),
      ),
      isActive: _isActive,
      hostId: _host?.id,
    );

    // Back during the save takes the screen the callback would reach for, and
    // the notifier's own guard does not cover a context.
    if (saved == null || !mounted) {
      return;
    }

    if (widget.notifier.isCreating) {
      _reset();
    }

    widget.onSaved(saved);
  }

  // An experience that has just been created leaves the form empty for the
  // next one rather than sitting there looking like it is still being written.
  void _reset() {
    _form.currentState?.reset();

    setState(() {
      _title.clear();
      _description.clear();
      _meetingPoint.clear();
      _duration.clear();
      _price.clear();
      _category = null;
      _city = null;
      _host = null;
      _point = null;
      _faults.clear();
    });
  }

  Future<void> _confirmDelete() async {
    final Experience? experience = widget.notifier.experience;
    if (experience == null) {
      return;
    }

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete ${experience.title}?',
      message:
          'Its photographs and every term it runs go with it. This cannot be '
          'undone.',
      confirmLabel: 'Delete experience',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    final bool gone = await widget.notifier.delete();

    if (gone && mounted) {
      widget.onDeleted(experience);
    }
  }

  static LookupItem? _itemFor(List<LookupItem> values, int id) {
    for (final LookupItem value in values) {
      if (value.id == id) {
        return value;
      }
    }

    return null;
  }
}

class _Published extends StatelessWidget {
  const _Published({required this.isActive, required this.onChanged});

  final bool isActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SwitchListTile(
      value: isActive,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text('Published', style: text.bodyMedium),
      subtitle: Text(
        isActive
            ? 'Guests can find and book this experience.'
            : 'Withdrawn: it stays here, and guests cannot see it.',
        style: text.bodySmall,
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.notifier,
    required this.onSave,
    required this.onDelete,
  });

  final ExperienceDetailNotifier notifier;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (!notifier.isCreating)
          Tooltip(
            message: notifier.isBooked
                ? 'An experience with a reservation against it cannot be '
                      'deleted.'
                : 'Delete this experience and everything that hangs off it.',
            child: OutlinedButton(
              onPressed: notifier.isBooked || notifier.isSaving
                  ? null
                  : onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Delete'),
            ),
          ),
        const Spacer(),
        FilledButton(
          onPressed: notifier.isSaving ? null : onSave,
          child: Text(_label(notifier)),
        ),
      ],
    );
  }

  static String _label(ExperienceDetailNotifier notifier) {
    if (notifier.isSaving) {
      return notifier.isCreating ? 'Creating' : 'Saving';
    }

    return notifier.isCreating ? 'Create experience' : 'Save changes';
  }
}
