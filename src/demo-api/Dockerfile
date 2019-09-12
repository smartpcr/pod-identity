FROM mcr.microsoft.com/dotnet/core/aspnet:2.2 AS base
WORKDIR /app
# EXPOSE 80

FROM mcr.microsoft.com/dotnet/core/sdk:2.2 AS build
WORKDIR /src
COPY ["demo-api.csproj", "."]
RUN dotnet restore "demo-api.csproj"
COPY . .
RUN dotnet build "demo-api.csproj" -c Release -o /app

FROM build AS publish
RUN dotnet publish "demo-api.csproj" -c Release -o /app

FROM base AS final
# ARG client_id
# ENV client_id=${client_id}
# ARG vault_name
# ENV vault_name=${vault_name}
# ARG client_secret
# ENV client_secret=${client_secret}

WORKDIR /app
COPY --from=publish /app .
ENTRYPOINT ["dotnet", "demo-api.dll"]