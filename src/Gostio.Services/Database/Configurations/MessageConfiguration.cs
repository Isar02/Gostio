using Gostio.Model.Validation;
using Gostio.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Gostio.Services.Database.Configurations;

public sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.HasKey(message => message.Id);

        builder
            .Property(message => message.Body)
            .IsRequired()
            .HasMaxLength(ColumnLengths.MessageBody);

        builder
            .HasOne(message => message.Conversation)
            .WithMany(conversation => conversation.Messages)
            .HasForeignKey(message => message.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder
            .HasOne(message => message.SenderUser)
            .WithMany()
            .HasForeignKey(message => message.SenderUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(message => new { message.ConversationId, message.SentAt });
    }
}
