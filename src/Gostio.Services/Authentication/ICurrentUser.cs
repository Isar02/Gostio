namespace Gostio.Services.Authentication;

public interface ICurrentUser
{
    int? UserId { get; }

    int RequireUserId();

    bool IsInRole(string role);
}
