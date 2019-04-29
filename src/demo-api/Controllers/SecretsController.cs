using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.KeyVault;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace demo_api.Controllers
{
    public class VaultSetting
    {
        public string VaultName { get; set; }
        public string ClientId { get; set; }
        public string CertFile { get; set; }
    }

    [Route("api/[controller]")]
    [ApiController]
    public class SecretsController : ControllerBase
    {
        private readonly string _vaultUrl;

        public SecretsController(IKeyVaultClient kvClient, IOptions<VaultSetting> vaultSettings)
        {
            KeyVaultClient = kvClient;
            _vaultUrl = $"https://{vaultSettings.Value.VaultName}.vault.azure.net";
        }

        public IKeyVaultClient KeyVaultClient { get; }

        [HttpGet]
        public async Task<IEnumerable<KeyValuePair<string, string>>> Get()
        {
            var secrets = new List<KeyValuePair<string, string>>();
            var items = await KeyVaultClient.GetSecretsAsync(_vaultUrl);
            foreach(var item in items)
            {
                var secret = await KeyVaultClient.GetSecretAsync(item.Identifier.Identifier);
                secrets.Add(new KeyValuePair<string, string>(item.Id, secret.Value));
            }
            return secrets;
        }
    }
}
