import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/auth/data/account_registration.dart';
import 'package:gostio_mobile/features/auth/data/auth_repository.dart';

import 'account_fixture.dart';

// The five calls the session is made and unmade through. Each records what it
// was given and answers what the server would; a test that wants a refusal
// names the failure rather than the call being stubbed twice.
class AuthDouble implements AuthRepository {
  AuthDouble({
    User? user,
    this.failure,
    this.holdsTheCall = false,
    this.signOutFails = false,
  }) : _user = user ?? account();

  final ApiException? failure;

  // A call that does not answer until a test says so, which is how a screen is
  // looked at while it is busy.
  final bool holdsTheCall;

  final bool signOutFails;

  final Completer<void> _answer = Completer<void>();

  User _user;

  void answer() => _answer.complete();

  String? usernameSent;
  String? passwordSent;
  AccountRegistration? registered;
  String? addressAsked;
  String? codeSent;
  String? newPasswordSent;
  int meCalls = 0;
  bool wasSignedOut = false;

  @override
  Future<AuthResult> signIn({
    required String username,
    required String password,
  }) async {
    await _held();
    _refuseIfAsked();

    usernameSent = username;
    passwordSent = password;

    return issuedTo(_user);
  }

  @override
  Future<AuthResult> register(AccountRegistration registration) async {
    await _held();
    _refuseIfAsked();

    registered = registration;
    _user = account(
      firstName: registration.firstName,
      lastName: registration.lastName,
      username: registration.username,
      email: registration.email,
      phoneNumber: registration.phoneNumber,
    );

    return issuedTo(_user);
  }

  @override
  Future<User> me() async {
    await _held();
    _refuseIfAsked();

    meCalls++;

    return _user;
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _held();
    _refuseIfAsked();

    addressAsked = email;
  }

  @override
  Future<void> resetPassword({
    required String code,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await _held();
    _refuseIfAsked();

    codeSent = code;
    newPasswordSent = newPassword;
  }

  @override
  Future<void> signOut() async {
    if (signOutFails) {
      throw const ApiException(
        message: 'The API could not be reached.',
        statusCode: 503,
      );
    }

    wasSignedOut = true;
  }

  Future<void> _held() async {
    if (holdsTheCall) {
      await _answer.future;
    }
  }

  void _refuseIfAsked() {
    if (failure case final ApiException refused) {
      throw refused;
    }
  }
}
