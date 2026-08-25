using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Gostio.Services.Migrations
{
    public partial class AddConversationOwner : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "OpenedByUserId",
                table: "Conversations",
                type: "int",
                nullable: true);

            migrationBuilder.Sql(
                """
                UPDATE [conversation]
                SET [OpenedByUserId] = [owner].[UserId]
                FROM [Conversations] AS [conversation]
                CROSS APPLY
                (
                    SELECT TOP (1) [participant].[UserId]
                    FROM [ConversationParticipants] AS [participant]
                    WHERE [participant].[ConversationId] = [conversation].[Id]
                    ORDER BY
                        [participant].[JoinedAt],
                        CASE WHEN [participant].[UserId] =
                        (
                            SELECT TOP (1) [message].[SenderUserId]
                            FROM [Messages] AS [message]
                            WHERE [message].[ConversationId] = [conversation].[Id]
                            ORDER BY [message].[SentAt], [message].[Id]
                        ) THEN 0 ELSE 1 END,
                        [participant].[UserId]
                ) AS [owner]
                """);

            migrationBuilder.AlterColumn<int>(
                name: "OpenedByUserId",
                table: "Conversations",
                type: "int",
                nullable: false,
                oldClrType: typeof(int),
                oldType: "int",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Conversations_OpenedByUserId",
                table: "Conversations",
                column: "OpenedByUserId",
                unique: true,
                filter: "[Type] = 2");

            migrationBuilder.AddForeignKey(
                name: "FK_Conversations_Users_OpenedByUserId",
                table: "Conversations",
                column: "OpenedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Conversations_Users_OpenedByUserId",
                table: "Conversations");

            migrationBuilder.DropIndex(
                name: "IX_Conversations_OpenedByUserId",
                table: "Conversations");

            migrationBuilder.DropColumn(
                name: "OpenedByUserId",
                table: "Conversations");
        }
    }
}
