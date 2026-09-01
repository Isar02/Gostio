import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../../reservations/data/reservations_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/experience.dart';
import '../data/experience_draft.dart';
import '../data/experiences_repository.dart';
import 'experience_form_options.dart';

class ExperienceDetailNotifier extends ScreenNotifier {
  ExperienceDetailNotifier(
    this._experiences,
    this._reference,
    this._users,
    this._reservations, {
    required this.experienceId,
    required this.asAdministrator,
  });

  final ExperiencesRepository _experiences;
  final ReferenceRepository _reference;
  final UsersRepository _users;
  final ReservationsRepository _reservations;

  // Absent means the form is creating rather than editing one that exists.
  final int? experienceId;

  final bool asAdministrator;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _coverMayHaveChanged = false;
  int _bookings = 0;
  Experience? _experience;
  ExperienceFormOptions _options = ExperienceFormOptions.none;
  ApiException? _failure;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isCreating => experienceId == null;

  bool get isBooked => _bookings > 0;

  bool get hasCreated => isCreating && _experience != null;

  bool get coverMayHaveChanged => _coverMayHaveChanged;

  void coverMayChange() {
    _coverMayHaveChanged = true;
    publish();
  }

  Experience? get experience => _experience;

  ExperienceFormOptions get options => _options;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    publish();

    try {
      final List<Object?> answers = await Future.wait(<Future<Object?>>[
        _fetchExperience(),
        ExperienceFormOptions.load(
          _reference,
          _users,
          asAdministrator: asAdministrator,
          forCreating: isCreating,
        ),
        _countBookings(),
      ]);

      _experience = answers[0] as Experience?;
      _options = answers[1]! as ExperienceFormOptions;
      _bookings = answers[2]! as int;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<Experience?> save(
    ExperienceDraft draft, {
    required bool isActive,
    int? hostId,
  }) async {
    _isSaving = true;
    _failure = null;
    publish();

    Experience? written;

    try {
      written = switch (experienceId) {
        null => await _experiences.create(draft, hostId: hostId),
        final int id => await _experiences.update(
          id,
          draft,
          isActive: isActive,
        ),
      };
      _experience = written;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isSaving = false;
    publish();

    return written;
  }

  Future<bool> delete() async {
    final int? id = experienceId;
    if (id == null) {
      return false;
    }

    _isSaving = true;
    _failure = null;
    publish();

    try {
      await _experiences.delete(id);

      return true;
    } on ApiException catch (failure) {
      _failure = failure;
      _isSaving = false;
      publish();

      return false;
    }
  }

  // The failure is left to the dialog that asked, which still has the fields
  // the server is complaining about.
  Future<LookupItem> addCity({
    required String name,
    required int countryId,
  }) async {
    final LookupItem city = await _reference.addCity(
      name: name,
      countryId: countryId,
    );
    _options = _options.withCity(city);
    publish();

    return city;
  }

  Future<Experience?> _fetchExperience() async =>
      experienceId == null ? null : _experiences.get(experienceId!);

  Future<int> _countBookings() async => experienceId == null
      ? 0
      : _reservations.countForExperience(experienceId!);
}
