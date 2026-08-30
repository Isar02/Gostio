import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const Map<String, String> _licences = <String, String>{
  'Geist': 'assets/fonts/Geist-OFL.txt',
  'Manrope': 'assets/fonts/Manrope-OFL.txt',
  'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans-OFL.txt',
};

void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry<String, String> font in _licences.entries) {
      yield LicenseEntryWithLineBreaks(<String>[
        font.key,
      ], await rootBundle.loadString(font.value));
    }
  });
}
