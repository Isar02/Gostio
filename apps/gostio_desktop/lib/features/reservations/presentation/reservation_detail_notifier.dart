import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../experiences/data/experience_slot.dart';
import '../../experiences/data/experience_slots_repository.dart';
import '../data/refund_quote.dart';
import '../data/reservation.dart';
import '../data/reservation_payment.dart';
import '../data/reservation_refund.dart';
import '../data/reservations_repository.dart';
import 'side_read.dart';

class ReservationDetailNotifier extends ScreenNotifier {
  ReservationDetailNotifier(
    this._reservations,
    this._slots, {
    required this.reservationId,
  });

  final ReservationsRepository _reservations;
  final ExperienceSlotsRepository _slots;

  final int reservationId;

  bool _isLoading = true;
  bool _isWriting = false;
  bool _hasMoved = false;
  Reservation? _reservation;
  SideRead<ExperienceSlot> _term = SideRead.none;
  SideRead<ReservationPayment> _payment = SideRead.none;
  SideRead<ReservationRefund> _refund = SideRead.none;
  ApiException? _failure;
  ApiException? _writeFailure;

  bool get isLoading => _isLoading;

  bool get isWriting => _isWriting;

  bool get isBusy => _isWriting || _isLoading;

  bool get hasMoved => _hasMoved;

  Reservation? get reservation => _reservation;

  // The booking names the slot and carries nothing about it.
  SideRead<ExperienceSlot> get term => _term;

  SideRead<ReservationPayment> get payment => _payment;

  SideRead<ReservationRefund> get refund => _refund;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  String? get writeFailureMessage => _writeFailure?.message;

  Future<void> load() async {
    _isLoading = true;
    publish();

    await Future.wait(<Future<void>>[
      _readBooking(),
      _readPayment(),
      _readRefund(),
    ]);
    await _readTerm();

    _isLoading = false;
    publish();
  }

  Future<void> confirm() async {
    _writeFailure = await _move(() => _reservations.confirm(reservationId));
    publish();
  }

  Future<ApiException?> cancel({required String reason}) =>
      _move(() => _reservations.cancel(reservationId, reason: reason));

  // What a cancellation sends back moves with the clock until there is one.
  Future<RefundQuote> refundQuote() => _reservations.refundQuote(reservationId);

  // What settled a booking moves with it, so the page is read again rather
  // than patched from the one row the write answered.
  Future<ApiException?> _move(Future<Reservation> Function() write) async {
    _isWriting = true;
    _writeFailure = null;
    publish();

    try {
      await write();
    } on ApiException catch (refused) {
      _isWriting = false;
      publish();

      return refused;
    }

    _hasMoved = true;
    _isWriting = false;
    await load();

    return null;
  }

  Future<void> _readBooking() async {
    try {
      _reservation = await _reservations.get(reservationId);
      _failure = null;
    } on ApiException catch (failure) {
      _reservation = null;
      _failure = failure;
    }
  }

  Future<void> _readPayment() async {
    _payment = await _readBeside<ReservationPayment>(
      () => _reservations.payment(reservationId),
    );
  }

  Future<void> _readRefund() async {
    _refund = await _readBeside<ReservationRefund>(
      () => _reservations.refund(reservationId),
    );
  }

  Future<void> _readTerm() async {
    final Reservation? booking = _reservation;
    final int? experienceId = booking?.experienceId;
    final int? slotId = booking?.experienceSlotId;

    if (experienceId == null || slotId == null) {
      _term = SideRead.none;

      return;
    }

    _term = await _readBeside<ExperienceSlot>(
      () => _slots.get(experienceId, slotId),
    );
  }

  static Future<SideRead<T>> _readBeside<T>(Future<T?> Function() read) async {
    try {
      return SideRead<T>.answered(await read());
    } on ApiException catch (failure) {
      return SideRead<T>.failed(failure);
    }
  }
}
