using Newtonsoft.Json;

namespace demo_api.Features
{
    public class FeatureFlags
    {
        [JsonProperty("usePodIdentity")]
        public bool UsePodIdentity { get; set; }
    }

    public class ConfigMapOption
    {
        public string Name { get; set; }
        public string Namespace { get; set; }
    }
}
