import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../../users/data/user_draft.dart';
import '../data/profile_repository.dart';

// Three writes that do not move together: the fields, the picture and the
// password each have an endpoint, a button and a refusal of their own, so one
// that failed leaves the other two saying nothing.
class ProfileNotifier extends ScreenNotifier {
  ProfileNotifier(this._profile, this._session);

  final ProfileRepository _profile;
  final Session _session;

  bool _isLoading = true;
  bool _isSavingDetails = false;
  bool _isSavingPicture = false;
  bool _isSavingPassword = false;

  User? _account;
  ApiException? _failure;
  ApiException? _detailsFailure;
  ApiException? _pictureFailure;
  ApiException? _passwordFailure;

  bool get isLoading => _isLoading;

  bool get isSavingDetails => _isSavingDetails;

  bool get isSavingPicture => _isSavingPicture;

  bool get isSavingPassword => _isSavingPassword;

  // One write at a time, across all three. Two of them overlapping is not a
  // slow screen, it is a wrong one: a password that lands while a details save
  // is in flight raises the account's token version, and the save already on
  // its way is then answered with a 401 that ends the session — the one thing
  // this screen promises does not happen. Two writes that both answer an
  // account are the quieter half of it, where the later reply is the older
  // account and puts back what the earlier one had just changed.
  bool get isWriting =>
      _isSavingDetails || _isSavingPicture || _isSavingPassword;

  User? get account => _account;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? get detailsFailureMessage => _detailsFailure?.message;

  // The picture has one control and no field of its own to fault, so the
  // sentence about the file is preferred over the summary standing over it.
  String? get pictureFailureMessage =>
      _pictureFailure?.firstMessageFor(ProfileRepository.fileField) ??
      _pictureFailure?.message;

  String? get passwordFailureMessage => _passwordFailure?.message;

  String? detailsMessageFor(String field) =>
      _detailsFailure?.firstMessageFor(field);

  String? passwordMessageFor(String field) =>
      _passwordFailure?.firstMessageFor(field);

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    publish();

    try {
      final User read = await _profile.mine();

      // The read goes to the session too. What it is holding was answered when
      // the token was issued and an administrator may have edited the account
      // since, so this is the moment the top bar stops being older than the
      // screen under it.
      _account = read;
      _session.accountChanged(read);
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<bool> saveDetails(UserDraft draft) async {
    if (isWriting) {
      return false;
    }

    _isSavingDetails = true;
    _detailsFailure = null;
    publish();

    final bool saved = await _adopt(
      () => _profile.update(draft),
      onFailure: (ApiException failure) {
        _detailsFailure = failure;
      },
    );

    _isSavingDetails = false;
    publish();

    return saved;
  }

  Future<bool> setPicture(ImageUpload picture) =>
      _writePicture(() => _profile.setPicture(picture));

  Future<bool> clearPicture() => _writePicture(_profile.clearPicture);

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    if (isWriting) {
      return false;
    }

    _isSavingPassword = true;
    _passwordFailure = null;
    publish();

    bool changed = false;

    try {
      _session.tokenRenewed(
        await _profile.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmNewPassword: confirmNewPassword,
        ),
      );
      changed = true;
    } on ApiException catch (failure) {
      _passwordFailure = failure;
    }

    _isSavingPassword = false;
    publish();

    return changed;
  }

  Future<bool> _writePicture(Future<User> Function() write) async {
    if (isWriting) {
      return false;
    }

    _isSavingPicture = true;
    _pictureFailure = null;
    publish();

    final bool saved = await _adopt(
      write,
      onFailure: (ApiException failure) {
        _pictureFailure = failure;
      },
    );

    _isSavingPicture = false;
    publish();

    return saved;
  }

  // The account this screen holds and the one the session hands the rest of
  // the client are the same account, so a write that landed reaches both.
  Future<bool> _adopt(
    Future<User> Function() write, {
    required void Function(ApiException failure) onFailure,
  }) async {
    try {
      final User written = await write();

      _account = written;
      _session.accountChanged(written);

      return true;
    } on ApiException catch (failure) {
      onFailure(failure);

      return false;
    }
  }
}
