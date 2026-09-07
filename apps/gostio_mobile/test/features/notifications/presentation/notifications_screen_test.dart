import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/state/foreground_poll.dart';
import 'package:gostio_mobile/features/notifications/presentation/notifications_notifier.dart';
import 'package:gostio_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/auth_double.dart';
import '../../../support/notice_fixture.dart';
import '../../../support/notifications_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

// What a notice opened, recorded rather than drawn: the screen is handed the
// opener because the booking a notice names is another feature's.
final List<int> opened = <int>[];

void main() {
  setUp(usePhoneScreen);

  setUp(opened.clear);

  Future<void> open(
    WidgetTester tester,
    NotificationsDouble notifications,
  ) async {
    await tester.pumpWidget(
      underTest(
        NotificationsScreen(
          openBooking: (BuildContext context, int reservationId) async =>
              opened.add(reservationId),
        ),
        auth: AuthDouble(),
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();
  }

  // A list twenty rows long ends below the fold, and a row that has not been
  // built is a row no finder can see.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.pumpAndSettle();
  }

  testWidgets('a notice is drawn with what raised it and when', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        rows: <AppNotification>[
          notice(
            title: 'Payment received',
            body: 'Your payment for the stay in Mostar went through.',
            kind: NotificationKind.paymentSucceeded,
          ),
        ],
      ),
    );

    expect(find.text('Payment received'), findsOneWidget);
    expect(
      find.text('Your payment for the stay in Mostar went through.'),
      findsOneWidget,
    );
    expect(find.text('2 h ago'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  // Unread is a state the row is read in, so it is said in a word rather than
  // in a weight alone.
  testWidgets('only what has not been read is marked unread', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        rows: <AppNotification>[
          notice(id: 1, title: 'Newest'),
          notice(id: 2, title: 'Older', isRead: true),
        ],
      ),
    );

    expect(find.text('Unread'), findsOneWidget);
  });

  testWidgets('an account with nothing waiting is told so', (
    WidgetTester tester,
  ) async {
    await open(tester, NotificationsDouble());

    expect(find.text('Nothing to report'), findsOneWidget);
  });

  testWidgets('the footer says how much of the whole is held', (
    WidgetTester tester,
  ) async {
    await open(tester, NotificationsDouble(rows: notices(25)));
    await scrollTo(tester, find.text('20 of 25 notifications'));

    expect(find.text('20 of 25 notifications'), findsOneWidget);
  });

  // A page is asked for rather than taken by scrolling, and what is already
  // read stays where it is when the next one arrives.
  testWidgets('asking for more adds the next page to what is read', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: notices(25),
    );
    await open(tester, notifications);

    await scrollTo(tester, find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('25 of 25 notifications'));

    expect(notifications.pagesAsked, <int>[1, 2]);
    expect(find.text('25 of 25 notifications'), findsOneWidget);
  });

  testWidgets('a refused read is said with the trace it can be found by', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        failure: const ApiException(
          message: 'The API could not be reached.',
          traceId: '00-abc-def-01',
        ),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Trace 00-abc-def-01'), findsOneWidget);
  });

  testWidgets('another go repeats the read that was refused', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      failure: const ApiException(message: 'The API could not be reached.'),
    );
    await open(tester, notifications);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(notifications.pagesAsked, <int>[1, 1]);
  });

  // Opening a notice is reading it, so one gesture does both. The row the
  // server answers is what the list draws from then on.
  testWidgets('a notice tapped is marked read and opens what it names', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      unread: 1,
      rows: <AppNotification>[notice(id: 9, reservationId: 314)],
      read: notice(id: 9, title: 'Booking confirmed', isRead: true),
    );
    await open(tester, notifications);

    await tester.tap(find.text('Booking confirmed'));
    await tester.pumpAndSettle();

    expect(notifications.markedRead, <int>[9]);
    expect(opened, <int>[314]);
    expect(find.text('Unread'), findsNothing);
  });

  // A write that changes nothing is a write nobody asked for.
  testWidgets('a notice already read is opened without being marked again', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: <AppNotification>[
        notice(id: 9, title: 'Payment received', isRead: true),
      ],
    );
    await open(tester, notifications);

    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();

    expect(notifications.markedRead, isEmpty);
    expect(opened, <int>[314]);
  });

  // A read notice that names nothing has neither gesture left, and a card that
  // offers one it cannot perform is a card that lied.
  testWidgets('a read notice naming no booking answers no tap', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        rows: <AppNotification>[
          notice(
            id: 9,
            title: 'You are verified',
            kind: NotificationKind.hostVerificationDecided,
            isRead: true,
            reservationId: null,
          ),
        ],
      ),
    );

    await tester.tap(find.text('You are verified'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
  });

  // The one it does still have: an unread notice about nothing is still read
  // by the gesture that reads every other one.
  testWidgets('an unread notice naming no booking is still marked read', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      unread: 1,
      rows: <AppNotification>[
        notice(
          id: 9,
          title: 'You are verified',
          kind: NotificationKind.hostVerificationDecided,
          reservationId: null,
        ),
      ],
      read: notice(
        id: 9,
        title: 'You are verified',
        kind: NotificationKind.hostVerificationDecided,
        isRead: true,
        reservationId: null,
      ),
    );
    await open(tester, notifications);

    await tester.tap(find.text('You are verified'));
    await tester.pumpAndSettle();

    expect(notifications.markedRead, <int>[9]);
    expect(opened, isEmpty);
  });

  // Every notice on the account is marked, including the ones below what has
  // been loaded, so the list is read again rather than rewritten here.
  testWidgets('marking everything read is agreed to and reads the list again', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      unread: 4,
      rows: notices(3),
    );
    await open(tester, notifications);

    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(notifications.markAllCalls, 1);
    expect(notifications.pagesAsked, <int>[1, 1]);
  });

  testWidgets('nothing is marked where the reader did not agree', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      unread: 4,
      rows: notices(3),
    );
    await open(tester, notifications);

    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(notifications.markAllCalls, 0);
  });

  // The action stays where it is and says why it is not offered, rather than
  // leaving the bar a different shape on every visit.
  testWidgets('with nothing unread the bulk action is offered but dead', (
    WidgetTester tester,
  ) async {
    await open(tester, NotificationsDouble(rows: notices(3)));

    final IconButton action = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.done_all_rounded),
        matching: find.byType(IconButton),
      ),
    );

    expect(action.onPressed, isNull);
    expect(action.tooltip, 'Nothing is unread');
  });

  // A read that was refused and a write that was refused are two answers, and
  // only the second leaves the rows where they are.
  testWidgets('a refused write is said over the rows it did not change', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        unread: 1,
        rows: <AppNotification>[notice(id: 9, title: 'Booking confirmed')],
        writeFailure: const ApiException(
          message: 'That notice could not be marked read.',
        ),
      ),
    );

    await tester.tap(find.text('Booking confirmed'));
    await tester.pumpAndSettle();

    expect(find.text('That notice could not be marked read.'), findsOneWidget);
    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
  });

  // The list is the one screen in this client where something can arrive while
  // the reader is looking at it. A manual pull is not an answer to that: it
  // reads itself on the same interval the count is read on.
  testWidgets('the list reads itself again while it is open', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: notices(3),
    );
    await open(tester, notifications);

    expect(notifications.pagesAsked, <int>[1]);

    await tester.pump(ForegroundPoll.interval);
    await tester.pumpAndSettle();

    expect(notifications.pagesAsked, <int>[1, 1]);
  });

  // A phone in a pocket is not reading a list, and a timer behind the reader
  // spends battery to learn nothing.
  testWidgets('nothing is read while the application is in the background', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: notices(3),
    );
    await open(tester, notifications);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(ForegroundPoll.interval * 3);
    await tester.pumpAndSettle();

    expect(notifications.pagesAsked, <int>[1]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(notifications.pagesAsked, <int>[1, 1]);
  });

  // A notice that arrived shows up where the server put it, and one read
  // somewhere else catches up — without the reader being sent back to the
  // first page of a list they have asked for more of.
  testWidgets('what arrives is merged into what the reader is holding', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: notices(25),
    );
    await open(tester, notifications);

    await scrollTo(tester, find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('25 of 25 notifications'));

    notifications.rows = <AppNotification>[
      notice(id: 99, title: 'Booking confirmed'),
      ...notices(25),
    ];
    await tester.pump(ForegroundPoll.interval);
    await tester.pumpAndSettle();

    // The second page is still held, so the footer counts twenty-six rather
    // than going back to the twenty a reload would leave.
    await scrollTo(tester, find.text('26 of 26 notifications'));

    expect(find.text('26 of 26 notifications'), findsOneWidget);
  });

  testWidgets('an older poll cannot restore a row marked read after it began', (
    WidgetTester tester,
  ) async {
    final _HeldSearch notifications = _HeldSearch(
      rows: <AppNotification>[notice(id: 9)],
      read: notice(id: 9, isRead: true),
    );
    await open(tester, notifications);
    final BuildContext context = tester.element(find.text('Notifications'));
    final NotificationsNotifier notifier = context
        .read<NotificationsNotifier>();

    notifications.holdNextSearch();
    final Future<void> catchingUp = notifier.catchUp();
    await notifications.searchReached;
    await notifier.markRead(notifier.items.single);
    notifications.answerSearch();
    await catchingUp;

    expect(notifier.items.single.isRead, isTrue);
  });
}

class _HeldSearch extends NotificationsDouble {
  _HeldSearch({required super.rows, required super.read});

  Completer<void>? _reached;
  Completer<void>? _answer;

  late Future<void> searchReached;

  void holdNextSearch() {
    _reached = Completer<void>();
    _answer = Completer<void>();
    searchReached = _reached!.future;
  }

  void answerSearch() => _answer!.complete();

  @override
  Future<PagedResult<AppNotification>> search({
    required int page,
    required int pageSize,
  }) async {
    final Completer<void>? reached = _reached;
    final Completer<void>? answer = _answer;
    if (reached == null || answer == null) {
      return super.search(page: page, pageSize: pageSize);
    }

    final List<AppNotification> snapshot = List<AppNotification>.of(rows);
    pagesAsked.add(page);
    reached.complete();
    await answer.future;
    _reached = null;
    _answer = null;

    final int from = ((page - 1) * pageSize).clamp(0, snapshot.length);
    final int to = (from + pageSize).clamp(0, snapshot.length);
    return PagedResult<AppNotification>(
      items: snapshot.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: snapshot.length,
    );
  }
}
