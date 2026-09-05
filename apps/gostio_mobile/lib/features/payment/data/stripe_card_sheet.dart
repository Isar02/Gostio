import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import 'card_sheet.dart';

// The card sheet as the processor draws it. The publishable key arrives with
// the charge rather than at start-up, so it is set here: a client that never
// pays for anything never holds one.
class StripeCardSheet implements CardSheet {
  const StripeCardSheet();

  static const String _payee = 'Gostio';

  @override
  Future<CardSheetResult> present({
    required String publishableKey,
    required String clientSecret,
  }) async {
    stripe.Stripe.publishableKey = publishableKey;
    await stripe.Stripe.instance.applySettings();

    try {
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: _payee,
        ),
      );
      await stripe.Stripe.instance.presentPaymentSheet();

      return const CardSheetSent();
    } on stripe.StripeException catch (refusal) {
      final stripe.LocalizedErrorMessage fault = refusal.error;

      return fault.code == stripe.FailureCode.Canceled
          ? const CardSheetCancelled()
          : CardSheetRefused(
              fault.localizedMessage ??
                  fault.message ??
                  'The card was not charged.',
            );
    } on Exception {
      // The processor's own refusals are the branch above. What is left is the
      // platform channel underneath it, and a sheet that could not be opened
      // is not a payment either — it is said rather than thrown at a screen
      // whose button would otherwise wait forever.
      return const CardSheetRefused('The card sheet could not be opened.');
    }
  }
}
