using Gostio.Model.Authorization;
using Gostio.Model.Requests;
using Gostio.Model.Responses;
using Gostio.Model.Validation;
using Gostio.Services.Users;

namespace Gostio.Tests.Users;

internal sealed class StubUsers : IUserService
{
    public static byte[] Bytes => [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

    public ImageUpload? LastImage { get; private set; }

    public int? LastImageOwner { get; private set; }

    public int? LastImageCleared { get; private set; }

    public bool MineWasNamed { get; private set; }

    public Task<PagedResult<UserResponse>> SearchAsync(
        UserSearchRequest search,
        CancellationToken cancellationToken) =>
        Task.FromResult(new PagedResult<UserResponse>
        {
            Items = [Row(1)],
            Page = search.Page,
            PageSize = search.PageSize,
            TotalCount = 1,
        });

    public Task<UserResponse> GetAsync(int id, CancellationToken cancellationToken) =>
        Task.FromResult(Row(id));

    public Task<UserResponse> GetMineAsync(CancellationToken cancellationToken) =>
        Task.FromResult(Row(1));

    public Task<UserResponse> UpdateMineAsync(
        UserUpdateRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Row(1));

    public Task<ImageContent> GetImageAsync(int id, CancellationToken cancellationToken) =>
        Task.FromResult(new ImageContent(Bytes, ImageRules.Jpeg));

    public Task<UserResponse> SetImageAsync(
        int id,
        ImageUpload upload,
        CancellationToken cancellationToken)
    {
        LastImageOwner = id;
        LastImage = upload;

        return Task.FromResult(Row(id));
    }

    public Task<UserResponse> SetMineImageAsync(
        ImageUpload upload,
        CancellationToken cancellationToken)
    {
        MineWasNamed = true;
        LastImage = upload;

        return Task.FromResult(Row(1));
    }

    public Task ClearImageAsync(int id, CancellationToken cancellationToken)
    {
        LastImageCleared = id;

        return Task.CompletedTask;
    }

    public Task ClearMineImageAsync(CancellationToken cancellationToken)
    {
        MineWasNamed = true;

        return Task.CompletedTask;
    }

    public Task<UserResponse> CreateAsync(
        UserCreateRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Row(9));

    public Task<UserResponse> UpdateAsync(
        int id,
        UserUpdateRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Row(id));

    public Task<UserResponse> SetRolesAsync(
        int id,
        UserRolesRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Row(id));

    public Task<UserResponse> SetStateAsync(
        int id,
        UserStateRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Row(id));

    public Task DeleteAsync(int id, CancellationToken cancellationToken) =>
        Task.CompletedTask;

    private static UserResponse Row(int id) => new()
    {
        Id = id,
        FirstName = "Amina",
        LastName = "Kovačević",
        Username = "amina.kovacevic",
        Email = "amina.kovacevic@example.com",
        PhoneNumber = null,
        HasProfileImage = true,
        IsActive = true,
        Roles = [RoleNames.Guest],
        CreatedAt = DateTime.UtcNow,
    };
}
