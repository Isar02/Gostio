using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class SearchHistoryConfiguration : IEntityTypeConfiguration<SearchHistory>
{
    public void Configure(EntityTypeBuilder<SearchHistory> builder)
    {
        builder.HasKey(search => search.Id);

        builder
            .Property(search => search.Term)
            .HasMaxLength(ColumnLengths.SearchTerm);

        builder
            .HasOne(search => search.User)
            .WithMany(user => user.SearchHistory)
            .HasForeignKey(search => search.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(search => search.City)
            .WithMany()
            .HasForeignKey(search => search.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(search => new { search.UserId, search.SearchedAt });

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_SearchHistory_Target",
                EnumCheckConstraint.Values<SearchTarget>(nameof(SearchHistory.Target)));

            table.HasCheckConstraint(
                "CK_SearchHistory_GuestCount",
                $"[{nameof(SearchHistory.GuestCount)}] IS NULL"
                + $" OR [{nameof(SearchHistory.GuestCount)}] > 0");

            table.HasCheckConstraint(
                "CK_SearchHistory_PriceRange",
                $"([{nameof(SearchHistory.MinPrice)}] IS NULL"
                + $" OR [{nameof(SearchHistory.MinPrice)}] >= 0)"
                + $" AND ([{nameof(SearchHistory.MaxPrice)}] IS NULL"
                + $" OR [{nameof(SearchHistory.MaxPrice)}] >= 0)"
                + $" AND ([{nameof(SearchHistory.MinPrice)}] IS NULL"
                + $" OR [{nameof(SearchHistory.MaxPrice)}] IS NULL"
                + $" OR [{nameof(SearchHistory.MaxPrice)}]"
                + $" >= [{nameof(SearchHistory.MinPrice)}])");
        });
    }
}
