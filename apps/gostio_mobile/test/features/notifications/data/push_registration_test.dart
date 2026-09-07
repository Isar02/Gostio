import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/notifications/data/push_registration.dart';

import '../../../support/notifications_double.dart';
import '../../../support/push_double.dart';

void main() {
  test('the device is registered when the session begins', () async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushRegistration registration = PushRegistration(
      notifications,
      PushMessagingDouble(token: 'device-token'),
    );

    await registration.start();

    expect(notifications.registered, <String>['device-token']);

    await registration.close();
  });

  // A build with no messaging configuration answers no token. Nothing is
  // registered and nothing else about the client changes.
  test('a device with no token registers nothing', () async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushRegistration registration = PushRegistration(
      notifications,
      PushMessagingDouble(),
    );

    await registration.start();

    expect(notifications.registered, isEmpty);

    await registration.close();
  });

  // The service rotates a token on reinstall and on its own schedule. A client
  // that registers once and never listens goes quiet without ever failing.
  test('a rotated token is registered again', () async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushMessagingDouble messaging = PushMessagingDouble(
      token: 'first-token',
    );
    final PushRegistration registration = PushRegistration(
      notifications,
      messaging,
    );

    await registration.start();
    messaging.tokens.add('second-token');
    await Future<void>.delayed(Duration.zero);

    expect(notifications.registered, <String>['first-token', 'second-token']);

    await registration.close();
  });

  test('a rotated token replaces the previous server registration', () async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushMessagingDouble messaging = PushMessagingDouble(
      token: 'first-token',
    );
    final PushRegistration registration = PushRegistration(
      notifications,
      messaging,
    );

    await registration.start();
    messaging.tokens.add('second-token');
    await Future<void>.delayed(Duration.zero);
    await registration.forget();

    expect(notifications.forgotten, <String>['first-token', 'second-token']);

    await registration.close();
  });

  // A phone is handed between people, and a registration left behind delivers
  // this account's bookings to whoever holds the phone next.
  test('signing out gives the registration up', () async {
    final NotificationsDouble notifications = NotificationsDouble();
    final PushRegistration registration = PushRegistration(
      notifications,
      PushMessagingDouble(token: 'device-token'),
    );

    await registration.start();
    await registration.forget();

    expect(notifications.forgotten, <String>['device-token']);
    expect(registration.deviceToken, isNull);

    await registration.close();
  });

  // A rotation that lands after the reader has gone would put the device back
  // on an account that has just left it.
  test(
    'a rotation after the registration was given up registers nothing',
    () async {
      final NotificationsDouble notifications = NotificationsDouble();
      final PushMessagingDouble messaging = PushMessagingDouble(
        token: 'first-token',
      );
      final PushRegistration registration = PushRegistration(
        notifications,
        messaging,
      );

      await registration.start();
      await registration.forget();
      messaging.tokens.add('second-token');
      await Future<void>.delayed(Duration.zero);

      expect(notifications.registered, <String>['first-token']);

      await registration.close();
    },
  );

  // A refused registration is a deployment or a network fault. Nothing on the
  // screen is waiting for its answer and nothing may be thrown at the session.
  test('a refused registration is not thrown at the client', () async {
    final NotificationsDouble notifications = NotificationsDouble(
      deviceFailure: const ApiException(
        message: 'The API could not be reached.',
      ),
    );
    final PushRegistration registration = PushRegistration(
      notifications,
      PushMessagingDouble(token: 'device-token'),
    );

    await registration.start();

    expect(notifications.registered, <String>['device-token']);
    expect(registration.deviceToken, isNull);

    await registration.close();
  });

  // The registration is written after the reader has already left, which is
  // the one window where giving it up cannot find anything to give up. The
  // device would otherwise stay registered to an account that has gone.
  test(
    'a registration that lands after the reader left is taken back',
    () async {
      final _HeldRegistration notifications = _HeldRegistration();
      final PushRegistration registration = PushRegistration(
        notifications,
        PushMessagingDouble(token: 'device-token'),
      );

      final Future<void> starting = registration.start();
      await notifications.reached;
      final Future<void> givingUp = registration.forget();
      notifications.answer();
      await givingUp;
      await starting;

      expect(notifications.registered, <String>['device-token']);
      expect(notifications.forgotten, <String>['device-token']);
      expect(registration.deviceToken, isNull);

      await registration.close();
    },
  );
}

// Holds the registration until a test says the server answered, which is what
// lets the reader sign out while it is still in flight.
class _HeldRegistration extends NotificationsDouble {
  final Completer<void> _reached = Completer<void>();
  final Completer<void> _answer = Completer<void>();

  Future<void> get reached => _reached.future;

  void answer() => _answer.complete();

  @override
  Future<void> registerDevice(String token) async {
    if (!_reached.isCompleted) {
      _reached.complete();
    }

    await _answer.future;
    await super.registerDevice(token);
  }
}
