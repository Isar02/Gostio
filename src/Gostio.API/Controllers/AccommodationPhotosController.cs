using Gostio.Services.Listings;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/accommodations/{listingId:int}/photos")]
public sealed class AccommodationPhotosController(IAccommodationPhotoService photos)
    : ListingPhotosControllerBase<IAccommodationPhotoService>(photos);
