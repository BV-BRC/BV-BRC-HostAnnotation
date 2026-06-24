
using HostAnnotation.Common;
using HostAnnotation.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Runtime.InteropServices;

internal class Program {

    private static async Task Main(string[] args) {

        using IHost host = Host.CreateDefaultBuilder(args)
            .ConfigureLogging(logging => {
                logging.ClearProviders();
                logging.AddSimpleConsole(options =>
                {
                    options.SingleLine = true;
                    options.TimestampFormat = "[yyyy-MM-dd HH:mm:ss] ";
                    options.IncludeScopes = false;
                });
                logging.AddDebug();
                logging.SetMinimumLevel(LogLevel.Information);
            })
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

        // Get a logger from DI
        var logger = host.Services.GetRequiredService<ILogger<Program>>();

        // Validate the args
        if (args == null || args.Length < 1) {
            LogBasicUsage(logger);
            return;
        }

        // Get and validate the action code.
        string? actionCode = args[0];
        if (string.IsNullOrEmpty(actionCode)) {
            logger.LogError("Invalid action code");
            LogBasicUsage(logger);
            return;
        } else {
            actionCode = actionCode.Trim().ToLower();
        }

        // Log a start message
        logger.LogInformation("Started HostAnnotationConsole with action code '{ActionCode}'", actionCode);
        
        // Start the host to start hosted services.
        await host.StartAsync();

        // Run the synchronous work on the thread-pool to avoid blocking the caller thread.
        var sw = System.Diagnostics.Stopwatch.StartNew();

        try {
            switch (actionCode) {

                case Names.ConsoleActionCode.AnnotateHostGroup:
                    int hostCount = await AnnotateHostGroup(args, host);
                    break;

                default:
                    logger.LogWarning("Unknown action code supplied: {ActionCode}", actionCode);
                    LogBasicUsage(logger);
                    break;
            }
        }
        catch (Exception ex) {
            logger.LogError(ex, "Unhandled exception during execution");
        }

        // Stop the stopwatch and write the elapsed time to stdout.
        sw.Stop();
        LogElapsedTime(logger, sw);

        await host.StopAsync();
    }

    // Call the AnnotationService.annotateHostGroup method.
    private static async Task<int> AnnotateHostGroup(string[] args_, IHost host_) {

        int hostCount = 0;

        // Resolve the service and logger.
        using var scope = host_.Services.CreateScope();
        var annotationService = scope.ServiceProvider.GetRequiredService<IAnnotationService>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

        // Parse action-specific arguments (excluding actionCode).
        var parseResult = ParseAnnotateHostGroupArgs(args_.Skip(1).ToArray());
        if (!parseResult.success) {
            logger.LogError("Usage:");
            logger.LogError("  HostAnnotationConsole annotate_host_group group_id=<id> [max_hosts=<n>]");
            logger.LogError("");
            logger.LogError("Examples:");
            logger.LogError("  HostAnnotationConsole annotate_host_group group_id=123");
            logger.LogError("  HostAnnotationConsole annotate_host_group group_id=123 max_hosts=50");
            logger.LogError("  HostAnnotationConsole annotate_host_group 123 50");

            // Stop the host and exit.
            await host_.StopAsync();
            return 0;
        }

        // Log the request
        logger.LogInformation("Running annotateHostGroup for group {GroupId}, maxHosts={MaxHosts}",
            parseResult.groupId, parseResult.maxHosts?.ToString() ?? "null");

        // Run the synchronous work on the thread-pool to avoid blocking the caller thread.
        await Task.Run(() => 
            hostCount = annotationService.annotateHostGroup(parseResult.groupId, parseResult.maxHosts)
        );

        logger.LogInformation("annotateHostGroup finished and processed {HostCount} hosts", hostCount);

        return hostCount;
    }

    private static void LogBasicUsage(ILogger<Program> logger_) {
        logger_.LogError("Usage:");
        logger_.LogError("\tHostAnnotationConsole <action code> <action-specific parameters>");
    }

    private static void LogElapsedTime(ILogger<Program> logger_, System.Diagnostics.Stopwatch sw_) {

        var endedAt = DateTime.Now;
        var elapsed = sw_.Elapsed;
        string elapsedText = "";

        if (elapsed.Days > 0) {
            elapsedText += elapsed.Days == 1
                ? "1 day"
                : $"{elapsed.Days} days";
        }
        if (elapsed.Hours > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Hours == 1
                ? "1 hour"
                : $"{elapsed.Hours} hours";
        }
        if (elapsed.Minutes > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Minutes == 1
                ? "1 minute"
                : $"{elapsed.Minutes} minutes";
        }
        if (elapsed.Seconds > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Seconds == 1
                ? "1 second"
                : $"{elapsed.Seconds} seconds";
        }
        if (elapsed.Milliseconds > 0) {
            if (elapsedText.Length > 0) { elapsedText += ", "; }
            elapsedText += elapsed.Milliseconds == 1
                ? "1 millisecond"
                : $"{elapsed.Milliseconds} milliseconds";
        }

        logger_.LogInformation("Ended on {EndDate} at {EndTime}", endedAt.ToString("MM/dd/yy"), endedAt.ToString("h:mmtt"));
        logger_.LogInformation("Total running time: {ElapsedTime}", elapsedText);
    }

    // Parse parameters for annotateHostGroup from the command line arguments.
    private static (bool success, int groupId, int? maxHosts) ParseAnnotateHostGroupArgs(string[] args) {

        int? groupId = null;
        int? maxHosts = null;

        foreach (var raw in args) {
            if (string.IsNullOrWhiteSpace(raw)) { continue; }

            var arg = raw.Trim();

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

            // Unknown token - ignore but indicate failure
            return (false, 0, null);
        }

        if (!groupId.HasValue) {
            return (false, 0, null);
        }

        return (true, groupId.Value, maxHosts);
    } 
}