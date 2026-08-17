using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

/// <summary>
/// Rules every reference table shares. Derived configurations override
/// <see cref="Configure"/> and call the base implementation first when they
/// need to add columns or relationships of their own.
/// </summary>
public abstract class LookupEntityConfiguration<TEntity> : IEntityTypeConfiguration<TEntity>
    where TEntity : class, ILookupEntity
{
    public virtual void Configure(EntityTypeBuilder<TEntity> builder)
    {
        builder.HasKey(entity => entity.Id);

        builder
            .Property(entity => entity.Name)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Name);

        builder
            .HasIndex(entity => entity.Name)
            .IsUnique();
    }
}
