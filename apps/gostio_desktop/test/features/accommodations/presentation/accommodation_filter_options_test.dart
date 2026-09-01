import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_filter_options.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';

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

class _FailingReference implements ReferenceRepository {
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

  @override
  Future<List<LookupItem>> experienceCategories() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> countries() async => const <LookupItem>[];

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();
}
