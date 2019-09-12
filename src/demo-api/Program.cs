using demo_api.Features;
using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Serilog;
using System.IO;
using Microsoft.AspNetCore.Server.Kestrel.Https;
using System.Net;

namespace demo_api
{
    public static class WebHostBuilderEx
    {
        public static IWebHostBuilder UseKestrel(this IWebHostBuilder hostBuilder, int port)
        {
            return hostBuilder.UseKestrel(options =>
            {
                options.Listen(new IPEndPoint(IPAddress.Any, port));
            });
        }
    }

    public class Program
    {
        public static void Main(string[] args)
        {
            CreateWebHostBuilder(args).Build().Run();
        }

        public static IWebHostBuilder CreateWebHostBuilder(string[] args)
        {
            var loggerFactory = ConfigureLogging();

            var builder = WebHost.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((_, configBuilder) =>
                {
                    configBuilder.SetBasePath(Directory.GetCurrentDirectory());
                    configBuilder.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
                    var config = configBuilder.Build();
                    var configMap = new ConfigMapOption();
                    config.Bind("ConfigMap", configMap);
                    configBuilder.AddFeatureFlags(loggerFactory, configMap);
                })
                .UseStartup<Startup>()
                .UseKestrel(6010);
            return builder;
        }

        static ILoggerFactory ConfigureLogging()
        {
            var loggerConfiguration = new LoggerConfiguration()
                .MinimumLevel.Information()
                .WriteTo.Console(
                    outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:l}{NewLine}{Exception}"
                );
            Log.Logger = loggerConfiguration.CreateLogger();
            return new LoggerFactory().AddSerilog(Log.Logger);
        }
    }
}
