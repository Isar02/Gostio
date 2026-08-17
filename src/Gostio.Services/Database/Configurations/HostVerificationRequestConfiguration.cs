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

        // Both paths restrict: this table is an audit trail, and deleting a
        // user must not be able to take the record of a decision with it.
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

        // A user may reapply after a decision, but may never have two open
        // applications at once. The filter is built from the enum so that
        // renumbering the values cannot silently disable the constraint.
        builder
            .HasIndex(request => request.UserId)
            .IsUnique()
            .HasFilter($"[{nameof(HostVerificationRequest.Status)}] = {(int)HostVerificationStatus.Pending}");

        // The administrator queue is the only list screen over this table.
        builder.HasIndex(request => request.Status);
    }
}
