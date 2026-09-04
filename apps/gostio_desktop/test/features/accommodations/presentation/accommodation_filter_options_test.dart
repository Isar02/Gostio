import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_filter_options.dart';

import '../../../support/reference_double.dart';

void main() {
  test('a table that could not be read says what the API said', () async {
    await expectLater(
      AccommodationFilterOptions.load(_FailingReference()),
      throwsA(
        isA<ApiException>().having(
          (ApiException failure) => failure.message,
          'message',
          'The cities could not be read.',
        ),
      ),
    );
  });
}

class _FailingReference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> cities() async =>
      throw const ApiException(message: 'The cities could not be read.');

  @override
  Future<List<LookupItem>> accommodationTypes() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> accommodationCategories() async =>
      const <LookupItem>[];

  @override
  Future<List<LookupItem>> amenities() async => const <LookupItem>[];
}
