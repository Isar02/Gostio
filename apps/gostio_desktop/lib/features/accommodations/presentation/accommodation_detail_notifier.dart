import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../../reservations/data/reservations_repository.dart';
import '../../users/data/users_repository.dart';
import '../data/accommodation.dart';
import '../data/accommodation_draft.dart';
import '../data/accommodations_repository.dart';
import 'accommodation_form_options.dart';

class AccommodationDetailNotifier extends ScreenNotifier {
  AccommodationDetailNotifier(
    this._accommodations,
    this._reference,
    this._users,
    this._reservations, {
    required this.accommodationId,
    required this.asAdministrator,
  });

  final AccommodationsRepository _accommodations;
  final ReferenceRepository _reference;
  final UsersRepository _users;
  final ReservationsRepository _reservations;

  // Absent means the form is creating rather than editing one that exists.
  final int? accommodationId;

  final bool asAdministrator;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _coverMayHaveChanged = false;
  int _bookings = 0;
  Accommodation? _accommodation;
  AccommodationFormOptions _options = AccommodationFormOptions.none;
  ApiException? _failure;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  bool get isCreating => accommodationId == null;

  bool get isBooked => _bookings > 0;

  bool get hasCreated => isCreating && _accommodation != null;

  bool get coverMayHaveChanged => _coverMayHaveChanged;

  void coverMayChange() {
    _coverMayHaveChanged = true;
    publish();
  }

  Accommodation? get accommodation => _accommodation;

  AccommodationFormOptions get options => _options;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? messageFor(String field) => _failure?.firstMessageFor(field);

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    publish();

    try {
      final List<Object?> answers = await Future.wait(<Future<Object?>>[
        _fetchAccommodation(),
        AccommodationFormOptions.load(
          _reference,
          _users,
          asAdministrator: asAdministrator,
          forCreating: isCreating,
        ),
        _countBookings(),
      ]);

      _accommodation = answers[0] as Accommodation?;
      _options = answers[1]! as AccommodationFormOptions;
      _bookings = answers[2]! as int;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isLoading = false;
    publish();
  }

  Future<Accommodation?> save(
    AccommodationDraft draft, {
    required bool isActive,
    int? hostId,
  }) async {
    _isSaving = true;
    _failure = null;
    publish();

    Accommodation? written;

    try {
      written = switch (accommodationId) {
        null => await _accommodations.create(draft, hostId: hostId),
        final int id => await _accommodations.update(
          id,
          draft,
          isActive: isActive,
        ),
      };
      _accommodation = written;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _isSaving = false;
    publish();

    return written;
  }

  Future<bool> delete() async {
    final int? id = accommodationId;
    if (id == null) {
      return false;
    }

    _isSaving = true;
    _failure = null;
    publish();

    try {
      await _accommodations.delete(id);

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

  Future<Accommodation?> _fetchAccommodation() async =>
      accommodationId == null ? null : _accommodations.get(accommodationId!);

  Future<int> _countBookings() async => accommodationId == null
      ? 0
      : _reservations.countForAccommodation(accommodationId!);
}
