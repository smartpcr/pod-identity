using KubeClient;
using KubeClient.Extensions.Configuration;
using Microsoft.Extensions.Configuration;

namespace demo_api.Features
{
    public static class FeatureFlagBuilder
    {
        public static IConfigurationBuilder AddFeatureFlags(this IConfigurationBuilder builder, ConfigMapOption configMap)
        {
            KubeClientOptions clientOptions = KubeClientOptions.FromPodServiceAccount();
            builder.AddKubeConfigMap(clientOptions, configMapName: configMap.Name, reloadOnChange: true);
            return builder;
        }
    }
}
