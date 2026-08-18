using Gostio.Services.Configuration;
using Gostio.Services.Database;

var builder = WebApplication.CreateBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

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
