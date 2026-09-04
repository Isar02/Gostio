import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('an amount takes a figure the parser reads back', () {
    expect(_amount('', '40'), '40');
    expect(_amount('40', '40.'), '40.');
    expect(_amount('40.', '40.5'), '40.5');
    expect(_amount('40.5', '40.55'), '40.55');
    expect(_amount('40', ''), '');
  });

  test('an amount refuses what would then be dropped from the request', () {
    expect(_amount('', '.'), '');
    expect(_amount('1.2', '1.2.'), '1.2');
    expect(_amount('40.55', '40.555'), '40.55');
    expect(_amount('40', '40a'), '40');
  });
}

String _amount(String previous, String typed) => InputFormats.amount
    .formatEditUpdate(
      TextEditingValue(
        text: previous,
        selection: TextSelection.collapsed(offset: previous.length),
      ),
      TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    )
    .text;
