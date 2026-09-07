// What a delivered push says about the notice behind it. The row the server
// wrote is the record; this is only enough to open what it is about, and the
// value arrived as a string because every value in a delivery does.
//
// The kind that raised it is in the payload as well and is deliberately not
// read: nothing this client does with a tap turns on it, and a field parsed
// for nobody is a field the next reader has to work out.
class PushNotice {
  const PushNotice({this.reservationId});

  factory PushNotice.of(Map<String, dynamic> data) =>
      PushNotice(reservationId: int.tryParse(_text(data['reservationId'])));

  // Every notice the server raises but a host verification is about a
  // reservation, so this is the one thing a tap has to open a screen with.
  final int? reservationId;

  static String _text(Object? value) => value is String ? value : '';
}
