using Newtonsoft.Json;

namespace demo_api.Features
{
    public class FeatureFlags
    {
        public string UsePodIdentity { get; set; }
    }

    public class ConfigMapOption
    {
        public string Name { get; set; }
        public string Namespace { get; set; }
    }
}
