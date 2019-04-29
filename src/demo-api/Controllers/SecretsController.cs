using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.KeyVault;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using System.Collections.Generic;
using System.Linq;

namespace demo_api.Controllers
{
    public class VaultSetting
    {
        public string VaultName { get; set; }
    }

    [Route("api/[controller]")]
    [ApiController]
    public class SecretsController : ControllerBase
    {
        public SecretsController(IConfiguration config)
        {
            Config = config;
        }

        public IConfiguration Config { get; }

        [HttpGet]
        public ActionResult<IEnumerable<KeyValuePair<string, string>>> Get()
        {
            var secretNames = new List<KeyValuePair<string, string>>();
            foreach(var kvp in Config.AsEnumerable())
            {
                secretNames.Add(kvp);
            }
            return secretNames;
        }
    }
}
