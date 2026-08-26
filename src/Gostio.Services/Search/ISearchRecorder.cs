namespace Gostio.Services.Search;

public interface ISearchRecorder
{
    Task RecordAsync(
        SearchSignal signal,
        DateTime searchedAt,
        CancellationToken cancellationToken);
}
