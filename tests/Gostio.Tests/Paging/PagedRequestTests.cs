using Gostio.Model.Requests;

namespace Gostio.Tests.Paging;

public class PagedRequestTests
{
    [Theory]
    [InlineData(0, 1)]
    [InlineData(-7, 1)]
    [InlineData(1, 1)]
    [InlineData(42, 42)]
    public void PageNeverFallsBelowOne(int requested, int expected)
    {
        Assert.Equal(expected, new PagedRequest { Page = requested }.Page);
    }

    [Theory]
    [InlineData(0, 1)]
    [InlineData(-3, 1)]
    [InlineData(50, 50)]
    [InlineData(1000, PagedRequest.MaxPageSize)]
    public void PageSizeStaysWithinItsBounds(int requested, int expected)
    {
        Assert.Equal(expected, new PagedRequest { PageSize = requested }.PageSize);
    }

    [Fact]
    public void PageSizeFallsBackWhenTheClientAsksForNothing()
    {
        Assert.Equal(PagedRequest.DefaultPageSize, new PagedRequest().PageSize);
    }

    [Fact]
    public void OffsetCountsTheRowsBeforeThePage()
    {
        Assert.Equal(75L, new PagedRequest { Page = 4, PageSize = 25 }.Offset);
    }

    // The regression: in int arithmetic this product wraps to a negative
    // offset, which the database refuses outright.
    [Fact]
    public void OffsetOfAVeryHighPageDoesNotOverflow()
    {
        var request = new PagedRequest
        {
            Page = int.MaxValue,
            PageSize = PagedRequest.MaxPageSize,
        };

        Assert.Equal((int.MaxValue - 1L) * PagedRequest.MaxPageSize, request.Offset);
        Assert.True(request.Offset > int.MaxValue);
    }
}
