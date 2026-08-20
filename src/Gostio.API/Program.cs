using Gostio.Services.Configuration;
using Gostio.Services.Database;

var builder = WebApplication.CreateBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

// The container sets ASPNETCORE_URLS and binds every interface; on a developer
// machine the port comes from .env, so it is configured in one place either way.
if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASPNETCORE_URLS")))
{
    builder.WebHost.UseUrls($"http://localhost:{settings.Api.HttpPort}");
}

builder.Services.AddGostioDatabase(settings.Database);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

const string CorsPolicyName = "GostioCorsPolicy";

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy => policy
        .WithOrigins([.. settings.CorsAllowedOrigins])
        .AllowAnyHeader()
        .AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// No HTTPS redirection: plain HTTP avoids self-signed certificate trouble on the Android emulator.

app.UseCors(CorsPolicyName);

app.MapControllers();

app.Run();
