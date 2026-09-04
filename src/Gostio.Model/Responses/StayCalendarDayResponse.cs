namespace Gostio.Model.Responses;

// One night of a stay: whether it can be booked and what it costs. It names no
// reservation and no guest, because occupancy is what a booking site shows and
// who booked is not.
public sealed class StayCalendarDayResponse
{
    public required DateOnly Date { get; init; }

    public required bool IsBookable { get; init; }

    public required decimal Price { get; init; }
}
