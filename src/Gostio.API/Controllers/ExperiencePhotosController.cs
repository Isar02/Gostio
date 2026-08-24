using Gostio.Services.Listings;
using Microsoft.AspNetCore.Mvc;

namespace Gostio.API.Controllers;

[ApiController]
[Route("api/experiences/{listingId:int}/photos")]
public sealed class ExperiencePhotosController(IExperiencePhotoService photos)
    : ListingPhotosControllerBase<IExperiencePhotoService>(photos);
