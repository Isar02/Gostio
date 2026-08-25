using Gostio.Services.Favorites;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations/{listingId:int}/favorite")]
public sealed class AccommodationFavoriteController(IAccommodationFavoriteService favorites)
    : ListingFavoriteControllerBase<IAccommodationFavoriteService>(favorites);
