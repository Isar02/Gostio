import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/password_draft.dart';
import 'package:gostio_mobile/features/profile/data/profile_draft.dart';
import 'package:gostio_mobile/features/profile/data/profile_repository.dart';

import 'account_fixture.dart';

// The account this token belongs to, answered without a server. Every write is
// recorded and every one of them may be held open, which is how a test says
// what a second write does while the first is still out.
class ProfileDouble implements ProfileRepository {
  ProfileDouble({
    User? holds,
    this.readFailure,
    this.updateFailure,
    this.pictureFailure,
    this.passwordFailure,
    this.renewedToken = 'the-renewed-token',
    this.holdsReads,
    this.holdsWrites,
  }) : _account = holds ?? account();

  final ApiException? readFailure;
  final ApiException? updateFailure;
  final ApiException? pictureFailure;
  final ApiException? passwordFailure;
  final String renewedToken;

  // A read waits here after taking its snapshot. This lets a test order the
  // answer independently of a write that started before or after it.
  final Completer<void>? holdsReads;

  // A write waits on this before it answers. Nothing is held where it is null.
  final Completer<void>? holdsWrites;

  int reads = 0;
  ProfileDraft? saved;
  ImageUpload? pictureWritten;
  bool wasPictureCleared = false;
  PasswordDraft? passwordSent;

  User _account;

  @override
  Future<User> mine() async {
    reads++;
    final User read = _account;

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    await holdsReads?.future;

    return read;
  }

  @override
  Future<User> update(ProfileDraft draft) async {
    await _held();
    saved = draft;

    if (updateFailure case final ApiException refused) {
      throw refused;
    }

    return _account = User(
      id: _account.id,
      firstName: draft.firstName,
      lastName: draft.lastName,
      username: _account.username,
      email: draft.email,
      phoneNumber: draft.phoneNumber,
      hasProfileImage: _account.hasProfileImage,
      isActive: _account.isActive,
      roles: _account.roles,
      createdAt: _account.createdAt,
    );
  }

  @override
  Future<User> setPicture(ImageUpload picture) async {
    await _held();
    pictureWritten = picture;

    if (pictureFailure case final ApiException refused) {
      throw refused;
    }

    return _account = _withPicture(hasPicture: true);
  }

  @override
  Future<User> clearPicture() async {
    await _held();
    wasPictureCleared = true;

    if (pictureFailure case final ApiException refused) {
      throw refused;
    }

    return _account = _withPicture(hasPicture: false);
  }

  @override
  Future<void> changePassword(
    PasswordDraft draft, {
    required void Function(String token) adopt,
  }) async {
    await _held();
    passwordSent = draft;

    if (passwordFailure case final ApiException refused) {
      throw refused;
    }

    adopt(renewedToken);
  }

  Future<void> _held() async => holdsWrites?.future;

  User _withPicture({required bool hasPicture}) => User(
    id: _account.id,
    firstName: _account.firstName,
    lastName: _account.lastName,
    username: _account.username,
    email: _account.email,
    phoneNumber: _account.phoneNumber,
    hasProfileImage: hasPicture,
    isActive: _account.isActive,
    roles: _account.roles,
    createdAt: _account.createdAt,
  );
}
