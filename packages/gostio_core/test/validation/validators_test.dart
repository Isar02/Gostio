import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

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

  test('a name and a username name their limits the server way', () {
    expect(Validators.firstName('  '), 'Enter a first name.');
    expect(Validators.lastName('  '), 'Enter a last name.');
    expect(
      Validators.firstName('n' * (Validators.nameMaximum + 1)),
      'A first name is at most ${Validators.nameMaximum} characters long.',
    );
    expect(Validators.accountUsername('  '), 'Enter a username.');
    expect(
      Validators.accountUsername('lamija h'),
      'A username holds letters, digits, dots, dashes and underscores.',
    );
    expect(Validators.accountUsername('lamija.h-2_x'), isNull);
  });

  test('an address is refused in the server sentence', () {
    expect(Validators.emailAddress(''), 'Enter an email address.');
    expect(
      Validators.emailAddress('lamija.at.gostio'),
      'This is not an email address.',
    );
    expect(Validators.emailAddress('lamija.h@gostio.test'), isNull);
  });

  // The server reads separators as nothing and a nine-digit local number as
  // Bosnian, so both shapes it stores are accepted here.
  test('a phone number is read the way the server reads it', () {
    expect(Validators.phoneNumber(null), isNull);
    expect(Validators.phoneNumber('061 234 567'), isNull);
    expect(Validators.phoneNumber('+387 61 234 567'), isNull);
    expect(Validators.phoneNumber('+49 170 1234567'), isNull);
    expect(Validators.phoneNumber('61 234 567'), Validators.phoneNumberMeans);
    expect(Validators.phoneNumber('+0387612345'), Validators.phoneNumberMeans);
  });

  test('a password names the bounds the server holds', () {
    expect(
      Validators.newPassword('', missing: 'Enter a password.'),
      'Enter a password.',
    );
    expect(
      Validators.newPassword('short', missing: 'Enter a password.'),
      'A password is at least ${Validators.passwordMinimumLength} characters '
      'long.',
    );
    expect(
      Validators.newPassword('a good long one', missing: 'Enter a password.'),
      isNull,
    );
    expect(
      Validators.newPassword(
        'ž' * Validators.passwordMaximumBytes,
        missing: 'Enter a password.',
      ),
      isNotNull,
    );
  });

  test('a repeat that does not match is refused in the server words', () {
    expect(
      Validators.repeatedPassword('', 'one', missing: 'Repeat the password.'),
      'Repeat the password.',
    );
    expect(
      Validators.repeatedPassword(
        'another',
        'one',
        missing: 'Repeat the password.',
      ),
      'The two passwords do not match.',
    );
    expect(
      Validators.repeatedPassword('one', 'one', missing: 'Repeat it.'),
      isNull,
    );
  });

  // A rejection has to say why and an approval does not, which is the only
  // thing that differs between the two decisions.
  test('a decision demands a reason only where the server does', () {
    expect(
      Validators.rejectionReason('  '),
      'Say why the request is being turned down.',
    );
    expect(Validators.decisionNote('  '), isNull);
    expect(
      Validators.decisionNote('r' * (Validators.reasonMaximum + 1)),
      'A reason is at most ${Validators.reasonMaximum} characters long.',
    );
  });
}
