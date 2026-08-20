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

        // Seeded here, not with the demo data: ReservationStatusCode names these
        // ids and the model is broken without the rows.
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

    private static ReservationStatus Row(ReservationStatusCode code, string description) =>
        new()
        {
            Id = (int)code,
            Code = code.ToString(),
            Name = code.ToString(),
            Description = description
        };
}
