import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

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
import '../data/accommodation.dart';
import '../data/accommodation_draft.dart';
import 'accommodation_detail_notifier.dart';
import 'accommodation_form_options.dart';

class AccommodationForm extends StatefulWidget {
  const AccommodationForm({
    required this.notifier,
    required this.onSaved,
    required this.onDeleted,
    super.key,
  });

  final AccommodationDetailNotifier notifier;
  final ValueChanged<Accommodation> onSaved;
  final ValueChanged<Accommodation> onDeleted;

  @override
  State<AccommodationForm> createState() => _AccommodationFormState();
}

class _AccommodationFormState extends State<AccommodationForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _guests = TextEditingController();
  final TextEditingController _bedrooms = TextEditingController();
  final TextEditingController _bathrooms = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _fee = TextEditingController();

  LookupItem? _type;
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

    final Accommodation? listing = widget.notifier.accommodation;
    if (listing == null) {
      return;
    }

    _title.text = listing.title;
    _description.text = listing.description;
    _address.text = listing.address;
    _guests.text = '${listing.maxGuests}';
    _bedrooms.text = '${listing.bedrooms}';
    _bathrooms.text = '${listing.bathrooms}';
    _price.text = AppNumbers.typed(listing.pricePerNight);
    _fee.text = AppNumbers.typed(listing.cleaningFee);
    _isActive = listing.isActive;
    _point = LatLng(listing.latitude, listing.longitude);

    final AccommodationFormOptions options = widget.notifier.options;
    _type = _itemFor(options.types, listing.accommodationTypeId);
    _category = _itemFor(options.categories, listing.accommodationCategoryId);
    _city = _itemFor(options.cities, listing.cityId);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title,
      _description,
      _address,
      _guests,
      _bedrooms,
      _bathrooms,
      _price,
      _fee,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AccommodationDetailNotifier notifier = widget.notifier;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (notifier.writeFailureMessage
                case final String message) ...<Widget>[
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

  Widget _describe(AccommodationDetailNotifier notifier) => Column(
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
        label: 'Type',
        anyLabel: 'Choose a type',
        errorText:
            _faults['type'] ?? notifier.messageFor('accommodationTypeId'),
        value: _type,
        values: notifier.options.types,
        labels: (LookupItem type) => type.name,
        onChanged: (LookupItem? type) => setState(() => _type = type),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppOptionalDropdown<LookupItem>(
        label: 'Category',
        anyLabel: 'Choose a category',
        errorText:
            _faults['category'] ??
            notifier.messageFor('accommodationCategoryId'),
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

  Widget _place(AccommodationDetailNotifier notifier) => Column(
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
        controller: _address,
        decoration: InputDecoration(
          labelText: 'Address',
          errorText: notifier.messageFor('address'),
        ),
        validator: Validators.address,
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
        children: <Widget>[
          Expanded(
            child: _whole(_guests, 'Guests', Validators.guests, 'maxGuests'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _whole(
              _bedrooms,
              'Bedrooms',
              Validators.bedrooms,
              'bedrooms',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _whole(
              _bathrooms,
              'Bathrooms',
              Validators.bathrooms,
              'bathrooms',
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      Row(
        children: <Widget>[
          Expanded(
            child: _amount(
              _price,
              'Price per night',
              Validators.price,
              'pricePerNight',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _amount(_fee, 'Cleaning fee', Validators.fee, 'cleaningFee'),
          ),
        ],
      ),
    ],
  );

  Widget _whole(
    TextEditingController controller,
    String label,
    FormFieldValidator<String> check,
    String field,
  ) => TextFormField(
    controller: controller,
    inputFormatters: <TextInputFormatter>[InputFormats.whole],
    decoration: InputDecoration(
      labelText: label,
      errorText: widget.notifier.messageFor(field),
    ),
    validator: check,
  );

  Widget _amount(
    TextEditingController controller,
    String label,
    FormFieldValidator<String> check,
    String field,
  ) => TextFormField(
    controller: controller,
    inputFormatters: <TextInputFormatter>[InputFormats.amount],
    decoration: InputDecoration(
      labelText: label,
      suffixText: AppNumbers.currency,
      errorText: widget.notifier.messageFor(field),
    ),
    validator: check,
  );

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
          if (_type == null) 'type': 'Choose the type of accommodation.',
          if (_category == null)
            'category': 'Choose the category this accommodation belongs to.',
          if (_city == null)
            'city': 'Choose the city this accommodation is in.',
          if (_point == null) 'point': 'Choose the place on the map.',
          if (widget.notifier.isCreating &&
              widget.notifier.asAdministrator &&
              _host == null)
            'host': 'Choose the host this accommodation belongs to.',
        });
    });

    if (!written || _faults.isNotEmpty) {
      return;
    }

    final Accommodation? saved = await widget.notifier.save(
      AccommodationDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        accommodationTypeId: _type!.id,
        accommodationCategoryId: _category!.id,
        cityId: _city!.id,
        address: _address.text.trim(),
        latitude: _point!.latitude,
        longitude: _point!.longitude,
        maxGuests: int.parse(_guests.text.trim()),
        bedrooms: int.parse(_bedrooms.text.trim()),
        bathrooms: int.parse(_bathrooms.text.trim()),
        pricePerNight: double.parse(_price.text.trim()),
        cleaningFee: double.parse(_fee.text.trim()),
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

  // A listing that has just been created leaves the form empty for the next
  // one rather than sitting there looking like it is still being written.
  void _reset() {
    _form.currentState?.reset();

    setState(() {
      _title.clear();
      _description.clear();
      _address.clear();
      _guests.clear();
      _bedrooms.clear();
      _bathrooms.clear();
      _price.clear();
      _fee.clear();
      _type = null;
      _category = null;
      _city = null;
      _host = null;
      _point = null;
      _faults.clear();
    });
  }

  Future<void> _confirmDelete() async {
    final Accommodation? listing = widget.notifier.accommodation;
    if (listing == null) {
      return;
    }

    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Delete ${listing.title}?',
      message:
          'Its photographs, its availability and the amenities it claims go '
          'with it. This cannot be undone.',
      confirmLabel: 'Delete listing',
      isDestructive: true,
    );

    if (!agreed) {
      return;
    }

    final bool gone = await widget.notifier.delete();

    if (gone && mounted) {
      widget.onDeleted(listing);
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
            ? 'Guests can find and book this listing.'
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

  final AccommodationDetailNotifier notifier;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (!notifier.isCreating)
          Tooltip(
            message: notifier.isBooked
                ? 'A listing with a reservation against it cannot be deleted.'
                : 'Delete this listing and everything that hangs off it.',
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

  static String _label(AccommodationDetailNotifier notifier) {
    if (notifier.isSaving) {
      return notifier.isCreating ? 'Creating' : 'Saving';
    }

    return notifier.isCreating ? 'Create listing' : 'Save changes';
  }
}
