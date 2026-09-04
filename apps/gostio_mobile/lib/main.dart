import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import 'app/configuration_failure_app.dart';
import 'app/gostio_app.dart';
import 'core/config/app_settings.dart';

void main() {
  registerFontLicences();

  runApp(switch (AppSettings.read()) {
    SettingsRead(:final settings) => GostioApp(settings: settings),
    SettingsRejected(:final reason) => ConfigurationFailureApp(reason: reason),
  });
}
