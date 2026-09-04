import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/app/configuration_failure_app.dart';
import 'package:gostio_mobile/app/gostio_app.dart';
import 'package:gostio_mobile/app/startup_screen.dart';
import 'package:gostio_mobile/core/config/app_settings.dart';

void main() {
  testWidgets('a client without an address says so and draws nothing else', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ConfigurationFailureApp(reason: 'API_BASE_URL is missing'),
    );

    expect(find.text('Gostio cannot start'), findsOneWidget);
    expect(find.text('API_BASE_URL is missing'), findsOneWidget);
    expect(find.byType(StartupScreen), findsNothing);
  });

  testWidgets('a client with an address names the API it will call', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      GostioApp(settings: AppSettings(apiBaseUrl: _address)),
    );

    expect(find.text('Gostio'), findsOneWidget);
    expect(find.text('http://10.0.2.2:5000'), findsOneWidget);
  });
}

final Uri _address = Uri.parse('http://10.0.2.2:5000');
