import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/config/app_settings.dart';

void main() {
  test('an absolute http address is read', () {
    final SettingsResult result = AppSettings.of('http://10.0.2.2:5000');

    expect(
      (result as SettingsRead).settings.apiBaseUrl,
      Uri.parse('http://10.0.2.2:5000'),
    );
  });

  test('an https address is read', () {
    final SettingsResult result = AppSettings.of('https://api.gostio.ba');

    expect(
      (result as SettingsRead).settings.apiBaseUrl,
      Uri.parse('https://api.gostio.ba'),
    );
  });

  test('a trailing slash is dropped, so a path is joined once', () {
    final SettingsResult result = AppSettings.of('http://10.0.2.2:5000//');

    expect(
      (result as SettingsRead).settings.apiBaseUrl,
      Uri.parse('http://10.0.2.2:5000'),
    );
  });

  test('surrounding whitespace does not decide the answer', () {
    expect(AppSettings.of('  http://10.0.2.2:5000  '), isA<SettingsRead>());
  });

  test('no address at all is named as missing', () {
    final SettingsResult result = AppSettings.of('   ');

    expect(
      (result as SettingsRejected).reason,
      contains('without ${AppSettings.apiBaseUrlVariable}'),
    );
  });

  test('an address that is not http or https is refused', () {
    for (final String supplied in <String>[
      'ftp://10.0.2.2',
      '10.0.2.2:5000',
      '/api',
      'http://',
      'http://10.0.2.2:5000?tenant=1',
      'http://10.0.2.2:5000#top',
    ]) {
      expect(
        AppSettings.of(supplied),
        isA<SettingsRejected>(),
        reason: '$supplied was accepted',
      );
    }
  });

  test('what is refused says how the address is supplied', () {
    final SettingsResult result = AppSettings.of('10.0.2.2:5000');

    expect((result as SettingsRejected).reason, contains('--dart-define'));
  });
}
