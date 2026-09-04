import 'dart:async';

import 'package:gostio_desktop/core/models/image_upload.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/profile/data/profile_repository.dart';
import 'package:gostio_desktop/features/users/data/user_draft.dart';

import 'account_fixture.dart';

// The account writing about itself. Each of the four calls records what it was
// given and answers what the server would; anything a test did not set up is
// refused here rather than restated as a stub.
class ProfileDouble implements ProfileRepository {
  ProfileDouble({
    User? mine,
    this.updateFails = false,
    this.passwordFails = false,
    this.holdsTheWrite = false,
    this.issuedToken = 'the-token-after-the-change',
  }) : _mine = mine ?? account();

  final bool updateFails;
  final bool passwordFails;
  final String issuedToken;

  // A save that does not answer until a test says so, which is how a second
  // write is offered one while the first is still out.
  final bool holdsTheWrite;

  final Completer<void> _write = Completer<void>();

  User _mine;

  void releaseTheWrite() => _write.complete();

  UserDraft? updated;
  ImageUpload? picture;
  bool clearedPicture = false;
  String? currentPasswordSent;
  String? newPasswordSent;

  @override
  Future<User> mine() async => _mine;

  @override
  Future<User> update(UserDraft draft) async {
    if (holdsTheWrite) {
      await _write.future;
    }

    if (updateFails) {
      throw const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Email': <String>['An account already uses this address.'],
        },
      );
    }

    updated = draft;
    _mine = account(
      firstName: draft.firstName,
      lastName: draft.lastName,
      email: draft.email,
      phoneNumber: draft.phoneNumber,
      hasProfileImage: _mine.hasProfileImage,
    );

    return _mine;
  }

  @override
  Future<User> setPicture(ImageUpload picture) async {
    this.picture = picture;
    _mine = account(hasProfileImage: true);

    return _mine;
  }

  @override
  Future<User> clearPicture() async {
    clearedPicture = true;
    _mine = account();

    return _mine;
  }

  @override
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (passwordFails) {
      throw const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'CurrentPassword': <String>['This is not your current password.'],
        },
      );
    }

    currentPasswordSent = currentPassword;
    newPasswordSent = newPassword;

    return issuedToken;
  }
}
