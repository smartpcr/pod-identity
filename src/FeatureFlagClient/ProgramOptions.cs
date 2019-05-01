using System;
using System.Collections.Generic;
using System.Text;
using CommandLine;

namespace FeatureFlagClient
{
    class ProgramOptions
    {
        [Option('v', "verbose", Default = false, HelpText = "Enable verbose logging.")]
        public bool Verbose { get; set; }

        [Option('n', "namespace", Default = "default", HelpText = "K8S namespace where configmap will be created")]
        public string Namespace { get; set; }

        [Option('m', "name", Required = true, HelpText = "Name of configmap")]
        public string Name { get; set; }

        [Option('k', "key", HelpText = "Key of feature flag")]
        public string Key { get; set; }

        [Option('f', "value", HelpText = "Value of feature flag")]
        public string Value { get; set; }

        [Option('d', "file", HelpText = "Json file of feature flag data")]
        public string JsonFile { get; set; }

        public static ProgramOptions Parse(string[] args)
        {
            ProgramOptions opts = null;
            Parser.Default.ParseArguments<ProgramOptions>(args)
                .WithParsed(parsedOpts => opts = parsedOpts);

            return opts;
        }
    }
}
