import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/multi_select_field.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/users/data/user_draft.dart';
import 'package:gostio_desktop/features/users/data/users_repository.dart';
import 'package:gostio_desktop/features/users/presentation/user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/account_fixture.dart';
import '../../../support/reference_double.dart';
import '../../../support/users_double.dart';

void main() {
  testWidgets('an account is not made until the server has what it demands', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users();

    await tester.pumpWidget(_screen(users));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(users.created, isNull);
    expect(find.text('Enter a first name.'), findsOneWidget);
    expect(find.text('Enter a username.'), findsOneWidget);
    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(find.text('Enter a password.'), findsOneWidget);
    expect(find.text('Give the account at least one role.'), findsOneWidget);
  });

  // The refusal is what the form was written for, so the screen it is said on
  // has to still be there: a write that failed is not a page that could not be
  // read, and emptying the form would throw away everything typed into it.
  testWidgets('a refused create keeps the form and faults the field', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(createFails: true);

    await tester.pumpWidget(_screen(users));
    await tester.pumpAndSettle();

    await _fillTheForm(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('This username is taken.'), findsOneWidget);
  });

  // Three endpoints own three parts of an account, and a save touches only the
  // ones that moved: writing the roles again would sign the account out for
  // nothing, since the server raises the token version on that call.
  testWidgets('a save writes the fields and leaves what did not move', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account());

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'lamija@gostio.test',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(users.updated?.email, 'lamija@gostio.test');
    expect(users.writtenRoles, isNull);
    expect(users.writtenState, isNull);
  });

  testWidgets('a role that changed goes to the endpoint that owns it', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account());

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    await _chooseRole(tester, 'Administrator');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(users.updated, isNull);
    expect(users.writtenRoles, <String>['Host', 'Administrator']);
  });

  // The fields landed and the roles did not, so the account on screen is the
  // one the write that succeeded left behind and the refusal is said above it.
  testWidgets('a refusal stops the writes after it and says so', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account(), rolesFail: true);

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'lamija@gostio.test',
    );
    await _chooseRole(tester, 'Administrator');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(users.updated, isNotNull);
    expect(users.writtenState, isNull);
    expect(find.text('No role goes by Administrator.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('editing asks for no password until one is being set', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account());

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    expect(find.text('New password'), findsNothing);

    await tester.tap(find.text('Set a new password'));
    await tester.pumpAndSettle();

    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Repeat the new password'), findsOneWidget);
  });

  testWidgets('a password set with the rest goes out on its own call', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account());

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set a new password'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'a good long one',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repeat the new password'),
      'a good long one',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(users.updated, isNull);
    expect(users.writtenPassword, 'a good long one');
  });

  // A save is up to four writes and none of them has said what it did yet, so
  // the way off the screen is shut for the length of it.
  testWidgets('a save in flight holds the screen it is written on', (
    WidgetTester tester,
  ) async {
    // The write is refused so the screen stays put once it lands: a save that
    // succeeds leaves for the list, which is a different test.
    final _Users users = _Users(
      existing: account(),
      holdsTheWrite: true,
      updateFails: true,
    );

    await tester.pumpWidget(_screen(users, userId: 7));
    await tester.pumpAndSettle();

    expect(_back(tester).onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'lamija@gostio.test',
    );
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(_back(tester).onPressed, isNull);
    expect(
      find.byTooltip('The write in flight has to land first.'),
      findsOneWidget,
    );

    users.releaseTheWrite();
    await tester.pumpAndSettle();

    expect(_back(tester).onPressed, isNotNull);
  });

  // The three the server refuses against the caller's own account, refused
  // here first with the reason on them rather than pressed and answered 400.
  testWidgets('the caller is offered none of the three moves on themselves', (
    WidgetTester tester,
  ) async {
    final _Users users = _Users(existing: account(id: 4));

    await tester.pumpWidget(_screen(users, userId: 4, signedInUserId: 4));
    await tester.pumpAndSettle();

    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(_switch(tester, 'Active').onChanged, isNull);
    expect(_switch(tester, 'Set a new password').onChanged, isNull);
    expect(
      find.byTooltip(
        'An account cannot deactivate itself. Ask another administrator.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an account that could not be read empties the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Users(readFails: true), userId: 7));
    await tester.pumpAndSettle();

    expect(find.text('This account could not be read.'), findsOneWidget);
    expect(find.text('Trace 9f2c41'), findsOneWidget);
  });
}

Future<void> _fillTheForm(WidgetTester tester) async {
  for (final MapEntry<String, String> field in <String, String>{
    'First name': 'Lamija',
    'Last name': 'Hodžić',
    'Username': 'lamija.h',
    'Email': 'lamija.h@gostio.test',
    'Password': 'a good long one',
    'Repeat the password': 'a good long one',
  }.entries) {
    await tester.enterText(
      find.widgetWithText(TextFormField, field.key),
      field.value,
    );
  }

  await _chooseRole(tester, 'Host');
}

IconButton _back(WidgetTester tester) => tester.widget<IconButton>(
  find.widgetWithIcon(IconButton, Icons.arrow_back),
);

SwitchListTile _switch(WidgetTester tester, String label) =>
    tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label));

