using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class AccommodationConfiguration : IEntityTypeConfiguration<Accommodation>
{
    private const int CoordinatePrecision = 9;
    private const int CoordinateScale = 6;

    public void Configure(EntityTypeBuilder<Accommodation> builder)
    {
        builder.HasKey(accommodation => accommodation.Id);

        builder
            .Property(accommodation => accommodation.Title)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Title);

        builder
            .Property(accommodation => accommodation.Description)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Description);

        builder
            .Property(accommodation => accommodation.Address)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Address);

        builder
            .Property(accommodation => accommodation.Latitude)
            .HasPrecision(CoordinatePrecision, CoordinateScale);

        builder
            .Property(accommodation => accommodation.Longitude)
            .HasPrecision(CoordinatePrecision, CoordinateScale);

        builder
            .HasOne(accommodation => accommodation.Host)
            .WithMany(user => user.Accommodations)
            .HasForeignKey(accommodation => accommodation.HostId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(accommodation => accommodation.City)
            .WithMany()
            .HasForeignKey(accommodation => accommodation.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(accommodation => accommodation.AccommodationType)
            .WithMany()
            .HasForeignKey(accommodation => accommodation.AccommodationTypeId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(accommodation => accommodation.AccommodationCategory)
            .WithMany()
            .HasForeignKey(accommodation => accommodation.AccommodationCategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Accommodations_Capacity",
                $"[{nameof(Accommodation.MaxGuests)}] > 0"
                + $" AND [{nameof(Accommodation.Bedrooms)}] >= 0"
                + $" AND [{nameof(Accommodation.Bathrooms)}] >= 0");

            table.HasCheckConstraint(
                "CK_Accommodations_Prices",
                $"[{nameof(Accommodation.PricePerNight)}] > 0"
                + $" AND [{nameof(Accommodation.CleaningFee)}] >= 0");

            table.HasCheckConstraint(
                "CK_Accommodations_Coordinates",
                $"[{nameof(Accommodation.Latitude)}] BETWEEN -90 AND 90"
                + $" AND [{nameof(Accommodation.Longitude)}] BETWEEN -180 AND 180");
        });
    }
}
