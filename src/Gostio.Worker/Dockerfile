# Build context is the repository root, so the shared projects are reachable.
#   docker build -f src/Gostio.Worker/Dockerfile .

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

COPY global.json .
COPY Gostio.sln .
COPY src/Gostio.Model/Gostio.Model.csproj src/Gostio.Model/
COPY src/Gostio.Services/Gostio.Services.csproj src/Gostio.Services/
COPY src/Gostio.API/Gostio.API.csproj src/Gostio.API/
COPY src/Gostio.Worker/Gostio.Worker.csproj src/Gostio.Worker/
RUN dotnet restore src/Gostio.Worker/Gostio.Worker.csproj

COPY src/ src/
RUN dotnet publish src/Gostio.Worker/Gostio.Worker.csproj \
    --configuration Release \
    --no-restore \
    --output /app

# The ASP.NET Core runtime image is used rather than the plain runtime image
# because the shared services layer depends on ASP.NET Core abstractions.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

COPY --from=build /app .

ENTRYPOINT ["dotnet", "Gostio.Worker.dll"]
