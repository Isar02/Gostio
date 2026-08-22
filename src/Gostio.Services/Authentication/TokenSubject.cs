namespace Gostio.Services.Authentication;

// Everything a token says about who it belongs to, and nothing else: the hash
// and the rest of the row have no business reaching the signing code.
public sealed record TokenSubject(
    int UserId,
    string Username,
    string Email,
    int TokenVersion,
    IReadOnlyList<string> Roles);
