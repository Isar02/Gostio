# Gostio desktop client

The Windows client for administrators and hosts. Guests are served by the
Android client beside it.

## Running it

The API address is the only thing this client is told, and it is supplied on the
command line:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5000
```

Started without it, or with an address that is not absolute http or https, the
client says which value is missing and stops rather than failing on the first
call.

## Before a commit

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter analyze --fatal-infos --fatal-warnings
```

Nothing is committed while any of them reports anything. A change that reaches
into `packages/gostio_core` runs the same three there before it is read here.

## Layout

```
lib/
  main.dart            reads the settings and picks the application to run
  app/                 the application widget, the shell and routing
  core/
    config/            the settings read from the environment
    paging/            the list state every screen with a table reuses
    state/             the notifier every screen is built on
    theme/             the scales this client is measured in, and the theme
    widgets/           the controls every screen reuses
  features/
    <feature>/
      data/            the repository over the client, and what a screen asks it
      presentation/    the screens and the notifier behind them
```

The contract, the session and the brand are not here. They belong to the product
rather than to this client, so they live in `packages/gostio_core` and are read
through the one library it publishes:

```dart
import 'package:gostio_core/gostio_core.dart';
```

That is where the response models, `ApiClient`, `Session`, the validators, the
date and money formats, the palette, `Tone` and the three bundled faces are. A
model that changes is regenerated there, not here — this client has no
`build_runner`.

Dependencies point one way: `presentation` reaches `data`, `data` reaches
`core`, and nothing reaches back. A feature may import another feature's `data`
freely. It may import what another feature *draws* only from `listings` and
`reference`, the two that publish widgets for other features to compose — the
photographs and the status of any listing, the city a form picks — and from no
other. Neither `core` nor the package holds business rules: the server owns
them, so `Session` holds state and the repositories make the calls.

`test/architecture/layering_test.dart` holds five of those directions — core
reaching a feature or the application, a feature reaching the application, a
data layer reaching a presentation one, a feature reaching what a feature
outside the shared two draws, and anything naming a path inside `gostio_core`
rather than the library it publishes — over every import and export in `lib`,
and the suite fails when one is crossed. Adding a feature to the shared list
there is a decision about the shape of the client rather than a way past a
failing test.
