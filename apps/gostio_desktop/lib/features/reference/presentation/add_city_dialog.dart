import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../data/lookup_item.dart';

// A city can be added without leaving the form that needed it. The route
// behind this is the administrator's, so a host is never offered it.
class AddCityDialog extends StatefulWidget {
  const AddCityDialog({required this.countries, required this.add, super.key});

  final List<LookupItem> countries;
  final Future<LookupItem> Function({
    required String name,
    required int countryId,
  })
  add;

  @override
  State<AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<AddCityDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();

  LookupItem? _country;
  String? _countryFault;
  bool _isSaving = false;
  ApiException? _failure;

  @override
  void initState() {
    super.initState();
    if (widget.countries.length == 1) {
      _country = widget.countries.single;
    }
  }

  @override
  void dispose() {
    _name.dispose();

    super.dispose();
  }

  // The dialog writes the city itself and stays open if that fails, because
  // the fields the server is complaining about are the ones on it.
  Future<void> _submit() async {
    final bool written = _form.currentState?.validate() ?? false;

    setState(() {
      _countryFault = _country == null
          ? 'Choose the country this city is in.'
          : null;
      _failure = null;
    });

    if (!written || _country == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final LookupItem city = await widget.add(
        name: _name.text.trim(),
        countryId: _country!.id,
      );

      if (mounted) {
        Navigator.of(context).pop(city);
      }
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _failure = failure;
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a city', style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_failure?.message case final String message) ...<Widget>[
                AppNotice(message),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: _failure?.firstMessageFor('name'),
                ),
                validator: Validators.cityName,
                onFieldSubmitted: (String _) => _submit(),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppOptionalDropdown<LookupItem>(
                label: 'Country',
                anyLabel: 'Choose a country',
                errorText:
                    _countryFault ?? _failure?.firstMessageFor('countryId'),
                value: _country,
                values: widget.countries,
                labels: (LookupItem country) => country.name,
                onChanged: (LookupItem? country) =>
                    setState(() => _country = country),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(_isSaving ? 'Adding' : 'Add city'),
        ),
      ],
    );
  }
}
