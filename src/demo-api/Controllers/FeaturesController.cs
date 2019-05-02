using System.Collections.Generic;
using System.Threading.Tasks;
using demo_api.Features;
using KubeClient;
using KubeClient.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace demo_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FeaturesController : ControllerBase
    {
        public FeaturesController(
            IConfiguration config, 
            IOptionsSnapshot<FeatureFlags> featureFlags,
            IKubeApiClient kubeApiClient,
            ILogger<FeaturesController> logger)
        {
            FeatureFlags = featureFlags;
            KubeApiClient = kubeApiClient;
            Config = config;
            Logger = logger;
        }

        public IOptionsSnapshot<FeatureFlags> FeatureFlags { get; }
        public IKubeApiClient KubeApiClient { get; }
        public IConfiguration Config { get; }
        public ILogger<FeaturesController> Logger { get; }

        [HttpGet]
        public async Task<List<KeyValuePair<string, string>>> Get()
        {
            var features = new List<KeyValuePair<string, string>>();
            ConfigMapV1 configMap = await KubeApiClient.ConfigMapsV1().Get("test", "default");
            if (configMap != null)
            {
                foreach(var name in configMap.Data.Keys)
                {
                    features.Add(new KeyValuePair<string, string>(name, configMap.Data[name]));
                }
            }
                
            return features;
        }

        [HttpGet("{name}")]
        public async Task<string> GetFeatureFlag([BindRequired]string name)
        {
            Logger.LogWarning("Getting feature flat: {name}", name);

            ConfigMapV1 configMap = await KubeApiClient.ConfigMapsV1().Get("test", "default");
            if (configMap != null)
            {
                if (configMap.Data.ContainsKey(name))
                {
                    var value = configMap.Data[name];
                    Logger.LogInformation("Found feature: {name}={value}", name, value);
                    return value;
                }
            }

            return "Unknown";
        }
    }
}
