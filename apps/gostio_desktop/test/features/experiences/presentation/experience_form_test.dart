import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/features/experiences/data/experience.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_detail_notifier.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_form.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';

import '../../../support/bookings_double.dart';

void main() {
  testWidgets('an experience is not created until the lists answer', (
    WidgetTester tester,
  ) async {
    final _Repositories repositories = _Repositories();
    final ExperienceDetailNotifier notifier = await _notifier(repositories);

    await tester.pumpWidget(_form(notifier));
    await tester.tap(find.text('Create experience'));
    await tester.pump();

    expect(repositories.created, isNull);
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Enter a meeting point.'), findsOneWidget);
    expect(
      find.text('Choose the category this experience belongs to.'),
      findsOneWidget,
    );
    expect(find.text('Choose the place on the map.'), findsOneWidget);
  });

  testWidgets('editing writes back every field the experience owns', (
    WidgetTester tester,
  ) async {
    final _Repositories repositories = _Repositories();
    final ExperienceDetailNotifier notifier = await _notifier(
      repositories,
      experienceId: 12,
    );

    await tester.pumpWidget(_form(notifier));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final ExperienceDraft? written = repositories.updated;

    expect(written, isNotNull);
    expect(written!.title, 'Rafting the Neretva canyon');
    expect(written.cityId, 11);
    expect(written.experienceCategoryId, 3);
    expect(written.meetingPoint, 'The old bridge in Konjic');
    expect(written.durationMinutes, 240);
    expect(written.pricePerPerson, 85.5);
    expect(repositories.updatedActive, isTrue);
  });

  // The API holds minutes, and a term on a calendar is read in hours.
  testWidgets('the duration typed in minutes is read back in hours', (
    WidgetTester tester,
  ) async {
    final ExperienceDetailNotifier notifier = await _notifier(_Repositories());

    await tester.pumpWidget(_form(notifier));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration'),
      '90',
    );
    await tester.pump();

    expect(find.text('1 h 30 min'), findsOneWidget);
  });

  testWidgets('an experience with a booking cannot be deleted', (
    WidgetTester tester,
  ) async {
    final ExperienceDetailNotifier notifier = await _notifier(
      _Repositories(bookings: 2),
      experienceId: 12,
    );

    await tester.pumpWidget(_form(notifier));

    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });
}

Future<ExperienceDetailNotifier> _notifier(
  _Repositories repositories, {
  int? experienceId,
}) async {
  final ExperienceDetailNotifier notifier = ExperienceDetailNotifier(
    repositories,
    repositories,
    repositories,
    _Bookings(repositories.bookings),
    experienceId: experienceId,
    asAdministrator: false,
  );

  await notifier.load();

  return notifier;
}

Widget _form(ExperienceDetailNotifier notifier) => MaterialApp(
  home: Scaffold(
    body: ExperienceForm(
      notifier: notifier,
      onSaved: (Experience _) {},
      onDeleted: (Experience _) {},
    ),
  ),
);

class _Repositories
    implements ExperiencesRepository, ReferenceRepository, UsersRepository {
  _Repositories({this.bookings = 0});

  final int bookings;

  ExperienceDraft? created;
  ExperienceDraft? updated;
  bool? updatedActive;

  @override
  Future<Experience> get(int id) async => _experience();

  @override
  Future<List<LookupItem>> titles({int? hostId}) => throw UnimplementedError();

  @override
  Future<Experience> create(ExperienceDraft draft, {int? hostId}) async {
    created = draft;

    return _experience();
  }

  @override
  Future<Experience> update(
    int id,
    ExperienceDraft draft, {
    required bool isActive,
  }) async {
    updated = draft;
    updatedActive = isActive;

    return _experience();
  }

  @override
  Future<void> delete(int id) async {}

  @override
  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();

  @override
  Future<List<LookupItem>> cities() async => <LookupItem>[
    const LookupItem(id: 11, name: 'Konjic'),
  ];

  @override
  Future<List<LookupItem>> experienceCategories() async => <LookupItem>[
    const LookupItem(id: 3, name: 'Adventure'),
  ];

  @override
  Future<List<LookupItem>> accommodationTypes() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> accommodationCategories() async =>
      const <LookupItem>[];

  @override
  Future<List<LookupItem>> amenities() async => const <LookupItem>[];

  @override
  Future<List<LookupItem>> countries() async => const <LookupItem>[];

  @override
  Future<LookupItem> addCity({required String name, required int countryId}) =>
      throw UnimplementedError();

  @override
  Future<List<User>> hosts() async => const <User>[];

  @override
  Future<List<LookupItem>> reservationStatuses() async => const <LookupItem>[];
}

// The bookings against the experience are read through their own repository,
// which answers get and search where the catalogue answers the same two names.
class _Bookings extends BookingsDouble {
  const _Bookings(this._held);

  final int _held;

  @override
  Future<int> countForExperience(int experienceId) async => _held;
}

Experience _experience() => Experience(
  id: 12,
  hostId: 7,
  hostName: 'Host',
  title: 'Rafting the Neretva canyon',
  description: 'Down the green water.',
  experienceCategoryId: 3,
  experienceCategoryName: 'Adventure',
  cityId: 11,
  cityName: 'Konjic',
  countryName: 'Bosnia and Herzegovina',
  meetingPoint: 'The old bridge in Konjic',
  latitude: 43.65,
  longitude: 17.96,
  durationMinutes: 240,
  pricePerPerson: 85.5,
  isActive: true,
  reviewCount: 0,
  createdAt: DateTime.utc(2026, 1, 1),
);
