import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('the two refusals a caller acts on are told apart by their code', () {
    const ApiException missing = ApiException(
      message: 'Reservation 8 has no review.',
      statusCode: 404,
    );

    expect(missing.isMissing, isTrue);
    expect(missing.isUnauthorized, isFalse);
    expect(
      const ApiException(message: 'Signed out.', statusCode: 401).isMissing,
      isFalse,
    );
  });

  test('a refusal that named no code is neither of them', () {
    const ApiException refused = ApiException(message: 'The network is out.');

    expect(refused.isMissing, isFalse);
    expect(refused.isUnauthorized, isFalse);
  });
}
