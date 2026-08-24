using Gostio.Services.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Stripe;

namespace Gostio.Services.Payments;

public static class PaymentServiceCollectionExtensions
{
    public static IServiceCollection AddGostioPaymentServices(this IServiceCollection services)
    {
        services.AddSingleton<IStripeClient>(provider =>
        {
            var stripe = provider.GetRequiredService<StripeSettings>();

            return stripe.CanReachTheProcessor
                ? new StripeClient(stripe.SecretKey)
                : throw new InvalidOperationException(
                    "Reaching the payment processor needs STRIPE_SECRET_KEY in the .env file.");
        });

        services.AddScoped<IPaymentGateway, StripePaymentGateway>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<IPaymentSettlement, PaymentSettlement>();
        services.AddScoped<IPaymentWebhook, StripeWebhook>();

        return services;
    }
}
