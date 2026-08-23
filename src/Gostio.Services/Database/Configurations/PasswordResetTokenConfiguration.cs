using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class PasswordResetTokenConfiguration : IEntityTypeConfiguration<PasswordResetToken>
{
    public void Configure(EntityTypeBuilder<PasswordResetToken> builder)
    {
        builder.HasKey(token => token.Id);

        builder
            .Property(token => token.TokenHash)
            .IsRequired()
            .HasMaxLength(ColumnLengths.TokenHash);

        builder
            .HasOne(token => token.User)
            .WithMany(user => user.PasswordResetTokens)
            .HasForeignKey(token => token.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasIndex(token => token.TokenHash)
            .IsUnique();

        builder.HasIndex(token => new { token.UserId, token.ExpiresAt });

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_PasswordResetTokens_Expiry",
                $"[{nameof(PasswordResetToken.ExpiresAt)}]"
                + $" > [{nameof(PasswordResetToken.CreatedAt)}]");
        });
    }
}
