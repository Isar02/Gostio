namespace Gostio.Model.Responses;

public sealed class AuthResponse
{
    public required string Token { get; init; }

    public required DateTime ExpiresAt { get; init; }

    public required UserResponse User { get; init; }
}
