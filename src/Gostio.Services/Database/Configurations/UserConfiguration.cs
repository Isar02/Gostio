using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(user => user.Id);

        builder
            .Property(user => user.FirstName)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Name);

        builder
            .Property(user => user.LastName)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Name);

        builder
            .Property(user => user.Username)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Username);

        builder
            .Property(user => user.Email)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Email);

        builder
            .Property(user => user.PhoneNumber)
            .HasMaxLength(ColumnLengths.PhoneNumber);

        builder
            .Property(user => user.PasswordHash)
            .IsRequired()
            .HasMaxLength(ColumnLengths.PasswordHash);

        builder
            .HasIndex(user => user.Username)
            .IsUnique();

        builder
            .HasIndex(user => user.Email)
            .IsUnique();
    }
}
