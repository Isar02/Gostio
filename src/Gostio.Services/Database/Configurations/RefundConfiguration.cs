using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class RefundConfiguration : IEntityTypeConfiguration<Refund>
{
    public void Configure(EntityTypeBuilder<Refund> builder)
    {
        builder.HasKey(refund => refund.Id);

        builder
            .Property(refund => refund.StripeRefundId)
            .HasMaxLength(ColumnLengths.ExternalId);

        builder
            .Property(refund => refund.Reason)
            .HasMaxLength(ColumnLengths.Reason)
            .IsRequired();

        builder
            .Property(refund => refund.FailureReason)
            .HasMaxLength(ColumnLengths.Reason);

        builder
            .HasOne(refund => refund.Payment)
            .WithMany()
            .HasForeignKey(refund => refund.PaymentId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(refund => refund.PaymentId);

        builder
            .HasIndex(refund => refund.StripeRefundId)
            .IsUnique()
            .HasFilter($"[{nameof(Refund.StripeRefundId)}] IS NOT NULL");

        // One open or settled refund per payment, mirroring the payment index.
        // Refunding twice is the mistake that costs money, and a cancellation
        // decides one amount, so a retry waits until an attempt has failed.
        builder
            .HasIndex(refund => refund.PaymentId, "IX_Refunds_PaymentId_Open")
            .IsUnique()
            .HasFilter(
                $"[{nameof(Refund.Status)}] IN"
                + $" ({(int)RefundStatus.Pending}, {(int)RefundStatus.Succeeded})");

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Refunds_Amount",
                $"[{nameof(Refund.Amount)}] > 0");

            // A resolved refund records when it resolved, a pending one cannot.
            // That the refunded amounts stay within the payment is arithmetic
            // across rows, so it is the service's job rather than a constraint.
            table.HasCheckConstraint(
                "CK_Refunds_Processed",
                $"([{nameof(Refund.Status)}] = {(int)RefundStatus.Pending}"
                + $" AND [{nameof(Refund.ProcessedAt)}] IS NULL)"
                + $" OR ([{nameof(Refund.Status)}] <> {(int)RefundStatus.Pending}"
                + $" AND [{nameof(Refund.ProcessedAt)}] IS NOT NULL)");
        });
    }
}
