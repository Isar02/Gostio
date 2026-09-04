# Gostio

Gostio is a booking platform for accommodations and experiences in Bosnia and
Herzegovina. A guest browses the two catalogues, books a stay or a term, pays
for it and talks to the host; a host manages their listings and the bookings
made against them; an administrator manages the reference data, the host
applications, the news and the reports.

Gostio consists of a backend, a desktop client and a mobile client:

| Application | Audience | Location | State |
| --- | --- | --- | --- |
| REST API and background worker | both clients | `src/` | built |
| Desktop client | administrators and hosts | `apps/gostio_desktop` | built |
| Mobile client | guests | `apps/gostio_mobile` | in progress |

The two clients share one package. `packages/gostio_core` holds what belongs to
the product rather than to a client — the response models, the API client and
its interceptors, the session, the validation rules mirroring the server's, the
date and money formats, the palette and the three bundled faces. What stays in
each client is measurement and drawing: its own spacing and type scales, its own
widgets, notifiers and repositories. A client imports the one library the
package publishes and nothing inside it.

## Test accounts

Created by the seeder the first time the API starts against an empty database.
Every one of them uses the password `test`, which is `SEED_DEFAULT_PASSWORD`
in `.env`.

| Username | Roles | Used for |
| --- | --- | --- |
| `desktop` | Administrator, Host | the desktop client |
| `mobile` | Guest | the mobile client |
| `administrator` | Administrator | a single-role check |
| `host` | Host | a single-role check |
| `guest` | Guest | a single-role check |

The seed writes eleven further accounts so the catalogue, the bookings and the
recommendations have data behind them. They use the same password.

## Prerequisites

- Docker Desktop
- .NET 10 SDK — only to build or test outside the containers
- Flutter 3.47 or later — only for the clients
- Android SDK and an emulator — only for the mobile client

## Running the stack

```bash
cp .env.example .env
```

Fill in the values the template leaves empty. `DB_NAME`, `DB_SA_PASSWORD`,
`JWT_KEY`, the two RabbitMQ credentials and `SEED_DEFAULT_PASSWORD` are needed
to start; the SMTP, Stripe and Google Maps values are needed only by the
features that call those services, and each of them names the value it is
missing rather than failing at start-up.

```bash
docker compose up -d --build
```

Four containers come up: SQL Server, RabbitMQ, the API and the worker. The API
creates its database, applies the migrations and seeds it on first start, so
nothing has to be run by hand. It listens on `http://localhost:${API_HTTP_PORT}`
— `5000` unless the template was changed — and serves Swagger at `/swagger`
while `ASPNETCORE_ENVIRONMENT` is `Development`.

Stripe settles a payment through a webhook, so a charge made locally confirms
its booking only while the Stripe CLI is forwarding:

```bash
stripe listen --forward-to http://localhost:5000/api/payments/webhook
```

The `whsec_...` value it prints on start-up is `STRIPE_WEBHOOK_SECRET`.

### Building and testing outside the containers

```bash
docker compose up -d gostio-db
dotnet build -warnaserror
dotnet test
```

The integration suite runs against the database container, so it has to be up.

## Running the desktop client

The API address is a compile-time constant, read through
`String.fromEnvironment`, so it is passed on every run and every build. A build
made without it starts and then says it was given no address, which is the only
thing it can honestly do.

```bash
cd apps/gostio_desktop
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
```

Sign in as `desktop` / `test`. That account holds both roles, so it opens on
the administrator panel with a switch to the host one beside the avatar.

Its own checks:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Running the mobile client

The address is passed the same way, and it is the one an Android emulator uses
to reach the host machine.

```bash
cd apps/gostio_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Its own checks are the desktop's three. Milestone C2 is complete: the client
has branded sign-in, registration, password recovery and session validation
screens, all exercised on the emulator against the running API, and the shared
widget vocabulary — cards, states, chips, sheets, the appending paged list and
the date range picker — that the catalogue flow composes from. That vocabulary
is C3 and is still in review: no screen draws it yet. C4, the five-tab shell,
is next.

## Building for release

The build carries the address the same way the run does, and the address is the
one the machine running the build output will use — `localhost` for Windows,
and the emulator's `10.0.2.2` for Android.

```bash
cd apps/gostio_desktop
flutter clean
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5000
```

```bash
cd apps/gostio_mobile
flutter clean
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

The Windows build writes `build/windows/x64/runner/Release`. `Gostio.exe` is
its entry point and the DLLs and the `data` folder beside it travel with it, so
the folder is what gets distributed rather than the executable alone. The
Android build writes one file, `build/app/outputs/flutter-apk/app-release.apk`,
signed with the debug keys so it installs from a build alone.

Build output stays out of the repository; it belongs on a GitHub Release.

## Repository layout

```
src/
  Gostio.API          REST API, SignalR hub, authentication, middleware
  Gostio.Model        requests, responses, enumerations, validation
  Gostio.Services     domain services, EF Core model, migrations, seeding
  Gostio.Worker       background service: reservation and refund sweeps, queue consumers
tests/
  Gostio.Tests        unit and API tests
  Gostio.IntegrationTests   endpoint tests against SQL Server
apps/
  gostio_desktop      Flutter desktop client for administrators and hosts
  gostio_mobile       Flutter Android client for guests
packages/
  gostio_core         the contract, the session and the brand both clients share
```

## Technology

.NET 10 and ASP.NET Core, Entity Framework Core against SQL Server, Mapster,
Swashbuckle, JWT bearer authentication, BCrypt for password hashing, RabbitMQ
for messaging, MailKit for mail, Firebase Cloud Messaging for mobile push,
Stripe for payments and refunds, SignalR for chat, and Docker Compose for the
whole stack. The clients are Flutter.

## Features

- Two catalogues — accommodations and experiences — with photos, amenities,
  availability ranges and bookable terms, searched and paged on the server.
- Bookings with a state machine, a hold that expires, and a background sweep
  that expires and completes them on a timer.
- Payments through Stripe, settled by a signed webhook, with refunds priced by
  a cancellation policy and sent by the worker.
- Reviews of finished stays, favourites, and host applications an administrator
  answers.
- Chat over SignalR, and notifications, email and mobile push each carried on a
  durable queue of its own.
- Explainable recommendations — see `recommender-dokumentacija.md`.
- Revenue and catalogue reports for the administrative client.

## Security

- JWT with signature validation, and sign-out that invalidates the token on the
  server rather than only dropping it on the client.
- Passwords hashed with BCrypt.
- Role-based authorisation, with ownership checked on every listing, booking,
  conversation and upload.
- Registration opens a guest account and carries no field that could grant a
  privilege.
- Uploaded images validated by their own bytes rather than by their extension.
- Five endpoints are reachable without a token: sign in, register, the two
  password-reset endpoints, and the payment webhook, which is authenticated by
  a signature over its raw body.

## Configuration

`.env` is gitignored and holds every secret the stack uses. `.env.example` is
the template and documents each value. Nothing in `src/`, `apps/` or
`appsettings.json` repeats any of them.

When a build is published, the filled-in `.env` travels beside the template as
a password-protected `.env-tajne.zip` in this folder — an encrypted archive, so
the password is what carries it rather than the file. It is made at that point
rather than kept in step with `.env` by hand, and it is not in the repository
yet.
