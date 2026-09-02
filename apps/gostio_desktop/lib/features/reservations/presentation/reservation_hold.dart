// What the API means by an active reservation: confirmed, or pending with a
// hold that has not run out.
enum ReservationHold {
  any('All', null),
  holding('Still holds a place', true),
  released('No longer does', false);

  const ReservationHold(this.label, this.isActive);

  final String label;
  final bool? isActive;
}
