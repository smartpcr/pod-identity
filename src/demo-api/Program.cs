using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Azure.KeyVault;
using Microsoft.Azure.Services.AppAuthentication;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.AzureKeyVault;
using System.IO;

namespace demo_api
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateWebHostBuilder(args).Build().Run();
        }

        public static IWebHostBuilder CreateWebHostBuilder(string[] args)
        {
            var builder = WebHost.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((context, configBuilder) =>
                {
                    configBuilder.SetBasePath(Directory.GetCurrentDirectory());
                    configBuilder.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
                    configBuilder.AddEnvironmentVariables();
                    configBuilder.AddCommandLine(args);
                    var config = configBuilder.Build();

                    if (context.HostingEnvironment.IsProduction())
                    {
                        var azureServiceTokenProvider = new AzureServiceTokenProvider();
                        var keyVaultClient = new KeyVaultClient(
                            new KeyVaultClient.AuthenticationCallback(
                                azureServiceTokenProvider.KeyVaultTokenCallback));
                        configBuilder.AddAzureKeyVault(
                            $"https://{config["Vault:VaultName"]}.vault.azure.net",
                            keyVaultClient,
                            new DefaultKeyVaultSecretManager());
                    }
                    else
                    {
                        configBuilder.AddAzureKeyVault(
                            $"https://{config["Vault:VaultName"]}.vault.azure.net",
                            config["Vault:ClientId"],
                            config["Vault:ClientSecret"],
                            new DefaultKeyVaultSecretManager());
                    }
                })
                .UseStartup<Startup>();
            return builder;
        }
    }
}
