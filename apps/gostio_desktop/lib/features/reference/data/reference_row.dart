import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

abstract final class ReferenceKeys {
  static const String id = 'id';
  static const String name = 'name';
  static const String isoCode = 'isoCode';
  static const String code = 'code';
  static const String description = 'description';
  static const String countryId = 'countryId';
  static const String countryName = 'countryName';
}

@immutable
class ReferenceRow {
  const ReferenceRow({
    required this.id,
    required this.name,
    this.details = const <String, dynamic>{},
  });

  factory ReferenceRow.fromJson(JsonMap json) => ReferenceRow(
    id: json[ReferenceKeys.id]! as int,
    name: json[ReferenceKeys.name]! as String,
    details: <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in json.entries)
        if (entry.key != ReferenceKeys.id && entry.key != ReferenceKeys.name)
          entry.key: entry.value,
    },
  );

  final int id;
  final String name;
  final Map<String, dynamic> details;

  String text(String key) =>
      key == ReferenceKeys.name ? name : details[key] as String? ?? '';

  int? number(String key) => details[key] as int?;
}
