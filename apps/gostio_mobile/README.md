# Gostio mobile client

The Android client for guests. Administrators and hosts are served by the
Windows client beside it.

## Current state

The client is complete. It signs in, registers, requests and spends a
password-reset code, signs out, and validates the active session whenever the
application returns to the foreground. Signed in, five tabs — Explore, For you,
Trips, Inbox and Profile — each hold their own stack over the shell: the two
catalogues searched, filtered and paged; a listing with its gallery, facts,
amenities, map, priced calendar and reviews; a booking against nights or a term
and the hold it comes back with; paying through the card sheet; trips ahead and
behind, cancelled with their refund quote; reviews written, changed and taken
back; favourites; explained recommendations; threads over the chat hub; notices
with the bell that polls for them and the news; the account with its picture,
its details and its password; and the application to host.

Every screen is composed from the widget vocabulary under `lib/core/widgets` —
cards and listing cards, section headers, chips, rating stars, the loading,
empty and error states, a bottom sheet and action bar, an appending paged list
that says how much of the whole it holds, a date range picker over a month grid,
and `ApiImage`. A screen that needs one of those takes it from there.

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
```

Started without it, or with an address that is not absolute http or https, the
client says which value is missing and stops rather than failing on the first
call.

Plain HTTP reaches `10.0.2.2` and `localhost` and nothing else; any other
address is called over HTTPS or not at all. That permission is in
`android/app/src/main/res/xml/network_security_config.xml` rather than in the
debug manifest, so the release build reaches the API the same way the debug one
does.

## Building for release

```bash
flutter clean
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

It writes one file, `build/app/outputs/flutter-apk/app-release.apk`, signed with
the debug keys so it installs from a build alone. The build is not shrunk, so no
plugin needs ProGuard rules kept beside it; turning minification on means
carrying the payment package's rules with it, or the card sheet fails at runtime
in a build that compiled cleanly.

Android's own release lint runs and reports no issues. It needs one narrow
exclusion to get that far: the payment plugin publishes lint rules of its own,
and their classpath pulls `com.google.android.gms:play-services-tapandpay`,
which Google serves only to approved partners, so `:stripe_android`'s
`lintVitalAnalyzeRelease` cannot resolve it from any public repository. The root
`build.gradle.kts` drops that one lint jar from every `*LintChecksClasspath`.

What is given up is Stripe's own extra lint rules over Stripe's own module. What
is kept is every Android check that gates a release build — over this
application's manifest, XML resources and Gradle configuration — which is what
was lost while lint was switched off wholesale. The exclusion touches the lint
classpath only; the payment SDK the application compiles and ships against is
untouched.

A release build is not done until it has been installed and driven:

```bash
adb uninstall ba.gostio.mobile
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The old version comes off first, because installing over it keeps the data of a
build nobody is delivering.

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
`core`, and nothing reaches back. A feature may import another feature's `data`.
It may compose another feature's `presentation` only when that feature is part
of the explicit shared-feature set in `test/architecture/layering_test.dart` —
currently `listing`, `booking`, `payment` and `messages`. The architecture tests
fail the build if a dependency points elsewhere or a new exception is not
recorded there deliberately.

## Identity

`ba.gostio.mobile` is the application id and it does not change: a Maps key's
application restriction and the Firebase Android registration are both issued
against it.
