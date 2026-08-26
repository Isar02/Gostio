using Gostio.API.Authentication;
using Gostio.API.Hubs;
using Gostio.API.Middleware;
using Gostio.API.Swagger;
using Gostio.Services.Chat;
using Gostio.Services.Configuration;
using Gostio.Services.Database;
using Gostio.Services.Favorites;
using Gostio.Services.HostVerification;
using Gostio.Services.Listings;
using Gostio.Services.Lookups;
using Gostio.Services.Messaging;
using Gostio.Services.News;
using Gostio.Services.Notifications;
using Gostio.Services.Payments;
using Gostio.Services.Reservations;
using Gostio.Services.Reviews;
using Gostio.Services.Users;

var builder = WebApplication.CreateBuilder(args);

var settings = builder.Services.AddGostioConfiguration();

// Only when nothing higher in the ASP.NET precedence chain named a URL, so
// ASPNETCORE_URLS in the container and --urls on the command line both still win.
if (string.IsNullOrWhiteSpace(builder.Configuration[WebHostDefaults.ServerUrlsKey]))
{
    builder.WebHost.UseUrls($"http://localhost:{settings.Api.HttpPort}");
}

builder.Services.AddGostioDatabase(settings.Database);

builder.Services.AddControllers();
builder.Services.AddGostioLookupServices();
builder.Services.AddGostioListingServices();
builder.Services.AddGostioUserServices();
builder.Services.AddGostioReservationServices();
builder.Services.AddGostioPaymentServices();
builder.Services.AddGostioReviewServices();
builder.Services.AddGostioChatServices();
builder.Services.AddSignalR();
builder.Services.AddScoped<IChatBroadcast, ChatBroadcast>();
builder.Services.AddGostioFavoriteServices();
builder.Services.AddGostioHostVerificationServices();
builder.Services.AddGostioMessaging();
builder.Services.AddGostioNewsServices();
builder.Services.AddGostioNotificationServices();
builder.Services.AddGostioValidationErrors();
builder.Services.AddGostioAuthentication(settings.Jwt);
builder.Services.AddGostioSwagger();

const string CorsPolicyName = "GostioCorsPolicy";

builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy => policy
        .WithOrigins([.. settings.CorsAllowedOrigins])
        .AllowAnyHeader()
        .AllowAnyMethod());
});

var app = builder.Build();

await app.Services.InitialiseDatabaseAsync(settings);

// First in the pipeline, so nothing downstream can fail without a reply.
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseGostioStatusCodeErrors();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(CorsPolicyName);

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ChatHub>(ChatHubRoute.Path);

app.Run();
