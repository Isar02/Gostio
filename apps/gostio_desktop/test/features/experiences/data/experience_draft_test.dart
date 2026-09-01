import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';

void main() {
  test('creating names a host and says nothing about publishing', () {
    expect(_draft.toCreate(hostId: 7)['hostId'], 7);
    expect(_draft.toCreate(hostId: 7).containsKey('isActive'), isFalse);
  });

  test('creating without a host leaves the caller keeping it', () {
    expect(_draft.toCreate().containsKey('hostId'), isFalse);
  });

  test('updating says whether it is published and never renames the host', () {
    final Map<String, dynamic> written = _draft.toUpdate(isActive: false);

    expect(written['isActive'], isFalse);
    expect(written.containsKey('hostId'), isFalse);
  });

  test('both endpoints carry every field the experience owns', () {
    for (final Map<String, dynamic> written in <Map<String, dynamic>>[
      _draft.toCreate(),
      _draft.toUpdate(isActive: true),
    ]) {
      expect(written['title'], 'Rafting the Neretva canyon');
      expect(written['description'], 'Down the green water.');
      expect(written['experienceCategoryId'], 3);
      expect(written['cityId'], 11);
      expect(written['meetingPoint'], 'The old bridge in Konjic');
      expect(written['latitude'], 43.65);
      expect(written['longitude'], 17.96);
      expect(written['durationMinutes'], 240);
      expect(written['pricePerPerson'], 85.5);
    }
  });
}

const ExperienceDraft _draft = ExperienceDraft(
  title: 'Rafting the Neretva canyon',
  description: 'Down the green water.',
  experienceCategoryId: 3,
  cityId: 11,
  meetingPoint: 'The old bridge in Konjic',
  latitude: 43.65,
  longitude: 17.96,
  durationMinutes: 240,
  pricePerPerson: 85.5,
);
