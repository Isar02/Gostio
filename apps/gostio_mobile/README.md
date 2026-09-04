# Gostio mobile client

The Android client for guests. Administrators and hosts are served by the
Windows client beside it.

## Current state

Milestone C2 is complete and C3 is in review. The client signs in, registers, requests and spends a
password-reset code, signs out, and validates the active session whenever the
application returns to the foreground. Behind those screens sits the widget
vocabulary the catalogue flow is built from: cards and listing cards, section
headers, chips, rating stars, the loading, empty and error states, a bottom
sheet and action bar, an appending paged list that says how much of the whole
it holds, a date range picker over a month grid, and `ApiImage`. None of it
is drawn by a screen yet, so C4, the five-tab shell, is both what composes it
and what first puts it in front of a reader.

## The emulator

Android Studio brings the SDK but no system image, and without one there is no
device to run on. These are run once, from the SDK's `cmdline-tools/latest/bin`
and `emulator` folders:

```bash
sdkmanager "system-images;android-36;google_apis;x86_64"
avdmanager create avd --name gostio_phone --package "system-images;android-36;google_apis;x86_64" --device pixel_7
emulator -avd gostio_phone
```

The image is `google_apis` rather than the bare one because it carries Google
Play services, which is what delivers a push notification.

## Running it

The API address is the only thing this client is told, and it is supplied on the
command line. `10.0.2.2` is the host machine as an emulator sees it.

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Started without it, or with an address that is not absolute http or https, the
client says which value is missing and stops rather than failing on the first
call.

Plain HTTP reaches `10.0.2.2` and `localhost` and nothing else; any other
address is called over HTTPS or not at all.

## Before a commit

```bash
dart format --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

Nothing is committed while any of the three reports anything.

The vocabulary lives under `lib/core` and belongs to no feature. A screen that
needs a card, a state, a chip or a list footer composes one from there rather
than writing its own.

## Layout

```
lib/
  main.dart            reads the settings and picks the application to run
  app/                 the application widget, the shell and routing
  core/
    config/            the settings read from the environment
    forms/             the fields of a form, and when it starts refusing
    state/             the notifier a screen's calls answer to
    theme/             the measurement and drawing this client adds to the brand
    widgets/           the controls every screen reuses
  features/
    <feature>/
      data/            the repository over the API client and its queries
      presentation/    the screens and the notifier behind them
```

The contract, the session and the brand come from `packages/gostio_core`,
through the one library it publishes.

Dependencies point one way: `presentation` reaches `data`, `data` reaches
`core`, and nothing reaches back. A feature may import another feature's `data`
and never its `presentation`. `test/architecture` fails the build if any of that
stops being true.

## Identity

`ba.gostio.mobile` is the application id and it does not change: a Maps key's
application restriction and the Firebase Android registration are both issued
against it.
