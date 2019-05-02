using KubeClient;
using KubeClient.Extensions.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
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
            logger.LogWarning("setting up configmap: {@configMap}", configMap);

            KubeClientOptions clientOptions = KubeClientOptions.FromPodServiceAccount();
            builder.AddKubeConfigMap(clientOptions, configMapName: configMap.Name, configMap.Namespace, reloadOnChange: true);
            return builder;
        }

        public static IServiceCollection AddKubeClient(this IServiceCollection services, ILoggerFactory loggerFactory)
        {
            services.AddScoped<IKubeApiClient>(_ => {
                KubeClientOptions clientOptions = KubeClientOptions.FromPodServiceAccount();
                KubeApiClient client = KubeApiClient.Create(clientOptions, loggerFactory);
                return client;
            });

            return services;
        }
    }
}
