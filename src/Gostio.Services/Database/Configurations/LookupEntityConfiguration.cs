using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

// Rules every reference table shares. A derived configuration calls the base
// first when it adds columns or relationships of its own.
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
