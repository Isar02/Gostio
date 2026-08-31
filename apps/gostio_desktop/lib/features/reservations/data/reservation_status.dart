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
}
