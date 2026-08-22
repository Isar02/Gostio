using Gostio.API.Authentication;
using Gostio.API.Middleware;
using Gostio.Services.Configuration;
using Gostio.Services.Database;

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
builder.Services.AddGostioValidationErrors();
builder.Services.AddGostioAuthentication(settings.Jwt);
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

app.Run();
