import 'package:flutter/material.dart';

import 'form_fields.dart';

// A form is quiet until it has refused something, and corrects itself from
// then on. Validating every keystroke of a form nobody has submitted shouts at
// somebody still typing; leaving it off altogether keeps a refusal on screen
// after the field it named has been put right.
mixin FormValidation<T extends StatefulWidget> on State<T> {
  AutovalidateMode _validation = AutovalidateMode.disabled;

  AutovalidateMode get validation => _validation;

  bool validate(GlobalKey<FormState> form, FormFields fields) {
    if (fields.validate(form)) {
      return true;
    }

    setState(() => _validation = AutovalidateMode.onUserInteraction);

    return false;
  }
}
