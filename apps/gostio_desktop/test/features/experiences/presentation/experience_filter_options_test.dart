import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_filter_options.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';

import '../../../support/reference_double.dart';

void main() {
  test('a table that could not be read says what the API said', () async {
    await expectLater(
      ExperienceFilterOptions.load(_FailingReference()),
      throwsA(
        isA<ApiException>().having(
          (ApiException failure) => failure.message,
          'message',
          'The categories could not be read.',
        ),
      ),
    );
  });
}

class _FailingReference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> experienceCategories() async =>
      throw const ApiException(message: 'The categories could not be read.');

  @override
  Future<List<LookupItem>> cities() async => const <LookupItem>[];
}
