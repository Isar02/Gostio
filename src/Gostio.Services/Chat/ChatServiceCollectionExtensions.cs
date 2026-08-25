using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Chat;

public static class ChatServiceCollectionExtensions
{
    public static IServiceCollection AddGostioChatServices(this IServiceCollection services)
    {
        services.AddScoped<ConversationAccess>();
        services.AddScoped<IConversationService, ConversationService>();
        services.AddScoped<IMessageService, MessageService>();

        return services;
    }
}
