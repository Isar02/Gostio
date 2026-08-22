namespace Gostio.Services.Authentication;

public sealed record TokenSubject(
    int UserId,
    string Username,
    string Email,
    int TokenVersion,
    IReadOnlyList<string> Roles);
