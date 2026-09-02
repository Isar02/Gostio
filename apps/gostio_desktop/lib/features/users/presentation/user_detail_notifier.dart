import '../../../core/models/user.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../data/user_draft.dart';
import '../data/users_repository.dart';

class UserDetailNotifier extends ScreenNotifier {
  UserDetailNotifier(
    this._users,
    this._reference, {
    required this.userId,
    required this.signedInUserId,
  });

  final UsersRepository _users;
  final ReferenceRepository _reference;

  // Absent means the form is creating rather than editing one that exists.
  final int? userId;

  final int signedInUserId;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanged = false;
  User? _user;
  List<LookupItem> _roles = const <LookupItem>[];
  ApiException? _failure;
  ApiException? _writeFailure;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isCreating => userId == null;

  // Three of the writes here are refused against the caller's own account, so
  // the screen answers the same question the server does before offering them.
  bool get isSelf => userId == signedInUserId;

  bool get hasChanged => _hasChanged;

  User? get user => _user;

  List<LookupItem> get roles => _roles;

  // What a load came back with empties the screen; what a write came back
  // with is said above the form that is still holding what was typed into it.
  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? get writeFailureMessage => _writeFailure?.message;

  String? messageFor(String field) => _writeFailure?.firstMessageFor(field);

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    _writeFailure = null;
    publish();

    try {
      final List<Object?> answers = await Future.wait(<Future<Object?>>[
        _fetchUser(),
        _reference.roles(),
      ]);

      _user = answers[0] as User?;
      _roles = answers[1]! as List<LookupItem>;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<User?> create(
    UserDraft draft, {
    required String username,
    required String password,
    required String confirmPassword,
    required List<String> roles,
  }) => _write(
    () => _users.create(
      draft,
      username: username,
      password: password,
      confirmPassword: confirmPassword,
      roles: roles,
    ),
  );

  // Four endpoints own four parts of an account, so a save writes the fields
  // and then only what actually moved. A refusal stops the rest and leaves the
  // account drawn as the writes that did land left it. The password goes last,
  // because writing one ends the account holder's session.
  Future<User?> saveChanges(
    UserDraft draft, {
    required List<String> roles,
    required bool isActive,
    String? password,
    String? confirmPassword,
  }) async {
    final int? id = userId;
    final User? current = _user;
    if (id == null || current == null) {
      return null;
    }

    _isSaving = true;
    _writeFailure = null;
    publish();

    User landed = current;
    bool didWrite = false;

    try {
      if (!draft.hasSameFieldsAs(landed)) {
        landed = await _users.update(id, draft);
        didWrite = true;
      }

      if (!_holdsExactly(landed.roles, roles)) {
        landed = await _users.setRoles(id, roles);
        didWrite = true;
      }

      if (landed.isActive != isActive) {
        landed = await _users.setState(id, isActive: isActive);
        didWrite = true;
      }

      if (password != null && confirmPassword != null) {
        await _users.setPassword(
          id,
          password: password,
          confirmPassword: confirmPassword,
        );
        didWrite = true;
      }
    } on ApiException catch (failure) {
      _writeFailure = failure;
    }

    if (didWrite) {
      _user = landed;
      _hasChanged = true;
    }

    _isSaving = false;
    publish();

    return _writeFailure == null ? landed : null;
  }

  Future<bool> delete() async {
    final int? id = userId;
    if (id == null) {
      return false;
    }

    _isSaving = true;
    _writeFailure = null;
    publish();

    try {
      await _users.delete(id);

      return true;
    } on ApiException catch (failure) {
      _writeFailure = failure;
      _isSaving = false;
      publish();

      return false;
    }
  }

  Future<User?> _fetchUser() async =>
      userId == null ? null : _users.get(userId!);

  Future<User?> _write(Future<User> Function() write) async {
    _isSaving = true;
    _writeFailure = null;
    publish();

    User? written;

    try {
      written = await write();
      _user = written;
      _hasChanged = true;
    } on ApiException catch (failure) {
      _writeFailure = failure;
    }

    _isSaving = false;
    publish();

    return written;
  }

  static bool _holdsExactly(List<String> held, List<String> wanted) =>
      held.length == wanted.length && held.toSet().containsAll(wanted);
}
