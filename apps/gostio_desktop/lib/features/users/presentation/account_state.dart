// What an account's active flag is called on screen, on the filter that asks
// for it and on the chip that reports it, so the words are written once.
enum AccountState {
  any('All', null),
  active('Active', true),
  deactivated('Deactivated', false);

  const AccountState(this.label, this.isActive);

  final String label;
  final bool? isActive;

  static AccountState of(bool isActive) => isActive ? active : deactivated;
}
