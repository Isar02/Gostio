using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class CountryConfiguration : LookupEntityConfiguration<Country>
{
    public override void Configure(EntityTypeBuilder<Country> builder)
    {
        base.Configure(builder);

        builder
            .Property(country => country.IsoCode)
            .IsRequired()
            .HasMaxLength(ColumnLengths.IsoCode)
            .IsFixedLength();

        builder
            .HasIndex(country => country.IsoCode)
            .IsUnique();
    }
}
