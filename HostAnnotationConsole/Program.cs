
using HostAnnotation.Common;
using HostAnnotation.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

internal class Program {

    private static async Task Main(string[] args) {

        if (args == null || args.Length < 1) {
            printUsage();
            return;
        }

        // Get and validate the action code.
        string? actionCode = args[0];
        if (string.IsNullOrEmpty(actionCode)) {
            printUsage();
            return;
        } else {
            actionCode = actionCode.Trim().ToLower();
        }

        // Print start timestamp
        var startedAt = DateTime.Now;
        Console.WriteLine($"Started on {startedAt:MM/dd/yy} at {startedAt:h:mmtt}");

        using IHost host = Host.CreateDefaultBuilder(args)
            .ConfigureServices((context, services) => {

                // Bind Database section to DatabaseOptions and register IOptions<DatabaseOptions>.
                services.Configure<DatabaseOptions>(context.Configuration.GetSection("Database"));

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

        // Uncomment when debugging the db connection string.
        //var config = host.Services.GetRequiredService<IConfiguration>();
        //Console.WriteLine($"Database connection string: '{config[Names.ConfigKey.DbConnectionString] ?? "<null>"}'");

        // Start the host to start hosted services.
        await host.StartAsync();

        // Run the synchronous work on the thread-pool to avoid blocking the caller thread.
        var sw = System.Diagnostics.Stopwatch.StartNew();

        switch (actionCode) {

            case Names.ConsoleActionCode.AnnotateHostGroup:

                int hostCount = await annotateHostGroup(args, host);

                Console.WriteLine($"Hosts processed: {hostCount}");

                break;

            default:
                Console.WriteLine($"Unknown action: {actionCode}");
                printUsage();
                break;
        }

        // Stop the stopwatch and write the elapsed time to stdout.
        sw.Stop();
        printElapsedTime(sw);

        await host.StopAsync();
    }

    // Call the AnnotationService.annotateHostGroup method.
    private static async Task<int> annotateHostGroup(string[] args_, IHost host_) {

        int hostCount = 0;

        // Parse action-specific arguments (excluding actionCode).
        var parseResult = parseAnnotateHostGroupArgs(args_.Skip(1).ToArray());
        if (!parseResult.success) {
            printUsage();
            await host_.StopAsync();
            return 0;
        }

        // Resolve the service
        using var scope = host_.Services.CreateScope();
        var annotationService = scope.ServiceProvider.GetRequiredService<IAnnotationService>();

        // Run the synchronous work on the thread-pool to avoid blocking the caller thread.
        await Task.Run(() => 
            hostCount = annotationService.annotateHostGroup(parseResult.groupId, parseResult.maxHosts, parseResult.unprocessed)
        );

        return hostCount;
    }


    // Parse parameters for annotateHostGroup from the command line arguments.
    private static (bool success, int groupId, int? maxHosts, bool unprocessed) parseAnnotateHostGroupArgs(string[] args) {

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

    private static void printElapsedTime(System.Diagnostics.Stopwatch sw_) {

        var endedAt = DateTime.Now;
        var elapsed = sw_.Elapsed;
        string elapsedText = "";

        if (elapsed.Days > 0) {
            elapsedText += elapsed.Days == 1 ? "1 day" : $"{elapsed.Days} days";
        }
        if (elapsed.Hours > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Hours == 1 ? "1 hour" : $"{elapsed.Hours} hours";
        }
        if (elapsed.Minutes > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Minutes == 1 ? "1 minute" : $"{elapsed.Minutes} minutes";
        }

        Console.WriteLine($"Ended on {endedAt:MM/dd/yy} at {endedAt:h:mmtt} (total running time: {elapsedText})");
    }

    private static void printUsage() {
        Console.WriteLine("Usage:");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=<id> [max_hosts=<n>] [--unprocessed]");
        Console.WriteLine();
        Console.WriteLine("Examples:");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=123");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group group_id=123 max_hosts=50 --unprocessed");
        Console.WriteLine("  HostAnnotationConsole annotate_host_group 123 50 --unprocessed   (positional supported)");
    }

    
}