using Gostio.Services.Configuration;
using Gostio.Services.Database;

var builder = WebApplication.CreateBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

// The container sets ASPNETCORE_URLS and owns its port; elsewhere the port comes
// from configuration, so it is declared once either way.
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

app.UseCors(CorsPolicyName);

app.MapControllers();

app.Run();
