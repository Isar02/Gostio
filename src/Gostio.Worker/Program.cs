using Gostio.Services.Configuration;
using Gostio.Worker;

var builder = Host.CreateApplicationBuilder(args);

// Same single configuration entry point the API uses.
builder.Services.AddGostioConfiguration();

builder.Services.AddHostedService<MessageConsumerService>();

var host = builder.Build();
host.Run();
