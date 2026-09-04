import 'package:flutter/services.dart';

// The shape is checked over the whole field rather than character by
// character, so nothing the parser would then quietly refuse — a second
// decimal point, a bare point, a third decimal — reaches the value at all.
abstract final class InputFormats {
  static final TextInputFormatter amount = TextInputFormatter.withFunction(
    (TextEditingValue previous, TextEditingValue value) =>
        _amount.hasMatch(value.text) ? value : previous,
  );

  static final TextInputFormatter whole =
      FilteringTextInputFormatter.digitsOnly;

  static final RegExp _amount = RegExp(r'^(\d+(\.\d{0,2})?)?$');
}
