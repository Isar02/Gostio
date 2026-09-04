import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

// The three faces are bundled by the package and declared by this client, so
// the licence they travel under is read across that seam or not at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled face carries its licence', () async {
    registerFontLicences();

    final Map<String, String> read = <String, String>{};
    await for (final LicenseEntry entry in LicenseRegistry.licenses) {
      for (final String face in entry.packages) {
        read[face] = entry.paragraphs
            .map((LicenseParagraph paragraph) => paragraph.text)
            .join();
      }
    }

    for (final String face in <String>[
      'Geist',
      'Manrope',
      'Plus Jakarta Sans',
    ]) {
      expect(read[face], isNotNull, reason: '$face carries no licence');
      expect(read[face], contains('SIL OPEN FONT LICENSE'));
    }
  });
}
