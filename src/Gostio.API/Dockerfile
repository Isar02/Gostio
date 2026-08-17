# Build context is the repository root, so the shared projects are reachable.
#   docker build -f src/Gostio.API/Dockerfile .

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

# Restore first, using only the project files, so that the restore layer is
# reused whenever source code changes but dependencies do not.
COPY global.json .
COPY Gostio.sln .
COPY src/Gostio.Model/Gostio.Model.csproj src/Gostio.Model/
COPY src/Gostio.Services/Gostio.Services.csproj src/Gostio.Services/
COPY src/Gostio.API/Gostio.API.csproj src/Gostio.API/
COPY src/Gostio.Worker/Gostio.Worker.csproj src/Gostio.Worker/
RUN dotnet restore src/Gostio.API/Gostio.API.csproj

COPY src/ src/
RUN dotnet publish src/Gostio.API/Gostio.API.csproj \
    --configuration Release \
    --no-restore \
    --output /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

COPY --from=build /app .

# Plain HTTP inside the container; TLS termination is not used in this project.
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Gostio.API.dll"]
