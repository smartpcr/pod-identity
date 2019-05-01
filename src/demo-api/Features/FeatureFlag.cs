using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Newtonsoft.Json;

namespace demo_api.Features
{
    public class FeatureFlag
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
