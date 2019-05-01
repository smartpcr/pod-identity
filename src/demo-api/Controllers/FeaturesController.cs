using System.Collections.Generic;
using System.Threading.Tasks;
using demo_api.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace demo_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FeaturesController : ControllerBase
    {
        public FeaturesController(IConfiguration config, IOptions<FeatureFlags> featureFlags, ILogger<FeaturesController> logger)
        {
            FeatureFlags = featureFlags.Value;
            Config = config;
            Logger = logger;
        }

        public FeatureFlags FeatureFlags { get; }
        public IConfiguration Config { get; }
        public ILogger<FeaturesController> Logger { get; }

        [HttpGet]
        public Task<List<KeyValuePair<string, string>>> Get()
        {
            // return $"UsePodIdentity={FeatureFlags.UsePodIdentity}";
            var features = new List<KeyValuePair<string, string>>();

            foreach (var kvp in Config.AsEnumerable())
            {
                Logger.LogInformation("{key}={value}", kvp.Key, kvp.Value);
                //features.Add(new KeyValuePair<string, string>(kvp.Key, kvp.Value));
                if (kvp.Key.StartsWith("feature:"))
                {
                    var key = kvp.Key.Substring("feature:".Length);
                    features.Add(new KeyValuePair<string, string>(key, kvp.Value));
                }
            }

            return features;
        }
    }
}
