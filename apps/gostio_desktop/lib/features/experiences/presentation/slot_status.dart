// What a term's open flag is called on screen, on the filter that asks for it
// and on the chip that reports it, so the words are written once.
enum SlotStatus {
  any('All', null),
  open('Open', true),
  closed('Closed', false);

  const SlotStatus(this.label, this.isActive);

  final String label;
  final bool? isActive;

  static SlotStatus of(bool isActive) => isActive ? open : closed;
}
