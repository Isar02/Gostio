using Gostio.Model.Enums;
using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.HasKey(device => device.Id);

        builder
            .Property(device => device.Token)
            .IsRequired()
            .HasMaxLength(ColumnLengths.DeviceToken);

        builder
            .HasOne(device => device.User)
            .WithMany(user => user.DeviceTokens)
            .HasForeignKey(device => device.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // One row per device rather than per device and account: a phone that
        // changes hands cannot hold two accounts' registrations at once.
        builder
            .HasIndex(device => device.Token)
            .IsUnique();

        builder.HasIndex(device => device.UserId);

        builder.ToTable(table => table.HasCheckConstraint(
            "CK_DeviceTokens_Platform",
            EnumCheckConstraint.Values<DevicePlatform>(nameof(DeviceToken.Platform))));
    }
}
