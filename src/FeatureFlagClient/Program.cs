using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using EnsureThat;
using HTTPlease;
using KubeClient;
using KubeClient.Models;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Serilog;

namespace FeatureFlagClient
{
    static class Program
    {
        static Program()
        {
            SynchronizationContext.SetSynchronizationContext(new SynchronizationContext());
        }

        static async Task<int> Main(string[] args)
        {
            ProgramOptions options = ProgramOptions.Parse(args);
            if (options == null)
                return ExitCodes.InvalidArguments;

            ILoggerFactory loggerFactory = ConfigureLogging(options);
            try
            {
                KubeClientOptions clientOptions = K8sConfig.Load().ToKubeClientOptions(defaultKubeNamespace: options.Namespace);
                if (options.Verbose)
                    clientOptions.LogPayloads = true;

                KubeApiClient client = KubeApiClient.Create(clientOptions, loggerFactory);

                Log.Information("Checking for existing ConfigMap '{Name}'...", options.Name);
                ConfigMapV1 configMap = await client.ConfigMapsV1().Get(options.Name, options.Namespace);
                if (configMap != null)
                {
                    Log.Information("Found existing ConfigMap...");
                    configMap.Data[options.Key] = options.Value;

                    // Replace the entire Data dictionary (otherwise, use an untyped JsonPatchDocument).
                    await client.ConfigMapsV1().Update(options.Name, patch =>
                    {
                        patch.Replace(patchConfigMap => patchConfigMap.Data, value: configMap.Data);
                    });
                    Log.Information("Existing ConfigMap updated: {Key}={Value}.", options.Key, options.Value);
                }
                else
                {
                    if (!File.Exists(options.JsonFile))
                    {
                        Log.Error("Unable to find file: {JsonFile}", options.JsonFile);
                        return ExitCodes.InvalidArguments;
                    }

                    Log.Information("Creating new ConfigMap {Name}...", options.Name);
                    var data = JsonConvert.DeserializeObject<Dictionary<string, string>>(File.ReadAllText(options.JsonFile));

                    var configMapToCreate = new ConfigMapV1
                    {
                        Metadata = new ObjectMetaV1
                        {
                            Name = options.Name,
                            Namespace = options.Namespace
                        }
                    };
                    foreach (var key in data.Keys)
                    {
                        configMapToCreate.Data.Add(key, data[key]);
                    }

                    configMap = await client.ConfigMapsV1().Create(configMapToCreate);
                    
                    Log.Information("New ConfigMap created: {@configMap}", configMap);
                }

                Console.WriteLine("Done!");
                Console.ReadLine();

                return ExitCodes.Success;
            }
            catch (HttpRequestException<StatusV1> kubeError)
            {
                Log.Error(kubeError, "Kubernetes API error: {@Status}", kubeError.Response);

                return ExitCodes.UnexpectedError;
            }
            catch (Exception unexpectedError)
            {
                Log.Error(unexpectedError, "Unexpected error.");

                return ExitCodes.UnexpectedError;
            }
        }

        static ILoggerFactory ConfigureLogging(ProgramOptions options)
        {
            Ensure.That(options, nameof(options)).IsNotNull();
            
            var loggerConfiguration = new LoggerConfiguration()
                .MinimumLevel.Information()
                .WriteTo.Console(
                    outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:l}{NewLine}{Exception}"
                );

            if (options.Verbose)
                loggerConfiguration.MinimumLevel.Verbose();

            Log.Logger = loggerConfiguration.CreateLogger();

            return new LoggerFactory().AddSerilog(Log.Logger);
        }
    }

    public static class ExitCodes
    {
        public const int Success = 0;
        public const int InvalidArguments = 1;
        public const int UnexpectedError = 5;
    }
}
