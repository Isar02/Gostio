# gostio_core

What belongs to Gostio rather than to one of its clients. Both applications
depend on this package by path; it depends on neither.

## What is in here

- the response models the API answers with, generated from the same shapes
- `ApiClient` over `dio`, with the token, session and failure interceptors,
  `ApiException`, `UploadedFile` and `ImageUpload`
- `Session`, the signed in account, and the role names the server writes
- the validators, input formats and image rules mirroring the server's own
- the date, money and duration formats, and the calendar-day helpers
- the palette, `Tone`, and the three faces with their licences

## What is not

Anything measured for a screen: spacing and type scales, `ThemeData`, widgets,
notifiers and repositories. A repository is a client's chosen vocabulary over
the endpoints it uses rather than the contract itself, so it stays with the
client, and so do the query and draft objects its screens fill.

Two tests hold that line: nothing under `lib/src` reaches a widget library, and
every public library under it is one `lib/gostio_core.dart` exports. Generated
`.g.dart` files are parts of the library they belong to rather than libraries of
their own, so they are neither exported nor counted. A client imports that
library and never a path inside it, which its own layering test holds from the
other side.

## The faces

They live under `lib/assets/fonts` because Flutter resolves a package asset
relative to `lib/`, so every reader names them
`packages/gostio_core/assets/fonts/...` — `AppFonts` holds that folder, the
family names and the two faces something reads by hand. Each application
declares the families in its own `pubspec.yaml` against those paths, which is
what keeps the family a theme asks for called `Geist`.

## Before a commit

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter analyze --fatal-infos --fatal-warnings
```

A changed response model is regenerated here and the result is committed, so
neither client builds through `build_runner`:

```bash
dart run build_runner build --delete-conflicting-outputs
```
