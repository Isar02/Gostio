using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Reservations;

public static class ReservationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReservationServices(this IServiceCollection services)
    {
        services.AddScoped<IReservationTransitionService, ReservationTransitionService>();

        return services;
    }
}
