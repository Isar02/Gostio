using Gostio.Services.Configuration;

var builder = WebApplication.CreateBuilder(args);

// Configuration is loaded once, here, and injected everywhere else.
var settings = builder.Services.AddGostioConfiguration();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// CORS is configured in exactly one place, with explicitly listed origins.
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

// HTTPS redirection is intentionally not enabled: the clients talk to the API
// over plain HTTP, which avoids self-signed certificate problems on the
// Android emulator and on a fresh Windows machine.

app.UseCors(CorsPolicyName);

app.MapControllers();

app.Run();
