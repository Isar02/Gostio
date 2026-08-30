# Gostio

Gostio is a booking platform for accommodations and experiences in Bosnia and
Herzegovina. A guest browses the two catalogues, books a stay or a term, pays
for it and talks to the host; a host manages their listings and the bookings
made against them; an administrator manages the reference data, the host
applications, the news and the reports.

Gostio consists of a working backend and two planned clients:

| Application | Audience | Location |
| --- | --- | --- |
| REST API and background worker | both clients | `src/` |
| Desktop client | administrators and hosts | `apps/gostio_desktop` |
| Mobile client | guests | `apps/gostio_mobile` |

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
- Flutter — only for the clients

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

## Running the clients

Neither client is built yet. The API above is what they are written against:
the desktop client reaches it on `localhost` and the Android emulator reaches
it on `10.0.2.2`, both through `API_BASE_URL`.

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
apps/                 desktop and mobile clients
```

## Technology

.NET 10 and ASP.NET Core, Entity Framework Core against SQL Server, Mapster,
Swashbuckle, JWT bearer authentication, BCrypt for password hashing, RabbitMQ
for messaging, MailKit for mail, Stripe for payments and refunds, SignalR for
chat, and Docker Compose for the whole stack. The clients are Flutter.

## Features

- Two catalogues — accommodations and experiences — with photos, amenities,
  availability ranges and bookable terms, searched and paged on the server.
- Bookings with a state machine, a hold that expires, and a background sweep
  that expires and completes them on a timer.
- Payments through Stripe, settled by a signed webhook, with refunds priced by
  a cancellation policy and sent by the worker.
- Reviews of finished stays, favourites, and host applications an administrator
  answers.
- Chat over SignalR, notifications, and email, both carried on durable queues.
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
the template and documents each value.
