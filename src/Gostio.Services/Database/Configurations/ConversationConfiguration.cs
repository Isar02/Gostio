using Gostio.Model.Enums;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class ConversationConfiguration : IEntityTypeConfiguration<Conversation>
{
    public void Configure(EntityTypeBuilder<Conversation> builder)
    {
        builder.HasKey(conversation => conversation.Id);

        builder
            .HasOne(conversation => conversation.Reservation)
            .WithMany()
            .HasForeignKey(conversation => conversation.ReservationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder
            .HasIndex(conversation => conversation.ReservationId)
            .IsUnique()
            .HasFilter($"[{nameof(Conversation.ReservationId)}] IS NOT NULL");

        builder.ToTable(table =>
        {
            table.HasCheckConstraint(
                "CK_Conversations_Type",
                EnumCheckConstraint.Values<ConversationType>(nameof(Conversation.Type)));

            table.HasCheckConstraint(
                "CK_Conversations_SupportSubject",
                $"[{nameof(Conversation.Type)}] <> {(int)ConversationType.Support}"
                + $" OR [{nameof(Conversation.ReservationId)}] IS NULL");
        });
    }
}
