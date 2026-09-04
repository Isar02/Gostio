import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_applications_repository.dart';
import 'package:gostio_desktop/features/host_applications/presentation/host_application_detail_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/application_fixture.dart';

void main() {
  testWidgets('a request nobody has answered offers both moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Applications()));
    await tester.pumpAndSettle();

    expect(_approve(tester).onPressed, isNotNull);
    expect(_reject(tester).onPressed, isNotNull);
    expect(find.text('Nobody has answered this yet.'), findsOneWidget);
  });

  // The server answers a request once and refuses a second answer, so neither
  // move is offered on one that already has an answer.
  testWidgets('an answered request says why neither move is offered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _Applications(
          request: application(
            status: 'Approved',
            reviewedByName: 'Emir Hodžić',
            reviewedAt: DateTime.utc(2026, 8, 22, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_approve(tester).onPressed, isNull);
    expect(_reject(tester).onPressed, isNull);
    expect(find.byTooltip('This request is already approved.'), findsOneWidget);
    expect(find.text('None was given.'), findsOneWidget);
  });

  testWidgets('turning a request down demands the reason the server does', (
    WidgetTester tester,
  ) async {
    final _Applications applications = _Applications();

    await tester.pumpWidget(_screen(applications));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turn down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn down'));
    await tester.pumpAndSettle();

    expect(find.text('Say why the request is being turned down.'), findsOne);
    expect(applications.rejections, isEmpty);

    await tester.enterText(
      find.byType(TextFormField),
      'The address could not be verified.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Turn down'));
    await tester.pumpAndSettle();

    expect(applications.rejections, <String>[
      'The address could not be verified.',
    ]);
  });

  // The server takes an approval with no reason at all, so the dialog does
  // too, and nothing is sent where nothing was typed.
  testWidgets('an approval goes through without a reason', (
    WidgetTester tester,
  ) async {
    final _Applications applications = _Applications();

    await tester.pumpWidget(_screen(applications));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();

    expect(applications.approvals, <String?>[null]);
    expect(_approve(tester).onPressed, isNull);
  });

  testWidgets('a refused decision keeps the dialog and the server word', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Applications(refusing: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pumpAndSettle();

    expect(
      find.text('This request has already been answered. Read it again.'),
      findsOneWidget,
    );
    expect(find.text('Approve this application?'), findsOneWidget);
  });

  // Leaving mid-write would hand the list a row about to be wrong, and the
  // refusal a write can come back with has nowhere to be said once the dialog
  // holding it is gone.
  testWidgets('a decision in flight holds the screen it is written on', (
    WidgetTester tester,
  ) async {
    final _Applications applications = _Applications(holdsTheWrite: true);

    await tester.pumpWidget(_screen(applications));
    await tester.pumpAndSettle();

    expect(_back(tester).onPressed, isNotNull);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('Approve this application?'), findsOneWidget);
    expect(_back(tester).onPressed, isNull);

    applications.releaseTheWrite();
    await tester.pumpAndSettle();

    expect(_back(tester).onPressed, isNotNull);
  });

  testWidgets('a request that could not be read empties the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Applications(readFails: true)));
    await tester.pumpAndSettle();

    expect(find.text('This request could not be read.'), findsOneWidget);
    expect(find.text('Trace 9f2c41'), findsOneWidget);
  });
}

// The header's, which is the first of the two once a dialog is open over it.
FilledButton _approve(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton).first);

OutlinedButton _reject(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byType(OutlinedButton));

IconButton _back(WidgetTester tester) => tester.widget<IconButton>(
  find.widgetWithIcon(IconButton, Icons.arrow_back),
);

Widget _screen(_Applications applications) =>
    Provider<HostApplicationsRepository>.value(
      value: applications,
      child: const MaterialApp(
        home: Scaffold(body: HostApplicationDetailScreen(applicationId: 5)),
      ),
    );

class _Applications implements HostApplicationsRepository {
  _Applications({
    HostApplication? request,
    this.readFails = false,
    this.refusing = false,
    this.holdsTheWrite = false,
  }) : _request = request ?? application();

  HostApplication _request;
  final bool readFails;
  final bool refusing;

  // Held open so a test can stand in the moment the write is still running.
  final bool holdsTheWrite;
  final Completer<void> _write = Completer<void>();

  final List<String?> approvals = <String?>[];
  final List<String> rejections = <String>[];

  void releaseTheWrite() => _write.complete();

  @override
  Future<HostApplication> get(int id) async {
    if (readFails) {
      throw const ApiException(
        message: 'This request could not be read.',
        statusCode: 500,
        traceId: '9f2c41',
      );
    }

    return _request;
  }

  @override
  Future<HostApplication> approve(int id, {String? reason}) async {
    await _held();

    if (refusing) {
      throw const ApiException(
        message: 'This request has already been answered. Read it again.',
        statusCode: 400,
      );
    }

    approvals.add(reason);
    _request = application(status: 'Approved', reviewedByName: 'Desktop');

    return _request;
  }

  @override
  Future<HostApplication> reject(int id, {required String reason}) async {
    await _held();
    rejections.add(reason);
    _request = application(
      status: 'Rejected',
      reviewedByName: 'Desktop',
      decisionReason: reason,
    );

    return _request;
  }

  @override
  Future<PagedResult<HostApplication>> search({
    required HostApplicationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) => throw UnimplementedError();

  Future<void> _held() async {
    if (holdsTheWrite) {
      await _write.future;
    }
  }
}
