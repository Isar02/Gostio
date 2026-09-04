import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/widgets/api_image.dart';

import '../../support/widgets.dart';

void main() {
  final ApiClient client = ApiClient(
    baseUrl: Uri.parse('http://10.0.2.2:5000'),
  );

  tearDownAll(client.close);

  // A listing without a cover is drawn, not skipped, and it asks for nothing.
  testWidgets('a picture that does not exist is a placeholder, not a request', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const ApiImage(path: null), client: client));

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a placeholder can say what the missing picture was', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const ApiImage(path: null, missingIcon: Icons.person_outline),
        client: client,
      ),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  // A card is drawn before its cover arrives, so the room the picture will
  // take is held rather than collapsed and pushed open under the thumb.
  testWidgets('a picture that is not there holds the room it would take', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const ApiImage(path: null, width: 320, height: 200),
        client: client,
      ),
    );

    expect(tester.getSize(find.byType(ApiImage)), const Size(320, 200));
  });

  test('two reads of one address are the same picture', () {
    expect(
      ApiImageProvider(client, 'api/accommodations/1/photos/7'),
      ApiImageProvider(client, 'api/accommodations/1/photos/7'),
    );
  });

  // An Image already on screen keeps the stream it resolved unless the key it
  // is given differs, so emptying the cache alone would not move one.
  testWidgets('a picture that was replaced is a different picture', (
    WidgetTester tester,
  ) async {
    const String path = 'api/users/me/picture';
    final ApiImageProvider before = ApiImageProvider(client, path);

    await tester.pumpWidget(
      drawn(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => ApiImage.forget(context, path),
            child: const Text('Replace'),
          ),
        ),
        client: client,
      ),
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(ApiImageProvider(client, path), isNot(before));
  });

  // A new sign in is a new right to read, so nothing read under the old one
  // is served to it.
  test('a picture read under another session is read again', () {
    final ApiImageProvider before = ApiImageProvider(
      client,
      'api/news/5/image',
    );
    client.token = 'another';

    expect(ApiImageProvider(client, 'api/news/5/image'), isNot(before));
  });
}
