import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  const AppSettings({required this.apiBaseUrl});

  final Uri apiBaseUrl;

  static const String apiBaseUrlVariable = 'API_BASE_URL';

  static const String _apiBaseUrl = String.fromEnvironment(apiBaseUrlVariable);

  static const String _howItIsSupplied =
      'Supply it as --dart-define=$apiBaseUrlVariable=http://localhost:5000';

  static SettingsResult read() {
    final String supplied = _apiBaseUrl.trim();
    if (supplied.isEmpty) {
      return const SettingsRejected(
        'The client was started without $apiBaseUrlVariable. $_howItIsSupplied',
      );
    }

    final Uri? address = Uri.tryParse(_withoutTrailingSlash(supplied));
    if (address == null || !_isAnApiAddress(address)) {
      return SettingsRejected(
        '$apiBaseUrlVariable must be an absolute http or https address, and '
        '"$supplied" is not one. $_howItIsSupplied',
      );
    }

    return SettingsRead(AppSettings(apiBaseUrl: address));
  }

  static bool _isAnApiAddress(Uri address) {
    return (address.scheme == 'http' || address.scheme == 'https') &&
        address.host.isNotEmpty &&
        !address.hasQuery &&
        !address.hasFragment;
  }

  static String _withoutTrailingSlash(String address) {
    var end = address.length;
    while (end > 0 && address[end - 1] == '/') {
      end--;
    }
    return address.substring(0, end);
  }
}

sealed class SettingsResult {
  const SettingsResult();
}

final class SettingsRead extends SettingsResult {
  const SettingsRead(this.settings);

  final AppSettings settings;
}

final class SettingsRejected extends SettingsResult {
  const SettingsRejected(this.reason);

  final String reason;
}
