import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/listings/data/listing_photos_repository.dart';
import 'package:gostio_desktop/features/listings/presentation/listing_photos_notifier.dart';

void main() {
  test('a file the server would refuse never reaches it', () async {
    final _Photos photos = _Photos();
    final ListingPhotosNotifier notifier = _notifier(photos);
    await notifier.load();

    await notifier.add(<ImageUpload>[
      ImageUpload(name: 'terrace.jpg', bytes: _jpeg),
      ImageUpload(name: 'notes.pdf', bytes: _notAnImage),
    ]);

    expect(photos.uploaded, <String>['terrace.jpg']);
    expect(
      notifier.failureMessage,
      'notes.pdf: An image has to be one of image/jpeg, image/png, image/webp.',
    );
  });

  test(
    'what landed before a refusal is read back rather than dropped',
    () async {
      final _Photos photos = _Photos();
      final ListingPhotosNotifier notifier = _notifier(photos);
      await notifier.load();

      await notifier.add(<ImageUpload>[
        ImageUpload(name: 'terrace.jpg', bytes: _jpeg),
        ImageUpload(name: 'notes.pdf', bytes: _notAnImage),
      ]);

      expect(notifier.items.length, 3);
      expect(notifier.isUploading, isFalse);
    },
  );

  test('the API refusal is read from the field it faults', () async {
    final _Photos photos = _Photos()
      ..refusal = const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'File': <String>['An image is at most 4 MB.'],
        },
        traceId: '4b19aa',
      );
    final ListingPhotosNotifier notifier = _notifier(photos);
    await notifier.load();

    await notifier.add(<ImageUpload>[
      ImageUpload(name: 'terrace.jpg', bytes: _jpeg),
    ]);

    expect(notifier.failureMessage, 'An image is at most 4 MB.');
    expect(notifier.failureTraceId, '4b19aa');
  });

  test(
    'the list is told when the photograph leading the listing changes',
    () async {
      int told = 0;
      final _Photos photos = _Photos();
      final ListingPhotosNotifier notifier = _notifier(
        photos,
        onCoverMayChange: () => told++,
      );
      await notifier.load();

      expect(told, 0);

      await notifier.setCover(2);

      expect(told, 1);
      expect(notifier.items.first.isCover, isFalse);
    },
  );

  test(
    'a possible change is reported before its write can outlive the screen',
    () async {
      int told = 0;
      final Completer<void> writeGate = Completer<void>();
      final _Photos photos = _Photos()..writeGate = writeGate;
      final ListingPhotosNotifier notifier = _notifier(
        photos,
        onCoverMayChange: () => told++,
      );
      await notifier.load();

      final Future<void> writing = notifier.setCover(2);

      expect(told, 1);
      expect(notifier.isBusy, isTrue);

      writeGate.complete();
      await writing;
    },
  );

  test(
    'a first upload reports its possible cover before it can outlive',
    () async {
      int told = 0;
      final Completer<void> writeGate = Completer<void>();
      final _Photos photos = _Photos()
        ..rows = <ListingPhoto>[]
        ..writeGate = writeGate;
      final ListingPhotosNotifier notifier = _notifier(
        photos,
        onCoverMayChange: () => told++,
      );
      await notifier.load();

      final Future<void> writing = notifier.add(<ImageUpload>[
        ImageUpload(name: 'terrace.jpg', bytes: _jpeg),
      ]);

      expect(told, 1);

      writeGate.complete();
      await writing;
    },
  );

  test('the file being uploaded is never counted past the batch', () async {
    final _Photos photos = _Photos();
    late final ListingPhotosNotifier notifier;
    notifier = _notifier(photos);
    await notifier.load();

    photos.onRead = () => notifier.uploading;

    await notifier.add(<ImageUpload>[
      ImageUpload(name: 'terrace.jpg', bytes: _jpeg),
      ImageUpload(name: 'balcony.jpg', bytes: _jpeg),
    ]);

    expect(photos.counted, <int>[2]);
    expect(notifier.uploading, 0);
  });

  test(
    'a write that stood is reported even when the read back fails',
    () async {
      int told = 0;
      final _Photos photos = _Photos();
      final ListingPhotosNotifier notifier = _notifier(
        photos,
        onCoverMayChange: () => told++,
      );
      await notifier.load();

      photos.readFailure = const ApiException(
        message: 'The photographs could not be read.',
        statusCode: 503,
      );

      await notifier.setCover(2);

      expect(told, 1);
      expect(notifier.failureMessage, 'The photographs could not be read.');
    },
  );

  test('a change that leaves the same cover in place tells nobody', () async {
    int told = 0;
    final _Photos photos = _Photos();
    final ListingPhotosNotifier notifier = _notifier(
      photos,
      onCoverMayChange: () => told++,
    );
    await notifier.load();

    await notifier.remove(2);

    expect(told, 0);
    expect(notifier.items.length, 1);
  });
}

ListingPhotosNotifier _notifier(
  _Photos photos, {
  VoidCallback? onCoverMayChange,
}) => ListingPhotosNotifier(
  photos,
  listing: _listing,
  onCoverMayChange: onCoverMayChange ?? () {},
);

class _Photos implements ListingPhotosRepository {
  final List<String> uploaded = <String>[];
  final List<int> counted = <int>[];

  int Function()? onRead;

  ApiException? refusal;

  ApiException? readFailure;

  Completer<void>? writeGate;

  List<ListingPhoto> rows = <ListingPhoto>[_photo(1, isCover: true), _photo(2)];

  @override
  Future<List<ListingPhoto>> forListing(ListingAddress listing) async {
    if (onRead case final int Function() reading) {
      counted.add(reading());
    }

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    return rows;
  }

  @override
  Future<ListingPhoto> upload(ListingAddress listing, ImageUpload image) async {
    if (refusal case final ApiException refused) {
      throw refused;
    }

    await writeGate?.future;

    uploaded.add(image.name);

    final ListingPhoto added = _photo(rows.length + 1);
    rows = <ListingPhoto>[...rows, added];

    return added;
  }

  @override
  Future<ListingPhoto> setCover(ListingAddress listing, int photoId) async {
    await writeGate?.future;

    rows = <ListingPhoto>[
      for (final ListingPhoto row in rows)
        _photo(row.id, isCover: row.id == photoId),
    ];

    return rows.firstWhere((ListingPhoto row) => row.id == photoId);
  }

  @override
  Future<void> delete(ListingAddress listing, int photoId) async {
    rows = rows
        .where((ListingPhoto row) => row.id != photoId)
        .toList(growable: false);
  }
}

ListingPhoto _photo(int id, {bool isCover = false}) => ListingPhoto(
  id: id,
  listingId: 7,
  contentType: 'image/jpeg',
  isCover: isCover,
  displayOrder: id,
  sizeInBytes: 1024,
  uploadedAt: DateTime.utc(2026, 3, 4),
);

final Uint8List _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0]);

final Uint8List _notAnImage = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46]);

const ListingAddress _listing = ListingAddress(ListingKind.accommodation, 7);
