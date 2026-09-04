import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/api_image.dart';
import 'package:provider/provider.dart';

void main() {
  final ApiClient client = ApiClient(baseUrl: Uri.parse('http://localhost'));

  tearDownAll(client.close);

  test('two reads of one address are the same picture', () {
    expect(
      ApiImageProvider(client, '/news/3/image'),
      ApiImageProvider(client, '/news/3/image'),
    );
  });

  // An Image already on screen keeps the stream it resolved unless the key it
  // is given differs, so emptying the cache alone would not move one.
  testWidgets('a picture that was replaced is a different picture', (
    WidgetTester tester,
  ) async {
    const String path = '/news/3/image';
    final ApiImageProvider before = ApiImageProvider(client, path);

    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: client,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => ApiImage.forget(context, path),
              child: const Text('Replace'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(ApiImageProvider(client, path), isNot(before));
  });

  // A picture nobody replaced is the picture already read, so a correction to
  // the text beside it costs no fetch.
  test('a picture nobody replaced is read once', () {
    expect(
      ApiImageProvider(client, '/news/4/image'),
      ApiImageProvider(client, '/news/4/image'),
    );
  });

  // A new sign in is a new right to read, so nothing read under the old one
  // is served to it.
  test('a picture read under another session is read again', () {
    final ApiImageProvider before = ApiImageProvider(client, '/news/5/image');
    client.token = 'another';

    expect(ApiImageProvider(client, '/news/5/image'), isNot(before));
  });
}