Future<void> _chooseRole(WidgetTester tester, String role) async {
  await tester.tap(find.byType(MultiSelectField<LookupItem>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role).last);
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

Widget _screen(_Users users, {int? userId, int signedInUserId = 1}) =>
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<UsersRepository>.value(value: users),
        Provider<ReferenceRepository>.value(value: _Reference()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: UserDetailScreen(
            signedInUserId: signedInUserId,
            userId: userId,
          ),
        ),
      ),
    );

class _Reference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> roles() async => const <LookupItem>[
    LookupItem(id: 1, name: 'Administrator'),
    LookupItem(id: 2, name: 'Host'),
    LookupItem(id: 3, name: 'Guest'),
  ];
}

class _Users extends UsersDouble {
  _Users({
    this.existing,
    this.readFails = false,
    this.rolesFail = false,
    this.createFails = false,
    this.holdsTheWrite = false,
    this.updateFails = false,
  });

  final User? existing;
  final bool readFails;
  final bool rolesFail;
  final bool createFails;
  final bool updateFails;

  // Held open so a test can stand in the moment a write is still running.
  final bool holdsTheWrite;
  final Completer<void> _write = Completer<void>();

  UserDraft? created;
  UserDraft? updated;
  List<String>? writtenRoles;
  bool? writtenState;
  String? writtenPassword;

  @override
  Future<User> get(int id) async {
    if (readFails) {
      throw const ApiException(
        message: 'This account could not be read.',
        statusCode: 500,
        traceId: '9f2c41',
      );
    }

    return existing!;
  }

  @override
  Future<User> create(
    UserDraft draft, {
    required String username,
    required String password,
    required String confirmPassword,
    required List<String> roles,
  }) async {
    if (createFails) {
      throw const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Username': <String>['This username is taken.'],
        },
      );
    }

    created = draft;

    return account();
  }

  void releaseTheWrite() => _write.complete();

  @override
  Future<User> update(int id, UserDraft draft) async {
    if (holdsTheWrite) {
      await _write.future;
    }

    if (updateFails) {
      throw const ApiException(
        message: 'An account already uses this address.',
        statusCode: 400,
      );
    }

    updated = draft;

    return existing!;
  }

  @override
  Future<User> setRoles(int id, List<String> roles) async {
    if (rolesFail) {
      throw const ApiException(
        message: 'No role goes by Administrator.',
        statusCode: 400,
      );
    }

    writtenRoles = roles;

    return existing!;
  }

  @override
  Future<User> setState(int id, {required bool isActive}) async {
    writtenState = isActive;

    return existing!;
  }

  @override
  Future<void> setPassword(
    int id, {
    required String password,
    required String confirmPassword,
  }) async {
    writtenPassword = password;
  }
}
