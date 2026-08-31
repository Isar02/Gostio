import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/validation/validators.dart';

// The messages are the server's own, so each one here is quoted from the
// attribute that writes it rather than from the method under test.
void main() {
  test('a count the server could hold is accepted', () {
    expect(Validators.guests('4'), isNull);
    expect(Validators.bedrooms('0'), isNull);
    expect(Validators.bathrooms('2'), isNull);
    expect(Validators.guests('${Validators.largestWhole}'), isNull);
  });

  test('a count outside its bound is refused in the server words', () {
    expect(
      Validators.guests('0'),
      'An accommodation takes at least one guest.',
    );
    expect(Validators.bedrooms('-1'), 'A bedroom count is zero or more.');
    expect(Validators.bathrooms('-1'), 'A bathroom count is zero or more.');
  });

  test('a count past the 32 bits the server counts in is refused here', () {
    expect(Validators.guests('${Validators.largestWhole + 1}'), isNotNull);
  });

  test('an amount names its bounds the way the server writes them', () {
    expect(
      Validators.price('0'),
      'A nightly price is between 0.01 and 1000000.',
    );
    expect(Validators.fee('-1'), 'A cleaning fee is between 0 and 1000000.');
    expect(Validators.price('0.01'), isNull);
    expect(Validators.fee('0'), isNull);
  });

  test('a title names its limit the way the server writes it', () {
    expect(Validators.title('  '), 'Enter a title.');
    expect(
      Validators.title('t' * (Validators.titleMaximum + 1)),
      'A title is at most ${Validators.titleMaximum} characters long.',
    );
  });
}
