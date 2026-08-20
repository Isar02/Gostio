using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ExperienceConfiguration : IEntityTypeConfiguration<Experience>
{
    private const int CoordinatePrecision = 9;
    private const int CoordinateScale = 6;

    public void Configure(EntityTypeBuilder<Experience> builder)
    {
        builder.HasKey(experience => experience.Id);

        builder
            .Property(experience => experience.Title)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Title);

        builder
            .Property(experience => experience.Description)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Description);

        builder
            .Property(experience => experience.MeetingPoint)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Address);

        // The (18, 2) the context gives every decimal would round a coordinate
        // away, so both get their own precision.
        builder
            .Property(experience => experience.Latitude)
            .HasPrecision(CoordinatePrecision, CoordinateScale);

        builder
            .Property(experience => experience.Longitude)
            .HasPrecision(CoordinatePrecision, CoordinateScale);

        // A host with experiences cannot be deleted, only deactivated.
        builder
            .HasOne(experience => experience.Host)
            .WithMany(user => user.Experiences)
            .HasForeignKey(experience => experience.HostId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(experience => experience.City)
            .WithMany()
            .HasForeignKey(experience => experience.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(experience => experience.ExperienceCategory)
            .WithMany()
            .HasForeignKey(experience => experience.ExperienceCategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Experiences_Duration",
                $"[{nameof(Experience.DurationMinutes)}] > 0");

            table.HasCheckConstraint(
                "CK_Experiences_Price",
                $"[{nameof(Experience.PricePerPerson)}] > 0");

            table.HasCheckConstraint(
                "CK_Experiences_Coordinates",
                $"[{nameof(Experience.Latitude)}] BETWEEN -90 AND 90"
                + $" AND [{nameof(Experience.Longitude)}] BETWEEN -180 AND 180");
        });
    }
}
