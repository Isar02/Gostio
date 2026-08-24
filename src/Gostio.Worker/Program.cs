using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Payments;
using Gostio.Services.Reservations;
using Gostio.Worker;

var builder = Host.CreateApplicationBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

builder.Services.AddGostioDatabase(settings.Database);
builder.Services.AddGostioReservationSweep();
builder.Services.AddGostioRefundSweep();

builder.Services.AddHostedService<MessageConsumerService>();
builder.Services.AddHostedService<ReservationSweepService>();
builder.Services.AddHostedService<RefundSweepService>();

var host = builder.Build();
host.Run();
