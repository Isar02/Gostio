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

Nothing is committed while any of them reports anything.

## Layout

```
lib/
  main.dart            reads the settings and picks the application to run
  app/                 the application widget, the shell and routing
  core/
    authorization/     the role names, matching the ones the server writes
    config/            the settings read from the environment
    formatting/        the one place a date or a figure is printed
    models/            the shapes core itself reads, and the ones every module needs
    network/           the API client, its interceptors and its exception
    paging/            the list state every screen with a table reuses
    session/           the signed in account and its roles
    theme/             the colour, type, spacing and tone tokens, and the theme
    validation/        the client side mirror of the server's rules
    widgets/           the controls every screen reuses
  features/
    <feature>/
      data/            the response models and the repository over the client
      presentation/    the screens and the notifier behind them
assets/
  fonts/               Geist, Plus Jakarta Sans and Manrope, with their licences
```

Dependencies point one way: `presentation` reaches `data`, `data` reaches
`core`, and nothing reaches back. A feature may import another feature's `data`
freely. It may import what another feature *draws* only from `listings` and
`reference`, the two that publish widgets for other features to compose — the
photographs and the status of any listing, the city a form picks — and from no
other. `core` holds no business rules: the server owns them, so the session
holds state and the repositories make the calls.

`test/architecture/layering_test.dart` holds four of those directions — core
reaching a feature or the application, a feature reaching the application, a
data layer reaching a presentation one, and a feature reaching what a feature
outside the shared two draws — over every import and export in `lib`, and the
suite fails when one is crossed. Adding a feature to the shared list there is a
decision about the shape of the client rather than a way past a failing test.
