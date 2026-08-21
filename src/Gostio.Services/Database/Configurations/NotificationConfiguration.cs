using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.HasKey(notification => notification.Id);

        builder
            .Property(notification => notification.Title)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Title);

        builder
            .Property(notification => notification.Body)
            .IsRequired()
            .HasMaxLength(ColumnLengths.NotificationBody);

        builder
            .HasOne(notification => notification.User)
            .WithMany(user => user.Notifications)
            .HasForeignKey(notification => notification.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(notification => notification.Reservation)
            .WithMany()
            .HasForeignKey(notification => notification.ReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(notification => new { notification.UserId, notification.CreatedAt });

        builder
            .HasIndex(notification => notification.UserId)
            .HasFilter($"[{nameof(Notification.ReadAt)}] IS NULL");

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Notifications_Type",
                EnumCheckConstraint.Values<NotificationType>(nameof(Notification.Type)));

            table.HasCheckConstraint(
                "CK_Notifications_Subject",
                $"([{nameof(Notification.Type)}]"
                + $" = {(int)NotificationType.HostVerificationDecided}"
                + $" AND [{nameof(Notification.ReservationId)}] IS NULL)"
                + $" OR ([{nameof(Notification.Type)}]"
                + $" <> {(int)NotificationType.HostVerificationDecided}"
                + $" AND [{nameof(Notification.ReservationId)}] IS NOT NULL)");
        });
    }
}
