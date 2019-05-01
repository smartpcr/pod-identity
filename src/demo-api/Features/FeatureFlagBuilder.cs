using KubeClient;
using KubeClient.Extensions.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace demo_api.Features
{
    public static class FeatureFlagBuilder
    {
        public static IConfigurationBuilder AddFeatureFlags(
            this IConfigurationBuilder builder, 
            ILoggerFactory loggerFactory,
            ConfigMapOption configMap)
        {
            var logger = loggerFactory.CreateLogger(typeof(FeatureFlagBuilder));
            logger.LogInformation("setting up configmap, {name}, {namespace}", configMap.Name, configMap.Namespace);

            KubeClientOptions clientOptions = KubeClientOptions.FromPodServiceAccount();
            builder.AddKubeConfigMap(clientOptions, configMapName: configMap.Name, reloadOnChange: true);
            return builder;
        }
    }
}
