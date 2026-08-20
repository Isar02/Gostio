using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class FavoriteConfiguration : IEntityTypeConfiguration<Favorite>
{
    public void Configure(EntityTypeBuilder<Favorite> builder)
    {
        builder.HasKey(favorite => favorite.Id);

        // The one cascade from Users: a favourite is part of the guest who kept
        // it, not a record that has to outlive them. Both listings restrict, the
        // way everything pointing at a listing does.
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

        // One index per subject rather than one across both nullable columns:
        // each stays narrow and says on its own which duplicate it forbids.
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
            // Exactly one subject, as on Reservations.
            table.HasCheckConstraint(
                "CK_Favorites_Subject",
                $"([{nameof(Favorite.AccommodationId)}] IS NOT NULL"
                + $" AND [{nameof(Favorite.ExperienceId)}] IS NULL)"
                + $" OR ([{nameof(Favorite.ExperienceId)}] IS NOT NULL"
                + $" AND [{nameof(Favorite.AccommodationId)}] IS NULL)");
        });
    }
}
