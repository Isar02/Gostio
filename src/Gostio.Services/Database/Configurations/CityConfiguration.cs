using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class CityConfiguration : IEntityTypeConfiguration<City>
{
    public void Configure(EntityTypeBuilder<City> builder)
    {
        builder.HasKey(city => city.Id);

        builder
            .Property(city => city.Name)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Name);

        builder
            .HasIndex(city => new { city.CountryId, city.Name })
            .IsUnique();

        builder
            .HasOne(city => city.Country)
            .WithMany(country => country.Cities)
            .HasForeignKey(city => city.CountryId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
