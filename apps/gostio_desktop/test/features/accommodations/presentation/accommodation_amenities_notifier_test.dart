import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_amenities_repository.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_amenities_notifier.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';

void main() {
  test(
    'a set toggled back to what the server holds has nothing to save',
    () async {
      final AccommodationAmenitiesNotifier amenities = await _loaded(
        _Amenities(),
      );

      amenities.toggle(3);

      expect(amenities.hasChanges, isTrue);
      expect(amenities.added, <int>{3});
      expect(amenities.chosenCount, 3);

      amenities.toggle(3);

      expect(amenities.hasChanges, isFalse);
      expect(amenities.added, isEmpty);
      expect(amenities.removed, isEmpty);
    },
  );

  test('what is added and what is removed are counted apart', () async {
    final AccommodationAmenitiesNotifier amenities = await _loaded(
      _Amenities(),
    );

    amenities
      ..toggle(3)
      ..toggle(4)
      ..toggle(1);

    expect(amenities.added, <int>{3, 4});
    expect(amenities.removed, <int>{1});
    expect(amenities.chosenCount, 3);

    amenities.discard();

    expect(amenities.hasChanges, isFalse);
    expect(amenities.chosenCount, 2);
  });

  test(
    'a refused save leaves the choice standing and names its field',
    () async {
      final _Amenities offerings = _Amenities()
        ..refusal = const ApiException(
          message: 'One or more values are not valid.',
          statusCode: 400,
          errors: <String, List<String>>{
            'AmenityIds': <String>['No amenity has the id 9.'],
          },
          traceId: 'c72f10',
        );
      final AccommodationAmenitiesNotifier amenities = await _loaded(offerings);

      amenities.toggle(3);
      await amenities.save();

      expect(amenities.failureMessage, 'No amenity has the id 9.');
      expect(amenities.failureTraceId, 'c72f10');
      expect(amenities.hasChanges, isTrue);
      expect(amenities.isChosen(3), isTrue);
    },
  );

  // The server writes the whole set and answers with it, so its answer is what
  // both sets become: a request that carried a duplicate, or one the server
  // ordered differently, would otherwise leave the tab claiming a change that
  // is not there.
  test(
    'the set the server answered with is the one the screen keeps',
    () async {
      final _Amenities offerings = _Amenities()
        ..answer = <LookupItem>[_vocabulary[0], _vocabulary[3]];
      final AccommodationAmenitiesNotifier amenities = await _loaded(offerings);

      amenities.toggle(3);
      await amenities.save();

      expect(offerings.written, <int>[1, 2, 3]);
      expect(amenities.hasChanges, isFalse);
      expect(amenities.chosenCount, 2);
      expect(amenities.isChosen(1), isTrue);
      expect(amenities.isChosen(3), isFalse);
      expect(amenities.isChosen(4), isTrue);
    },
  );

  test('removing every amenity writes an empty set', () async {
    final _Amenities offerings = _Amenities();
    final AccommodationAmenitiesNotifier amenities = await _loaded(offerings);

    amenities
      ..toggle(1)
      ..toggle(2);
    await amenities.save();

    expect(offerings.written, isEmpty);
    expect(amenities.chosenCount, isZero);
    expect(amenities.hasChanges, isFalse);
  });

  test(
    'a set that could not be read leaves the tab with the failure',
    () async {
      final _Amenities offerings = _Amenities()
        ..readFailure = const ApiException(
          message: 'The amenities could not be read.',
          statusCode: 503,
        );
      final AccommodationAmenitiesNotifier amenities = await _loaded(offerings);

      expect(amenities.failureMessage, 'The amenities could not be read.');
      expect(amenities.hasChanges, isFalse);
    },
  );
}

Future<AccommodationAmenitiesNotifier> _loaded(_Amenities offerings) async {
  final AccommodationAmenitiesNotifier amenities =
      AccommodationAmenitiesNotifier(
        offerings,
        _Reference(),
        accommodationId: 7,
      );
  await amenities.load();

  return amenities;
}

const List<LookupItem> _vocabulary = <LookupItem>[
  LookupItem(id: 1, name: 'Wi-Fi'),
  LookupItem(id: 2, name: 'Kitchen'),
  LookupItem(id: 3, name: 'Balcony'),
  LookupItem(id: 4, name: 'Heating'),
];

class _Amenities implements AccommodationAmenitiesRepository {
  List<int>? written;

  List<LookupItem>? answer;

  ApiException? refusal;

  ApiException? readFailure;

  List<LookupItem> rows = <LookupItem>[_vocabulary[0], _vocabulary[1]];

  @override
  Future<List<LookupItem>> forAccommodation(int accommodationId) async {
    if (readFailure case final ApiException refused) {
      throw refused;
    }

    return rows;
  }

  @override
  Future<List<LookupItem>> set(
    int accommodationId,
    List<int> amenityIds,
  ) async {
    if (refusal case final ApiException refused) {
      throw refused;
    }

    written = amenityIds;
    rows =
        answer ??
        <LookupItem>[
          for (final LookupItem amenity in _vocabulary)
            if (amenityIds.contains(amenity.id)) amenity,
        ];

    return rows;
  }
}

class _Reference implements ReferenceRepository {
  @override
  Future<List<LookupItem>> amenities() async => _vocabulary;

  @override
  Future<List<LookupItem>> cities() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> countries() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> accommodationTypes() => throw UnimplementedError();

  @override
  Future<List<LookupItem>> accommodationCategories() =>
      throw UnimplementedError();

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();
}
