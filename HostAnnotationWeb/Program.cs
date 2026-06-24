

using HostAnnotation.Common;
using HostAnnotation.Services;
using HostAnnotationWeb.Auth;
using System.Runtime.InteropServices;
using System.Security.Claims;
using System.Text.Json.Serialization;


// Create a web application builder.
var builder = WebApplication.CreateBuilder(args);


// Add logging to the application
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// TODO: what's the best way to use logging on all platforms?
if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
    builder.Logging.AddEventLog(eventLogSettings => {
        eventLogSettings.SourceName = "BV-BRC";
    });
}

//----------------------------------------------------------------------------------------------
// Get configuration data used by services
//----------------------------------------------------------------------------------------------

// Get the secret key
string? secretKey = builder.Configuration.GetValue<string>(Names.ConfigKey.AuthSecret);


//----------------------------------------------------------------------------------------------
// Add services to the container.
//----------------------------------------------------------------------------------------------

// Add the CORS policy
builder.Services.AddCors(options => {
    options.AddPolicy(name: Names.PolicyName.CORS, policy => {
        // TODO: are we sure we should allow ANY method? Can we restrict this to GET, OPTIONS, and POST?
        policy.AllowAnyMethod();
        policy.AllowAnyOrigin();
        //policy.WithOrigins(new[] { "http://localhost" }); // dmd testing 111123
        policy.WithExposedHeaders(Names.Header.Authorization, Names.Header.ContentType, "Access-Control-Allow-Origin");
        policy.WithHeaders(Names.Header.Authorization, Names.Header.ContentType, "Access-Control-Allow-Origin");
    });
});

// Add JSON serializer options.
builder.Services.AddControllers()
    .AddJsonOptions(options => {
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;
        options.JsonSerializerOptions.PropertyNamingPolicy = null;
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// Include BV-BRC-specific environment variables.
builder.Configuration.AddEnvironmentVariables("BVBRC_");

builder.Services.AddSingleton(builder.Configuration);

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add the authentication scheme
builder.Services
    .AddAuthentication("Basic")
    .AddScheme<AuthOptions, AuthHandler>("Basic", options_ => {
        options_.SecretKey = secretKey;
    });

// Add the account service.
builder.Services.AddSingleton<IAccountService, AccountService>();

// Add the annotation service.
builder.Services.AddSingleton<IAnnotationService, AnnotationService>();

// Add the curated word service.
builder.Services.AddSingleton<ICuratedWordService, CuratedWordService>();

// Add the Person service.
builder.Services.AddSingleton<IPersonService, PersonService>();

// Add the Taxonomy service.
builder.Services.AddSingleton<ITaxonomyService, TaxonomyService>();

// Add the token service.
builder.Services.AddSingleton<ITokenService, TokenService>();


// Configure authorization policies
builder.Services.AddAuthorization(options => {

    // Only authorize users with the administrator role.
    options.AddPolicy(Names.PolicyName.Administrators, policy => {
        policy.RequireClaim(ClaimTypes.Role, Names.ApiRole.administrator);
    });

    // Only authorize users with the curator or administrator roles.
    options.AddPolicy(Names.PolicyName.Curators, policy => {
        policy.RequireClaim(ClaimTypes.Role, Names.ApiRole.curator, Names.ApiRole.administrator);
    });

    // Only authorize users with the API user, curator, or administrator roles.
    options.AddPolicy(Names.PolicyName.ApiUsers, policy => {
        policy.RequireClaim(ClaimTypes.Role, Names.ApiRole.api_user, Names.ApiRole.curator, Names.ApiRole.administrator);
    });
});


//----------------------------------------------------------------------------------------------
// Configure the Application
//----------------------------------------------------------------------------------------------
var app = builder.Build();

if (app.Environment.IsDevelopment()) {
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors(Names.PolicyName.CORS);
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
