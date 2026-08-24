using Gostio.Services.Configuration;
using Gostio.Services.Reservations;
using Microsoft.Extensions.DependencyInjection;
using Stripe;

namespace Gostio.Services.Payments;

public static class PaymentServiceCollectionExtensions
{
    public static IServiceCollection AddGostioPaymentServices(this IServiceCollection services)
    {
        services.AddGostioRefundSweep();

        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<IPaymentSettlement, PaymentSettlement>();
        services.AddScoped<IPaymentWebhook, StripeWebhook>();
        services.AddScoped<RefundService>();
        services.AddScoped<IRefundService>(
            provider => provider.GetRequiredService<RefundService>());
        services.AddScoped<ICancellationRefunds>(
            provider => provider.GetRequiredService<RefundService>());

        return services;
    }

    // What the worker needs and nothing else: the processor, and the pass that
    // hands it the refunds a cancellation already promised.
    public static IServiceCollection AddGostioRefundSweep(this IServiceCollection services)
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
        services.AddScoped<IRefundSweep, RefundSweep>();

        return services;
    }
}
