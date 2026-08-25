namespace Gostio.API.Hubs;

// Named once, because the authentication has to recognise it as well as the
// routing: a socket cannot send an Authorization header, so the token arrives
// in the query string and only on this path is it read from there.
public static class ChatHubRoute
{
    public const string Path = "/hubs/chat";
}
