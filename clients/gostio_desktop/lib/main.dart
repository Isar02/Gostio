import 'package:flutter/material.dart';

import 'app/configuration_failure_app.dart';
import 'app/gostio_app.dart';
import 'core/config/app_settings.dart';

void main() {
  runApp(switch (AppSettings.read()) {
    SettingsRead(:final settings) => GostioApp(settings: settings),
    SettingsRejected(:final reason) => ConfigurationFailureApp(reason: reason),
  });
}
