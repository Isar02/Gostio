using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Gostio.Services.Database.Configurations;

// Every timestamp is written with DateTime.UtcNow, but SQL Server stores no
// zone and hands the value back as Unspecified, which serialises without the Z
// a client needs in order not to read it as local time.
internal sealed class UtcDateTimeConverter()
    : ValueConverter<DateTime, DateTime>(
        stored => stored,
        read => DateTime.SpecifyKind(read, DateTimeKind.Utc));
