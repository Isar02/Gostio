// The statuses the API answers with, by the seeded keys it never renumbers.
enum ReservationStatus {
  pending,
  confirmed,
  cancelled,
  completed;

  static ReservationStatus? forId(int id) => switch (id) {
    1 => pending,
    2 => confirmed,
    3 => cancelled,
    4 => completed,
    _ => null,
  };

  // The moves the server's state machine allows out of each standing, mirrored
  // so an action it would refuse is disabled with the reason rather than
  // pressed. A standing this client does not know refuses both: the server is
  // the authority, and guessing on its behalf is what this avoids.
  bool get canBeConfirmed => this == pending;

  bool get canBeCancelled => this == pending || this == confirmed;
}
