using Gostio.Model.Validation;
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
            .Property(photo => photo.ContentType)
            .IsRequired()
            .HasMaxLength(ColumnLengths.ContentType);

        builder
            .HasOne(photo => photo.Experience)
            .WithMany(experience => experience.Photos)
            .HasForeignKey(photo => photo.ExperienceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(photo => new { photo.ExperienceId, photo.DisplayOrder });

        builder
            .HasIndex(photo => photo.ExperienceId)
            .IsUnique()
            .HasFilter($"[{nameof(ExperiencePhoto.IsCover)}] = 1");
    }
}
