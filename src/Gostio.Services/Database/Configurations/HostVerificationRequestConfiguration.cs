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

        builder
            .HasOne(request => request.User)
            .WithMany(user => user.HostVerificationRequests)
            .HasForeignKey(request => request.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // The reviewing administrator is a second path into Users, which is why
        // no relationship in this model may cascade by convention.
        builder
            .HasOne(request => request.ReviewedByUser)
            .WithMany()
            .HasForeignKey(request => request.ReviewedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        // The administrator queue is the only list screen over this table.
        builder.HasIndex(request => request.Status);
    }
}
