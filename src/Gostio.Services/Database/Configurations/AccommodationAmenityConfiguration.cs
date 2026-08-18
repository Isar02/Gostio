using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class AccommodationAmenityConfiguration : IEntityTypeConfiguration<AccommodationAmenity>
{
    public void Configure(EntityTypeBuilder<AccommodationAmenity> builder)
    {
        // The pair is the key, so the same amenity cannot be listed twice.
        builder.HasKey(accommodationAmenity => new
        {
            accommodationAmenity.AccommodationId,
            accommodationAmenity.AmenityId
        });

        builder
            .HasOne(accommodationAmenity => accommodationAmenity.Accommodation)
            .WithMany(accommodation => accommodation.Amenities)
            .HasForeignKey(accommodationAmenity => accommodationAmenity.AccommodationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(accommodationAmenity => accommodationAmenity.Amenity)
            .WithMany(amenity => amenity.AccommodationAmenities)
            .HasForeignKey(accommodationAmenity => accommodationAmenity.AmenityId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
