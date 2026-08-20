using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class FavoriteConfiguration : IEntityTypeConfiguration<Favorite>
{
    public void Configure(EntityTypeBuilder<Favorite> builder)
    {
        builder.HasKey(favorite => favorite.Id);

        builder
            .HasOne(favorite => favorite.User)
            .WithMany(user => user.Favorites)
            .HasForeignKey(favorite => favorite.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(favorite => favorite.Accommodation)
            .WithMany()
            .HasForeignKey(favorite => favorite.AccommodationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(favorite => favorite.Experience)
            .WithMany()
            .HasForeignKey(favorite => favorite.ExperienceId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasIndex(favorite => new { favorite.UserId, favorite.AccommodationId })
            .IsUnique()
            .HasFilter($"[{nameof(Favorite.AccommodationId)}] IS NOT NULL");

        builder
            .HasIndex(favorite => new { favorite.UserId, favorite.ExperienceId })
            .IsUnique()
            .HasFilter($"[{nameof(Favorite.ExperienceId)}] IS NOT NULL");

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Favorites_Subject",
                $"([{nameof(Favorite.AccommodationId)}] IS NOT NULL"
                + $" AND [{nameof(Favorite.ExperienceId)}] IS NULL)"
                + $" OR ([{nameof(Favorite.ExperienceId)}] IS NOT NULL"
                + $" AND [{nameof(Favorite.AccommodationId)}] IS NULL)");
        });
    }
}
