using Microsoft.Extensions.DependencyInjection;

namespace Gostio.Services.Reservations;

public static class ReservationServiceCollectionExtensions
{
    public static IServiceCollection AddGostioReservationServices(this IServiceCollection services)
    {
        services.AddScoped<ReservationAccess>();
        services.AddScoped<ReservationPlaces>();
        services.AddScoped<IReservationService, ReservationService>();
        services.AddScoped<IReservationMoveService, ReservationMoveService>();
        services.AddScoped<IReservationTransitionService, ReservationTransitionService>();

        return services;
    }
}
