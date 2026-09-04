import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

typedef FieldKey = GlobalKey<FormFieldState<Object?>>;

// The fields of one form, in the order they are read down. A phone keyboard
// covers the lower half of the screen, so a refusal brings the first field
// carrying it back into view rather than leaving the reader to find it.
class FormFields {
  FormFields(List<String> names)
    : _keys = <String, FieldKey>{
        for (final String name in names) name: FieldKey(),
      };

  final Map<String, FieldKey> _keys;

  FieldKey operator [](String name) {
    final FieldKey? key = _keys[name];
    if (key == null) {
      throw ArgumentError.value(name, 'name', 'This form has no such field.');
    }

    return key;
  }

  bool validate(GlobalKey<FormState> form) {
    if (form.currentState?.validate() ?? false) {
      return true;
    }

    for (final FieldKey field in _keys.values) {
      if (field.currentState?.hasError ?? false) {
        _reveal(field);
        break;
      }
    }

    return false;
  }

  // The server faults by the property it bound, which is the name the field
  // was sent under.
  void revealFault(ApiException failure) {
    for (final MapEntry<String, FieldKey> field in _keys.entries) {
      if (failure.messagesFor(field.key).isNotEmpty) {
        _reveal(field.value);
        break;
      }
    }
  }

  static void _reveal(FieldKey field) {
    final BuildContext? where = field.currentContext;
    if (where == null) {
      return;
    }

    unawaited(
      Scrollable.ensureVisible(
        where,
        alignment: 0.2,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }
}
