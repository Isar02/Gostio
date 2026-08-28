using Gostio.Model.Enums;

namespace Gostio.Model.Requests;

public sealed class ListingReportRequest : ReportRangeRequest
{
    public SearchTarget? Target { get; set; }
}
