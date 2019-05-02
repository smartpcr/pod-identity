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
using Newtonsoft.Json.Linq;
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
                    if (string.IsNullOrEmpty(options.Key) || string.IsNullOrEmpty(options.Value))
                    {
                        Log.Error("Key and value must be provided from command line");
                        return ExitCodes.InvalidArguments;
                    }

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
                    var jtoken = JToken.Parse(File.ReadAllText(options.JsonFile));
                    var settings = FlattenSettings(jtoken);

                    var configMapToCreate = new ConfigMapV1
                    {
                        Metadata = new ObjectMetaV1
                        {
                            Name = options.Name,
                            Namespace = options.Namespace
                        }
                    };
                    foreach (var key in settings.Keys)
                    {
                        configMapToCreate.Data.Add(key, settings[key]);
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


        private static Dictionary<string, string> FlattenSettings(JToken settings, string parentPath = null)
        {
            var output = new Dictionary<string, string>();
            if (settings is JValue val)
            {
                output.Add(parentPath, val.Value<string>());
            }
            if (settings is JProperty prop)
            {
                output.Add(prop.Name, prop.Value<string>());
            }
            if (settings is JObject obj)
            {
                foreach (JProperty property in obj.Properties())
                {
                    var childPath = string.IsNullOrEmpty(parentPath) ? property.Name : parentPath + "." + property.Name;
                    var childSettings = FlattenSettings(property.Value, childPath);
                    if (childSettings != null && childSettings.Count > 0)
                    {
                        foreach (var key in childSettings.Keys)
                        {
                            output.Add(key, childSettings[key]);
                        }
                    }
                }
            }

            return output;
        }

    }

    public static class ExitCodes
    {
        public const int Success = 0;
        public const int InvalidArguments = 1;
        public const int UnexpectedError = 5;
    }
}
