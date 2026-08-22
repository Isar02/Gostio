namespace Gostio.Services.Authentication;

public sealed record IssuedToken(string Value, DateTime ExpiresAt);
