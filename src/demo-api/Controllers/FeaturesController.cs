using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace demo_api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FeaturesController : ControllerBase
    {
        public FeaturesController(IConfiguration config)
        {
            Config = config;
        }

        public IConfiguration Config { get; }

        [HttpGet]
        public async Task<IEnumerable<KeyValuePair<string, string>>> Get()
        {
            var features = new List<KeyValuePair<string, string>>();

            foreach(var kvp in Config.AsEnumerable())
            {
                if (kvp.Key.StartsWith("feature."))
                {
                    var key = kvp.Key.Substring("feature.".Length);
                    var value = kvp.Value;
                    features.Add(new KeyValuePair<string, string>(key, value));
                }
            }
            
            return features;
        }
    }
}
