using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class NewsConfiguration : IEntityTypeConfiguration<News>
{
    public void Configure(EntityTypeBuilder<News> builder)
    {
        builder.HasKey(news => news.Id);

        builder
            .Property(news => news.Title)
            .IsRequired()
            .HasMaxLength(ColumnLengths.Title);

        builder
            .Property(news => news.Body)
            .IsRequired()
            .HasMaxLength(ColumnLengths.NewsBody);

        builder
            .Property(news => news.Image)
            .IsRequired();

        builder
            .HasOne(news => news.CreatedByUser)
            .WithMany()
            .HasForeignKey(news => news.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(news => news.PublishedAt);
    }
}
