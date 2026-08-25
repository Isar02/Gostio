namespace Gostio.Services.Messaging;

public sealed class PermanentMessageFailure(string message) : Exception(message);
