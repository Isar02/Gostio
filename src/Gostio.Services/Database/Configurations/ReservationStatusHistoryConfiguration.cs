using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ReservationStatusHistoryConfiguration
    : IEntityTypeConfiguration<ReservationStatusHistory>
{
    public void Configure(EntityTypeBuilder<ReservationStatusHistory> builder)
    {
        builder.HasKey(history => history.Id);

        builder
            .Property(history => history.Reason)
            .HasMaxLength(ColumnLengths.Reason);

        builder
            .HasOne(history => history.Reservation)
            .WithMany(reservation => reservation.StatusHistory)
            .HasForeignKey(history => history.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(history => history.PreviousStatus)
            .WithMany()
            .HasForeignKey(history => history.PreviousStatusId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(history => history.NewStatus)
            .WithMany()
            .HasForeignKey(history => history.NewStatusId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(history => history.ChangedByUser)
            .WithMany()
            .HasForeignKey(history => history.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(history => new { history.ReservationId, history.ChangedAt });

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_ReservationStatusHistory_Change",
                $"[{nameof(ReservationStatusHistory.PreviousStatusId)}] IS NULL"
                + $" OR [{nameof(ReservationStatusHistory.PreviousStatusId)}]"
                + $" <> [{nameof(ReservationStatusHistory.NewStatusId)}]");
        });
    }
}
