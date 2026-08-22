namespace Gostio.Services.Authentication;

// Services ask this who is calling instead of taking a user id from a route or
// a body, so an endpoint cannot be talked into acting for somebody else.
public interface ICurrentUser
{
    int? UserId { get; }

    int RequireUserId();
}
