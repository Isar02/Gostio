using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Reservations;
using Gostio.Worker;

var builder = Host.CreateApplicationBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

builder.Services.AddGostioDatabase(settings.Database);
builder.Services.AddGostioReservationSweep();

builder.Services.AddHostedService<MessageConsumerService>();
builder.Services.AddHostedService<ReservationSweepService>();

var host = builder.Build();
host.Run();
