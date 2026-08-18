using Gostio.Services.Configuration;
using Gostio.Worker;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddGostioConfiguration();

builder.Services.AddHostedService<MessageConsumerService>();

var host = builder.Build();
host.Run();
