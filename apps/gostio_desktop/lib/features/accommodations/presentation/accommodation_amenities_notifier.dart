import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';
import '../data/accommodation_amenities_repository.dart';

// Two sets rather than one: what the server holds and what the screen has been
// asked to hold. The API writes the second over the first as a whole, so the
// difference between them is both what Save sends and what the tab has to be
// able to say out loud before it is sent.
class AccommodationAmenitiesNotifier extends ScreenNotifier {
  AccommodationAmenitiesNotifier(
    this._amenities,
    this._reference, {
    required this.accommodationId,
  });

  final AccommodationAmenitiesRepository _amenities;
  final ReferenceRepository _reference;

  final int accommodationId;

  bool _isLoading = true;
  bool _isLoaded = false;
  bool _isSaving = false;
  List<LookupItem> _vocabulary = const <LookupItem>[];
  Set<int> _offered = const <int>{};
  Set<int> _chosen = const <int>{};
  ApiException? _failure;

  bool get isLoading => _isLoading;

  bool get isLoaded => _isLoaded;

  bool get isSaving => _isSaving;

  List<LookupItem> get vocabulary => _vocabulary;

  int get chosenCount => _chosen.length;

  Set<int> get added => _chosen.difference(_offered);

  Set<int> get removed => _offered.difference(_chosen);

  bool get hasChanges => added.isNotEmpty || removed.isNotEmpty;

  bool isChosen(int amenityId) => _chosen.contains(amenityId);

  String? get failureMessage =>
      _failure?.firstMessageFor(AccommodationAmenitiesRepository.idsField) ??
      _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    publish();

    try {
      _vocabulary = await _reference.amenities();
      _offered = _idsOf(await _amenities.forAccommodation(accommodationId));
      _chosen = _offered;
      _isLoaded = true;
    } on ApiException catch (thrown) {
      // Half a load is worse than none: the vocabulary without the set the
      // listing holds draws every amenity as one it does not offer, and Save
      // would then write that.
      _isLoaded = false;
      _failure = thrown;
    }

    _isLoading = false;
    publish();
  }

  void toggle(int amenityId) {
    final Set<int> chosen = Set<int>.of(_chosen);
    if (!chosen.remove(amenityId)) {
      chosen.add(amenityId);
    }

    _chosen = chosen;
    _failure = null;
    publish();
  }

  void discard() {
    _chosen = _offered;
    _failure = null;
    publish();
  }

  // What the server answers with is what both sets become: it has just written
  // the whole thing, so its answer is the set rather than a copy of the
  // request that may have carried a duplicate.
  Future<void> save() async {
    if (!hasChanges) {
      return;
    }

    _isSaving = true;
    _failure = null;
    publish();

    try {
      _offered = _idsOf(
        await _amenities.set(accommodationId, _chosen.toList(growable: false)),
      );
      _chosen = _offered;
    } on ApiException catch (thrown) {
      _failure = thrown;
    }

    _isSaving = false;
    publish();
  }

  static Set<int> _idsOf(List<LookupItem> offered) => <int>{
    for (final LookupItem amenity in offered) amenity.id,
  };
}
