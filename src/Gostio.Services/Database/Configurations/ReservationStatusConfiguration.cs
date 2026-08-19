using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ReservationStatusConfiguration : LookupEntityConfiguration<ReservationStatus>
{
    public override void Configure(EntityTypeBuilder<ReservationStatus> builder)
    {
        base.Configure(builder);

        // A closed set, so no row is ever inserted at runtime and the ids stay
        // the ones the enum names.
        builder
            .Property(status => status.Id)
            .ValueGeneratedNever();

        builder
            .Property(status => status.Code)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Code);

        builder
            .Property(status => status.Description)
            .HasMaxLength(ColumnLengths.Description);

        builder
            .HasIndex(status => status.Code)
            .IsUnique();

        // Seeded here rather than with the demo data in the seeding step: the
        // enum names these ids, so the model is broken without the rows, and
        // they belong in the migration that creates the table.
        builder.HasData(
            Row(ReservationStatusCode.Pending,
                "Held until the payment deadline, after which the place is free again."),
            Row(ReservationStatusCode.Confirmed,
                "Paid for. It holds a place until it is cancelled or completed."),
            Row(ReservationStatusCode.Cancelled,
                "Ended before it was used, by the guest, the host or an expired hold."),
            Row(ReservationStatusCode.Completed,
                "The stay or the term is over, which is what opens a review."));
    }

    // Name starts as the code and is the half an administrator may reword.
    private static ReservationStatus Row(ReservationStatusCode code, string description) =>
        new()
        {
            Id = (int)code,
            Code = code.ToString(),
            Name = code.ToString(),
            Description = description
        };
}
