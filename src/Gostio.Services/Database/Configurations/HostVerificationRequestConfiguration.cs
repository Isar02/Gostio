using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class HostVerificationRequestConfiguration : IEntityTypeConfiguration<HostVerificationRequest>
{
    public void Configure(EntityTypeBuilder<HostVerificationRequest> builder)
    {
        builder.HasKey(request => request.Id);

        builder
            .Property(request => request.DecisionReason)
            .HasMaxLength(ColumnLengths.Reason);

        // An audit trail: deleting a user must not take the record of a decision with it.
        builder
            .HasOne(request => request.User)
            .WithMany(user => user.HostVerificationRequests)
            .HasForeignKey(request => request.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasOne(request => request.ReviewedByUser)
            .WithMany()
            .HasForeignKey(request => request.ReviewedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        // A user may reapply after a decision but never hold two open applications.
        // The filter is built from the enum so renumbering cannot silently disable it.
        builder
            .HasIndex(request => request.UserId)
            .IsUnique()
            .HasFilter($"[{nameof(HostVerificationRequest.Status)}] = {(int)HostVerificationStatus.Pending}");

        builder.HasIndex(request => request.Status);

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_HostVerificationRequests_Status",
                EnumCheckConstraint.Values<HostVerificationStatus>(
                    nameof(HostVerificationRequest.Status)));
        });
    }
}
