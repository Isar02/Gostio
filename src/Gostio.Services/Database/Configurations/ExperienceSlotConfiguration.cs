using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ExperienceSlotConfiguration : IEntityTypeConfiguration<ExperienceSlot>
{
    public void Configure(EntityTypeBuilder<ExperienceSlot> builder)
    {
        builder.HasKey(slot => slot.Id);

        builder
            .HasOne(slot => slot.Experience)
            .WithMany(experience => experience.Slots)
            .HasForeignKey(slot => slot.ExperienceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(slot => new { slot.ExperienceId, slot.StartTime });

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_ExperienceSlots_Capacity",
                $"[{nameof(ExperienceSlot.Capacity)}] > 0");

            table.HasCheckConstraint(
                "CK_ExperienceSlots_Duration",
                $"[{nameof(ExperienceSlot.DurationMinutes)}] > 0");
        });
    }
}
