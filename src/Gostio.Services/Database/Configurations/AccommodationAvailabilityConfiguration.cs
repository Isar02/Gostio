using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class AccommodationAvailabilityConfiguration
    : IEntityTypeConfiguration<AccommodationAvailability>
{
    public void Configure(EntityTypeBuilder<AccommodationAvailability> builder)
    {
        builder.HasKey(availability => availability.Id);

        builder
            .HasOne(availability => availability.Accommodation)
            .WithMany(accommodation => accommodation.Availability)
            .HasForeignKey(availability => availability.AccommodationId)
            .OnDelete(DeleteBehavior.Cascade);

        // Serves the calendar screen and the overlap check the reservation
        // service runs before it accepts a stay.
        builder.HasIndex(availability => new
        {
            availability.AccommodationId,
            availability.StartDate,
            availability.EndDate
        });

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_AccommodationAvailability_DateRange",
                $"[{nameof(AccommodationAvailability.EndDate)}]"
                + $" >= [{nameof(AccommodationAvailability.StartDate)}]");

            table.HasCheckConstraint(
                "CK_AccommodationAvailability_PriceOverride",
                $"[{nameof(AccommodationAvailability.PriceOverride)}] IS NULL"
                + $" OR [{nameof(AccommodationAvailability.PriceOverride)}] > 0");

            // A row must either block the dates or set a price, otherwise it says
            // nothing the base price does not already say. A blocked row may keep
            // its price, so unblocking it does not lose what the host typed.
            table.HasCheckConstraint(
                "CK_AccommodationAvailability_Purpose",
                $"[{nameof(AccommodationAvailability.IsAvailable)}] = 0"
                + $" OR [{nameof(AccommodationAvailability.PriceOverride)}] IS NOT NULL");
        });
    }
}
