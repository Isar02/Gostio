// What a listing's active flag is called on screen, on the filter that asks
// for it and on the chip that reports it, so the words are written once.
enum ListingStatus {
  any('All', null),
  active('Active', true),
  withdrawn('Withdrawn', false);

  const ListingStatus(this.label, this.isActive);

  final String label;
  final bool? isActive;

  static ListingStatus of(bool isActive) => isActive ? active : withdrawn;
}
