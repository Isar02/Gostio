using Gostio.Services.Favorites;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/experiences/{listingId:int}/favorite")]
public sealed class ExperienceFavoriteController(IExperienceFavoriteService favorites)
    : ListingFavoriteControllerBase<IExperienceFavoriteService>(favorites);
