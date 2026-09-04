import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/api_image.dart';
import 'package:gostio_desktop/features/listings/data/listing_photos_repository.dart';
import 'package:gostio_desktop/features/listings/presentation/listing_photos_tab.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The photographs could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Trace 7c30f1'), findsOneWidget);
    expect(find.textContaining('No photographs yet'), findsNothing);
  });

  testWidgets('a listing that really has none is named as the reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos()));
    await tester.pumpAndSettle();

    expect(find.text('No photographs yet'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('the gallery names the cover and counts what a listing holds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos(rows: _two)));
    await tester.pumpAndSettle();

    expect(find.text('Cover'), findsOneWidget);
    expect(
      find.text('2 photographs · 3 KB · the cover leads the listing'),
      findsOneWidget,
    );
  });

  testWidgets('deleting the only photograph promises no replacement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos(rows: _one)));
    await tester.pumpAndSettle();
    await _hover(tester, 0);

    await tester.tap(find.byTooltip('Delete this photograph'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('the listing is left showing no photograph'),
      findsOneWidget,
    );
    expect(find.textContaining('the next one takes its place'), findsNothing);
  });

  testWidgets('deleting a cover with others behind it names the successor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos(rows: _two)));
    await tester.pumpAndSettle();
    await _hover(tester, 0);

    await tester.tap(find.byTooltip('Delete this photograph').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('the next one takes its place'), findsOneWidget);
  });

  testWidgets('the cover offers a disabled promotion that says why', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Photos(rows: _two)));
    await tester.pumpAndSettle();
    await _hover(tester, 0);

    final Finder star = find.byTooltip('This one already leads the listing');

    expect(star, findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: star, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
  });
}

Future<void> _hover(WidgetTester tester, int tile) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);

  await mouse.moveTo(tester.getCenter(find.byType(ApiImage).at(tile)));
  await tester.pumpAndSettle();
}

Widget _tab(_Photos photos) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ApiClient>(
      create: (BuildContext context) =>
          ApiClient(baseUrl: Uri.parse('http://localhost:5000')),
      dispose: (BuildContext context, ApiClient client) => client.close(),
    ),
    Provider<ListingPhotosRepository>.value(value: photos),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: ListingPhotosTab(listing: _listing, onCoverMayChange: () {}),
    ),
  ),
);

class _Photos implements ListingPhotosRepository {
  _Photos({this.failing = false, this.rows = const <ListingPhoto>[]});

  final bool failing;
  final List<ListingPhoto> rows;

  @override
  Future<List<ListingPhoto>> forListing(ListingAddress listing) async {
    if (failing) {
      throw const ApiException(
        message: 'The photographs could not be read.',
        statusCode: 500,
        traceId: '7c30f1',
      );
    }

    return rows;
  }

  @override
  Future<ListingPhoto> upload(ListingAddress listing, ImageUpload image) =>
      throw UnimplementedError();

  @override
  Future<ListingPhoto> setCover(ListingAddress listing, int photoId) =>
      throw UnimplementedError();

  @override
  Future<void> delete(ListingAddress listing, int photoId) =>
      throw UnimplementedError();
}

final List<ListingPhoto> _one = <ListingPhoto>[_photo(1, isCover: true)];

final List<ListingPhoto> _two = <ListingPhoto>[
  _photo(1, isCover: true),
  _photo(2),
];

ListingPhoto _photo(int id, {bool isCover = false}) => ListingPhoto(
  id: id,
  listingId: 7,
  contentType: 'image/jpeg',
  isCover: isCover,
  displayOrder: id,
  sizeInBytes: 1536,
  uploadedAt: DateTime.utc(2026, 3, 4),
);

const ListingAddress _listing = ListingAddress(ListingKind.accommodation, 7);
