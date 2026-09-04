import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../data/home_country.dart';
import '../data/reference_repository.dart';
import '../data/reference_row.dart';
import '../data/reference_table.dart';

enum ReferenceFieldKind { line, paragraph, choice }

typedef ChoiceReader = Future<List<LookupItem>> Function(
  ReferenceRepository reference,
);

@immutable
class ReferenceColumn {
  const ReferenceColumn({
    required this.key,
    required this.label,
    this.width,
    this.flex = 1,
  });

  final String key;
  final String label;
  final double? width;
  final int flex;
}

@immutable
class ReferenceField {
  const ReferenceField({
    required this.key,
    required this.label,
    this.kind = ReferenceFieldKind.line,
    this.validator,
    this.hint,
    this.missing,
  });

  final String key;
  final String label;
  final ReferenceFieldKind kind;
  final String? Function(String? value)? validator;
  final String? hint;
  final String? missing;
}

@immutable
class ReferenceLayout {
  const ReferenceLayout({
    this.columns = const <ReferenceColumn>[],
    this.fields = const <ReferenceField>[],
    this.choices,
    this.frozen,
    this.kept,
  });

  static ReferenceLayout of(ReferenceTable table) => switch (table) {
    ReferenceTable.countries => _countries,
    ReferenceTable.cities => _cities,
    ReferenceTable.roles => _roles,
    ReferenceTable.reservationStatuses => _reservationStatuses,
    ReferenceTable.accommodationTypes ||
    ReferenceTable.accommodationCategories ||
    ReferenceTable.experienceCategories ||
    ReferenceTable.amenities => _nameAlone,
  };

  final List<ReferenceColumn> columns;
  final List<ReferenceField> fields;

  final ChoiceReader? choices;

  final String? Function(ReferenceRow row, String key)? frozen;
  final String? Function(ReferenceRow row)? kept;

  List<ReferenceField> get form => <ReferenceField>[_name, ...fields];

  static const ReferenceField _name = ReferenceField(
    key: ReferenceKeys.name,
    label: 'Name',
    validator: Validators.lookupName,
  );

  static const ReferenceLayout _nameAlone = ReferenceLayout();

  static const ReferenceLayout _countries = ReferenceLayout(
    columns: <ReferenceColumn>[
      ReferenceColumn(
        key: ReferenceKeys.isoCode,
        label: 'Code',
        width: AppSizes.compactColumn,
      ),
    ],
    fields: <ReferenceField>[
      ReferenceField(
        key: ReferenceKeys.isoCode,
        label: 'Country code',
        validator: Validators.countryCode,
      ),
    ],
    frozen: _homeCountryCode,
  );

  static const ReferenceLayout _cities = ReferenceLayout(
    columns: <ReferenceColumn>[
      ReferenceColumn(key: ReferenceKeys.countryName, label: 'Country'),
    ],
    fields: <ReferenceField>[
      ReferenceField(
        key: ReferenceKeys.countryId,
        label: 'Country',
        kind: ReferenceFieldKind.choice,
        hint: 'Choose a country',
        missing: 'Choose the country this city is in.',
      ),
    ],
    choices: _countriesACityMayBeIn,
  );

  static const ReferenceLayout _roles = ReferenceLayout(
    frozen: _namedRoleField,
    kept: _namedRole,
  );

  static const ReferenceLayout _reservationStatuses = ReferenceLayout(
    columns: <ReferenceColumn>[
      ReferenceColumn(
        key: ReferenceKeys.code,
        label: 'Code',
        width: AppSizes.numericColumn,
      ),
      ReferenceColumn(
        key: ReferenceKeys.description,
        label: 'Description',
        flex: 2,
      ),
    ],
    fields: <ReferenceField>[
      ReferenceField(
        key: ReferenceKeys.code,
        label: 'Code',
        validator: Validators.code,
      ),
      ReferenceField(
        key: ReferenceKeys.description,
        label: 'Description',
        kind: ReferenceFieldKind.paragraph,
        validator: Validators.optionalDescription,
      ),
    ],
    frozen: _stateMachineCode,
    kept: _stateMachineStatus,
  );

  static Future<List<LookupItem>> _countriesACityMayBeIn(
    ReferenceRepository reference,
  ) => reference.countriesHoldingCities();

  static String? _homeCountryCode(ReferenceRow row, String key) =>
      key == ReferenceKeys.isoCode && _isHome(row)
      ? '${row.name} is the country this platform carries, so its code cannot '
            'change.'
      : null;

  static bool _isHome(ReferenceRow row) =>
      row.text(ReferenceKeys.isoCode) == HomeCountry.isoCode;

  static String? _namedRole(ReferenceRow row) =>
      _endpointRoles.contains(row.name)
      ? 'The ${row.name} role is named by the endpoints themselves and can be '
            'neither renamed nor removed.'
      : null;

  static String? _namedRoleField(ReferenceRow row, String key) =>
      _namedRole(row);

  static String? _stateMachineStatus(ReferenceRow row) =>
      _isStateMachineStatus(row)
      ? 'The ${row.text(ReferenceKeys.code)} status is one the reservation '
            'state machine names and cannot be deleted.'
      : null;

  static String? _stateMachineCode(ReferenceRow row, String key) =>
      key == ReferenceKeys.code && _isStateMachineStatus(row)
      ? 'The ${row.text(ReferenceKeys.code)} status is one the reservation '
            'state machine names, so its code cannot change. Its name and '
            'description can.'
      : null;

  static bool _isStateMachineStatus(ReferenceRow row) =>
      ReservationStatus.forId(row.id) != null;

  static const Set<String> _endpointRoles = <String>{
    RoleNames.administrator,
    RoleNames.host,
    RoleNames.guest,
  };
}
