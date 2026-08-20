using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ReviewConfiguration : IEntityTypeConfiguration<Review>
{
    public void Configure(EntityTypeBuilder<Review> builder)
    {
        builder.HasKey(review => review.Id);

        builder
            .Property(review => review.Comment)
            .HasMaxLength(ColumnLengths.Comment);

        builder
            .HasOne(review => review.Reservation)
            .WithMany()
            .HasForeignKey(review => review.ReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        // One review per reservation. That the stay is over is a service rule,
        // because saying it here would name a status id inside the schema.
        builder
            .HasIndex(review => review.ReservationId)
            .IsUnique();

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Reviews_Rating",
                $"[{nameof(Review.Rating)}] BETWEEN 1 AND 5");
        });
    }
}
