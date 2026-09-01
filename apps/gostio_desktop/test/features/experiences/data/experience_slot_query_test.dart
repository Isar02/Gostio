import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot_query.dart';

void main() {
  test('a window nobody set is left out of the request', () {
    const ExperienceSlotQuery query = ExperienceSlotQuery();

    expect(query.toParameters(), isEmpty);
    expect(query.isEmpty, isTrue);
  });

  test('the first day of the window starts at its own midnight', () {
    final ExperienceSlotQuery query = ExperienceSlotQuery(
      from: DateTime(2026, 3, 4),
    );

    expect(_sent(query, 'from'), DateTime(2026, 3, 4));
  });

  // The API matches the moment a term starts, so a window ending on a day has
  // to reach the end of it: a term at six in the evening is on that day.
  test('the last day of the window reaches the end of that day', () {
    final ExperienceSlotQuery query = ExperienceSlotQuery(
      to: DateTime(2026, 3, 4),
    );

    expect(
      _sent(query, 'to'),
      DateTime(2026, 3, 5).subtract(const Duration(microseconds: 1)),
    );
  });

  test('a moment is written in UTC, which is what the API holds', () {
    final ExperienceSlotQuery query = ExperienceSlotQuery(
      from: DateTime(2026, 3, 4),
    );

    expect(query.toParameters()['from'] as String, endsWith('Z'));
  });

  test('the open flag is a filter of its own', () {
    const ExperienceSlotQuery query = ExperienceSlotQuery(isActive: false);

    expect(query.toParameters(), <String, dynamic>{'isActive': false});
  });
}

DateTime _sent(ExperienceSlotQuery query, String edge) =>
    DateTime.parse(query.toParameters()[edge] as String).toLocal();
