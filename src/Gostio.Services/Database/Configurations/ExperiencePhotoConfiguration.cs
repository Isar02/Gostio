using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ExperiencePhotoConfiguration : IEntityTypeConfiguration<ExperiencePhoto>
{
    public void Configure(EntityTypeBuilder<ExperiencePhoto> builder)
    {
        builder.HasKey(photo => photo.Id);

        builder
            .Property(photo => photo.Image)
            .IsRequired();

        builder
            .HasOne(photo => photo.Experience)
            .WithMany(experience => experience.Photos)
            .HasForeignKey(photo => photo.ExperienceId)
            .OnDelete(DeleteBehavior.Cascade);

        // The gallery reads in this order. DisplayOrder is deliberately not
        // unique, because swapping two photos would then need a spare value.
        builder.HasIndex(photo => new { photo.ExperienceId, photo.DisplayOrder });

        // At most one cover per experience.
        builder
            .HasIndex(photo => photo.ExperienceId)
            .IsUnique()
            .HasFilter($"[{nameof(ExperiencePhoto.IsCover)}] = 1");
    }
}
