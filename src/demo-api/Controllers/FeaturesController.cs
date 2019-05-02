using System.Collections.Generic;
using System.Threading.Tasks;
using demo_api.Features;
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
        public FeaturesController(IConfiguration config, IOptionsMonitor<FeatureFlags> featureFlags, ILogger<FeaturesController> logger)
        {
            FeatureFlags = featureFlags;
            Config = config;
            Logger = logger;
        }

        public IOptionsMonitor<FeatureFlags> FeatureFlags { get; }
        public IConfiguration Config { get; }
        public ILogger<FeaturesController> Logger { get; }

        [HttpGet]
        public List<KeyValuePair<string, string>> Get()
        {
            // return $"UsePodIdentity={FeatureFlags.UsePodIdentity}";
            var features = new List<KeyValuePair<string, string>>();

            foreach (var kvp in Config.AsEnumerable())
            {
                Logger.LogWarning("{key}={value}", kvp.Key, kvp.Value);
                features.Add(new KeyValuePair<string, string>(kvp.Key, kvp.Value));
                //if (kvp.Key.StartsWith("feature:"))
                //{
                //    var key = kvp.Key.Substring("feature:".Length);
                //    features.Add(new KeyValuePair<string, string>(key, kvp.Value));
                //}
            }

            return features;
        }

        [HttpGet("{name}")]
        public string GetFeatureFlag([BindRequired]string name)
        {
            Logger.LogWarning("Getting feature flat: {name}", name);

            if (name.Equals("UsePodIdentity"))
            {
                Logger.LogWarning("Returning feature flag: {name}={value}", name, FeatureFlags.CurrentValue.UsePodIdentity);
                return FeatureFlags.CurrentValue.UsePodIdentity;
            }

            return "Unknown";
        }
    }
}
