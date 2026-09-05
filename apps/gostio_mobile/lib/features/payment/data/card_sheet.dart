// The card sheet, named as what this client needs of it rather than as the
// processor that draws it. Every type belonging to that processor stops at the
// implementation, so nothing above this layer knows which one is in use.
abstract interface class CardSheet {
  Future<CardSheetResult> present({
    required String publishableKey,
    required String clientSecret,
  });
}

// The three ways a sheet ends, and the reason this is a result rather than a
// value plus an exception: a reader who closed the sheet did nothing wrong,
// and a sheet that could not open is reported rather than thrown.
sealed class CardSheetResult {
  const CardSheetResult();
}

// The reader finished the sheet. This is not a payment — what settles a
// booking is the signed call the processor makes to the server — so it says
// what was sent rather than what was paid.
final class CardSheetSent extends CardSheetResult {
  const CardSheetSent();
}

final class CardSheetCancelled extends CardSheetResult {
  const CardSheetCancelled();
}

// The sheet could not be opened. A card the processor declined is not this:
// that sheet stays up and says so itself, and never answers this call.
final class CardSheetRefused extends CardSheetResult {
  const CardSheetRefused(this.message);

  final String message;
}
