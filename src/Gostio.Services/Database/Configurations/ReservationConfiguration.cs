using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ReservationConfiguration : IEntityTypeConfiguration<Reservation>
{
    public void Configure(EntityTypeBuilder<Reservation> builder)
    {
        builder.HasKey(reservation => reservation.Id);

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

        builder
            .HasIndex(reservation => new
            {
                reservation.AccommodationId,
                reservation.CheckInDate,
                reservation.CheckOutDate
            })
            .HasFilter($"[{nameof(Reservation.AccommodationId)}] IS NOT NULL");

        builder
            .HasIndex(reservation => new
            {
                reservation.ExperienceSlotId,
                reservation.ReservationStatusId
            })
            .HasFilter($"[{nameof(Reservation.ExperienceSlotId)}] IS NOT NULL");

        builder
            .HasIndex(reservation => new
            {
                reservation.ReservationStatusId,
                reservation.ExpiresAt
            });

        builder.ToTable(table =>
        {
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
