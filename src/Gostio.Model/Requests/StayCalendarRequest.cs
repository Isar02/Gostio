namespace Gostio.Model.Requests;

public sealed class StayCalendarRequest
{
    public DateOnly? From { get; set; }

    public DateOnly? To { get; set; }
}
