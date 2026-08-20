using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class PaymentConfiguration : IEntityTypeConfiguration<Payment>
{
    public void Configure(EntityTypeBuilder<Payment> builder)
    {
        builder.HasKey(payment => payment.Id);

        builder
            .Property(payment => payment.StripePaymentIntentId)
            .HasMaxLength(ColumnLengths.ExternalId);

        builder
            .Property(payment => payment.Currency)
            .HasMaxLength(ColumnLengths.CurrencyCode)
            .IsRequired();

        builder
            .Property(payment => payment.FailureReason)
            .HasMaxLength(ColumnLengths.Reason);

        // A financial record, so it outlives everything it points at. No
        // collection on the reservation either: whether it is paid is a
        // projection in a query, not a count over rows already loaded.
        builder
            .HasOne(payment => payment.Reservation)
            .WithMany()
            .HasForeignKey(payment => payment.ReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(payment => payment.ReservationId);

        // The last line of defence behind the webhook, which resolves a payment
        // with a conditional update and so already ignores a repeat delivery.
        builder
            .HasIndex(payment => payment.StripePaymentIntentId)
            .IsUnique()
            .HasFilter($"[{nameof(Payment.StripePaymentIntentId)}] IS NOT NULL");

        // One live payment per reservation. A decline leaves the row pending and
        // reuses its intent, so only a cancellation Stripe has confirmed frees
        // this index for a new one.
        builder
            .HasIndex(payment => payment.ReservationId, "IX_Payments_ReservationId_Open")
            .IsUnique()
            .HasFilter(
                $"[{nameof(Payment.Status)}] IN"
                + $" ({(int)PaymentStatus.Pending}, {(int)PaymentStatus.Succeeded})");

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Payments_Status",
                EnumCheckConstraint.Values<PaymentStatus>(nameof(Payment.Status)));

            table.HasCheckConstraint(
                "CK_Payments_Amount",
                $"[{nameof(Payment.Amount)}] > 0");

            // A resolved payment records when it resolved, a pending one cannot.
            table.HasCheckConstraint(
                "CK_Payments_Processed",
                $"([{nameof(Payment.Status)}] = {(int)PaymentStatus.Pending}"
                + $" AND [{nameof(Payment.ProcessedAt)}] IS NULL)"
                + $" OR ([{nameof(Payment.Status)}] <> {(int)PaymentStatus.Pending}"
                + $" AND [{nameof(Payment.ProcessedAt)}] IS NOT NULL)");
        });
    }
}
