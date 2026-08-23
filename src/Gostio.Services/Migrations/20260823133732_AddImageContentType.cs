using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Gostio.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddImageContentType : Migration
    {
        private const string SeededContentType = "image/jpeg";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Added nullable, filled, then closed. A required column with a
            // default would leave the default behind for every later insert,
            // and every row already stored holds a JPEG.
            AddContentType(migrationBuilder, "AccommodationPhotos", "ContentType");
            AddContentType(migrationBuilder, "ExperiencePhotos", "ContentType");
            AddContentType(migrationBuilder, "News", "ImageContentType");

            migrationBuilder.AddColumn<string>(
                name: "ProfileImageContentType",
                table: "Users",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.Sql(
                $"UPDATE [Users] SET [ProfileImageContentType] = '{SeededContentType}'"
                + " WHERE [ProfileImage] IS NOT NULL");

            // Last, so the rows it judges have already been filled.
            migrationBuilder.AddCheckConstraint(
                name: "CK_Users_ProfileImage",
                table: "Users",
                sql: "([ProfileImage] IS NULL AND [ProfileImageContentType] IS NULL)"
                    + " OR ([ProfileImage] IS NOT NULL AND [ProfileImageContentType] IS NOT NULL)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_Users_ProfileImage",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ProfileImageContentType",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "ImageContentType",
                table: "News");

            migrationBuilder.DropColumn(
                name: "ContentType",
                table: "ExperiencePhotos");

            migrationBuilder.DropColumn(
                name: "ContentType",
                table: "AccommodationPhotos");
        }

        private static void AddContentType(
            MigrationBuilder migrationBuilder,
            string table,
            string column)
        {
            migrationBuilder.AddColumn<string>(
                name: column,
                table: table,
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.Sql(
                $"UPDATE [{table}] SET [{column}] = '{SeededContentType}'");

            migrationBuilder.AlterColumn<string>(
                name: column,
                table: table,
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false);
        }
    }
}
