using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ReservationConfiguration : IEntityTypeConfiguration<Reservation>
{
    public void Configure(EntityTypeBuilder<Reservation> builder)
    {
        builder.HasKey(reservation => reservation.Id);

        // Every foreign key restricts. Nothing a reservation points at may be
        // deleted out from under it, which is why listings and users are
        // deactivated instead.
        builder
            .HasOne(reservation => reservation.User)
            .WithMany(user => user.Reservations)
            .HasForeignKey(reservation => reservation.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(reservation => reservation.Accommodation)
            .WithMany()
            .HasForeignKey(reservation => reservation.AccommodationId)
            .OnDelete(DeleteBehavior.Restrict);

        // No collection on the slot either: counting taken places through a
        // navigation would count them in memory, which is exactly the read the
        // booking transaction must not do.
        builder
            .HasOne(reservation => reservation.ExperienceSlot)
            .WithMany()
            .HasForeignKey(reservation => reservation.ExperienceSlotId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(reservation => reservation.ReservationStatus)
            .WithMany()
            .HasForeignKey(reservation => reservation.ReservationStatusId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(reservation => reservation.UserId);

        // The overlap query always names one accommodation, so experience rows
        // are kept out of the index it uses.
        builder
            .HasIndex(reservation => new
            {
                reservation.AccommodationId,
                reservation.CheckInDate,
                reservation.CheckOutDate
            })
            .HasFilter($"[{nameof(Reservation.AccommodationId)}] IS NOT NULL");

        // The capacity count: one slot, filtered by status.
        builder
            .HasIndex(reservation => new
            {
                reservation.ExperienceSlotId,
                reservation.ReservationStatusId
            })
            .HasFilter($"[{nameof(Reservation.ExperienceSlotId)}] IS NOT NULL");

        // Serves the job that sweeps up expired holds.
        builder.HasIndex(reservation => reservation.ReservationStatusId);

        builder.ToTable(table =>
        {
            // Exactly one subject, with the dates that belong to it. An
            // experience reservation carries none, because the slot has them.
            table.HasCheckConstraint(
                "CK_Reservations_Subject",
                $"([{nameof(Reservation.AccommodationId)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.ExperienceSlotId)}] IS NULL"
                + $" AND [{nameof(Reservation.CheckInDate)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.CheckOutDate)}] IS NOT NULL)"
                + $" OR ([{nameof(Reservation.ExperienceSlotId)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.AccommodationId)}] IS NULL"
                + $" AND [{nameof(Reservation.CheckInDate)}] IS NULL"
                + $" AND [{nameof(Reservation.CheckOutDate)}] IS NULL)");

            table.HasCheckConstraint(
                "CK_Reservations_Dates",
                $"[{nameof(Reservation.CheckOutDate)}] IS NULL"
                + $" OR [{nameof(Reservation.CheckOutDate)}]"
                + $" > [{nameof(Reservation.CheckInDate)}]");

            table.HasCheckConstraint(
                "CK_Reservations_GuestCount",
                $"[{nameof(Reservation.GuestCount)}] > 0");

            // The invoice has to be rebuildable, so each side stores its own
            // parts and neither borrows the other's.
            table.HasCheckConstraint(
                "CK_Reservations_Charge",
                $"([{nameof(Reservation.AccommodationId)}] IS NULL"
                + $" OR ([{nameof(Reservation.AccommodationTotal)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.CleaningFee)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.PricePerPerson)}] IS NULL))"
                + $" AND ([{nameof(Reservation.ExperienceSlotId)}] IS NULL"
                + $" OR ([{nameof(Reservation.PricePerPerson)}] IS NOT NULL"
                + $" AND [{nameof(Reservation.AccommodationTotal)}] IS NULL"
                + $" AND [{nameof(Reservation.CleaningFee)}] IS NULL))");

            table.HasCheckConstraint(
                "CK_Reservations_Amounts",
                $"[{nameof(Reservation.TotalPrice)}] > 0"
                + $" AND ([{nameof(Reservation.AccommodationTotal)}] IS NULL"
                + $" OR [{nameof(Reservation.AccommodationTotal)}] > 0)"
                + $" AND ([{nameof(Reservation.CleaningFee)}] IS NULL"
                + $" OR [{nameof(Reservation.CleaningFee)}] >= 0)"
                + $" AND ([{nameof(Reservation.PricePerPerson)}] IS NULL"
                + $" OR [{nameof(Reservation.PricePerPerson)}] > 0)");

            table.HasCheckConstraint(
                "CK_Reservations_Expiry",
                $"[{nameof(Reservation.ExpiresAt)}]"
                + $" > [{nameof(Reservation.CreatedAt)}]");
        });
    }
}
