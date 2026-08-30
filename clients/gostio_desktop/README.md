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
dart format --output=none --set-exit-if-changed lib
flutter analyze --fatal-infos --fatal-warnings
```

Nothing is committed while either reports anything.

## Layout

```
lib/
  main.dart            reads the settings and picks the application to run
  app/                 the application widget, the shell and routing
  core/
    authorization/     the role names, matching the ones the server writes
    config/            the settings read from the environment
    models/            the shapes core itself reads, and the ones every module needs
    network/           the API client, its interceptors and its exception
    session/           the signed in account and its roles
    theme/             the colour, type and spacing tokens
    validation/        the client side mirror of the server's rules
    widgets/           the controls every screen reuses
  features/
    <feature>/
      data/            the response models and the repository over the client
      presentation/    the screens and the notifier behind them
```

Dependencies point one way: `presentation` reaches `data`, `data` reaches
`core`, and nothing reaches back. A feature may import another feature's `data`
and never its `presentation`. `core` holds no business rules: the server owns
them, so the session holds state and the repositories make the calls.
