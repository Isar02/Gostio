using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gostio.Services.Database;

// Every relationship in this assembly states OnDelete explicitly: the reservation
// graph reaches Users by more than one path, and SQL Server rejects multiple
// cascade paths to the same table.
public class GostioDbContext(DbContextOptions<GostioDbContext> options) : DbContext(options)
{
    // Keeps an unconfigured string column from silently becoming nvarchar(max).
    private const int DefaultStringLength = 256;

    private const int MoneyPrecision = 18;
    private const int MoneyScale = 2;

    public DbSet<User> Users => Set<User>();

    public DbSet<Role> Roles => Set<Role>();

    public DbSet<UserRole> UserRoles => Set<UserRole>();

    public DbSet<HostVerificationRequest> HostVerificationRequests => Set<HostVerificationRequest>();

    public DbSet<Accommodation> Accommodations => Set<Accommodation>();

    public DbSet<AccommodationPhoto> AccommodationPhotos => Set<AccommodationPhoto>();

    public DbSet<AccommodationAmenity> AccommodationAmenities => Set<AccommodationAmenity>();

    public DbSet<AccommodationAvailability> AccommodationAvailability => Set<AccommodationAvailability>();

    public DbSet<Experience> Experiences => Set<Experience>();

    public DbSet<ExperiencePhoto> ExperiencePhotos => Set<ExperiencePhoto>();

    public DbSet<ExperienceSlot> ExperienceSlots => Set<ExperienceSlot>();

    public DbSet<Reservation> Reservations => Set<Reservation>();

    public DbSet<ReservationStatusHistory> ReservationStatusHistory =>
        Set<ReservationStatusHistory>();

    public DbSet<Payment> Payments => Set<Payment>();

    public DbSet<Refund> Refunds => Set<Refund>();

    public DbSet<Review> Reviews => Set<Review>();

    public DbSet<Favorite> Favorites => Set<Favorite>();

    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();

    public DbSet<Country> Countries => Set<Country>();

    public DbSet<City> Cities => Set<City>();

    public DbSet<AccommodationType> AccommodationTypes => Set<AccommodationType>();

    public DbSet<AccommodationCategory> AccommodationCategories => Set<AccommodationCategory>();

    public DbSet<ExperienceCategory> ExperienceCategories => Set<ExperienceCategory>();

    public DbSet<Amenity> Amenities => Set<Amenity>();

    public DbSet<ReservationStatus> ReservationStatuses => Set<ReservationStatus>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<string>().HaveMaxLength(DefaultStringLength);
        configurationBuilder.Properties<decimal>().HavePrecision(MoneyPrecision, MoneyScale);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(GostioDbContext).Assembly);
    }
}
