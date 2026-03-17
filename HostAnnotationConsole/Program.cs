
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using HostAnnotation.Common;
using HostAnnotation.Services;

internal class Program {

    private static async Task Main(string[] args) {

        if (args == null || args.Length < 1) {
            PrintUsage();
            return;
        }

        // Get and validate the action code.
        string? actionCode = args[0];
        if (string.IsNullOrEmpty(actionCode)) {
            PrintUsage();
            return;
        }

        using IHost host = Host.CreateDefaultBuilder(args)
            .ConfigureServices((context, services) => {

                // Add the account service.
                services.AddSingleton<IAccountService, AccountService>();

                // Add the account service.
                services.AddSingleton<IAccountService, AccountService>();

                // Add the annotation service.
                services.AddSingleton<IAnnotationService, AnnotationService>();

                // Add the curated word service.
                services.AddSingleton<ICuratedWordService, CuratedWordService>();

                // Add the Person service.
                services.AddSingleton<IPersonService, PersonService>();

                // Add the Taxonomy service.
                services.AddSingleton<ITaxonomyService, TaxonomyService>();

                // Add the token service.
                services.AddSingleton<ITokenService, TokenService>();
            })
            .Build();

        var config = host.Services.GetRequiredService<IConfiguration>();
        Console.WriteLine($"Database connection string: '{config[HostAnnotation.Common.Names.ConfigKey.DbConnectionString] ?? "<null>"}'");

        // Start the host so hosted services (if any) are started.
        await host.StartAsync();

        
        
        if (string.Equals(actionCode, "annotate_host_group", StringComparison.OrdinalIgnoreCase)) {
            // Parse action-specific arguments (exclude actionCode itself)
            var parseResult = ParseAnnotateHostGroupArgs(args.Skip(1).ToArray());
            if (!parseResult.success) {
                PrintUsage();
                await host.StopAsync();
                return;
            }

            // Print start timestamp
            var startedAt = DateTime.Now;
            Console.WriteLine($"Started on {startedAt:MM/dd/yy} at {startedAt:h:mmtt}".ToLower());

            // Resolve the service and run the work
            using var scope = host.Services.CreateScope();
            var annotationService = scope.ServiceProvider.GetRequiredService<IAnnotationService>();

            // Run the synchronous work on the thread-pool to avoid blocking the caller thread.
            var sw = System.Diagnostics.Stopwatch.StartNew();
            await Task.Run(() => annotationService.annotateHostGroup(parseResult.groupId, parseResult.maxHosts, parseResult.unprocessed));
            sw.Stop();

            var endedAt = DateTime.Now;
            var elapsed = sw.Elapsed;
            string elapsedText;
            if (elapsed.TotalHours >= 1.0) {
                elapsedText = $"{elapsed.TotalHours:F1} hours";
            } else {
                elapsedText = $"{elapsed.TotalMinutes:F0} minutes";
            }

            Console.WriteLine($"Ended on {endedAt:MM/dd/yy} at {endedAt:h:mmtt}".ToLower() + $" (total running time: {elapsedText})");
        } else {
            Console.WriteLine($"Unknown action: {actionCode}");
            PrintUsage();
        }

        await host.StopAsync();
    }

    private static void PrintUsage() {
        Console.WriteLine("Usage:");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=<id> [max_hosts=<n>] [--unprocessed]");
        Console.WriteLine();
        Console.WriteLine("Examples:");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=123");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=123 max_hosts=50 --unprocessed");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group 123 50 --unprocessed   (positional supported)");
    }

    private static (bool success, int groupId, int? maxHosts, bool unprocessed) ParseAnnotateHostGroupArgs(string[] args) {
        int? groupId = null;
        int? maxHosts = null;
        bool unprocessed = false;

        foreach (var raw in args) {
            if (string.IsNullOrWhiteSpace(raw)) { continue; }

            var arg = raw.Trim();

            // Flags
            if (arg.Equals("--unprocessed", StringComparison.OrdinalIgnoreCase)) {
                unprocessed = true;
                continue;
            }

            // key=value style
            if (arg.Contains('=')) {
                var parts = arg.Split('=', 2);
                var key = parts[0].Trim().ToLowerInvariant();
                var val = parts[1].Trim();

                if (key == "group_id" || key == "groupid" || key == "group") {
                    if (int.TryParse(val, out var gid)) { groupId = gid; }
                } else if (key == "max_hosts" || key == "maxhosts" || key == "max") {
                    if (int.TryParse(val, out var mh)) { maxHosts = mh; }
                }
                continue;
            }

            // positional numeric values: first numeric -> groupId, second -> maxHosts
            if (int.TryParse(arg, out var numeric)) {
                if (!groupId.HasValue) { groupId = numeric; } else if (!maxHosts.HasValue) { maxHosts = numeric; }
                continue;
            }

            // unknown token - ignore but indicate failure
            return (false, 0, null, false);
        }

        if (!groupId.HasValue) {
            return (false, 0, null, false);
        }

        return (true, groupId.Value, maxHosts, unprocessed);
    }
}