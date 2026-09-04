import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

@immutable
class ReferenceQuery {
  const ReferenceQuery({this.name, this.focusId});

  final String? name;
  final int? focusId;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{'name': ?_written(name)};

  @override
  bool operator ==(Object other) =>
      other is ReferenceQuery && other.name == name && other.focusId == focusId;

  @override
  int get hashCode => Object.hash(name, focusId);

  static String? _written(String? value) {
    final String? trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
