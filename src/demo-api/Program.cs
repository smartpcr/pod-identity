using demo_api.Features;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
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
                    var configMap = new ConfigMapOption();
                    config.Bind("ConfigMap", configMap);
                    configBuilder.AddFeatureFlags(configMap);
                })
                .UseStartup<Startup>();
            return builder;
        }
    }
}
