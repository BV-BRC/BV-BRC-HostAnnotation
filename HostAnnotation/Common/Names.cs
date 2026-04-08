using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HostAnnotation.Common {

    public class Names {

        // Constant strings for the api_role enums/terms.
        public static class ApiRole {
            public const string administrator = "administrator";
            public const string api_user = "api_user";
            public const string curator = "curator";
        }

        // Keys found in the Configuration / appsettings.json.
        public static class ConfigKey {
            public const string AuthSecret = "SecretSettings:Secret";
            public const string DbConnectionString = "Database:ConnectionString";
            public const string Environment = "Settings:Environment";
            public const string TokenExpirationInSeconds = "Token:ExpirationInSeconds";
        }

        // Action codes used in the console application.
        public static class ConsoleActionCode {
            public const string AnnotateHostGroup = "annotate_host_group";
        }

        // (Custom) User identity claim types.
        public static class IdentityClaimType {
            public const string OrgID = "OrgID";
            public const string OrgUID = "OrgUID";
            public const string PersonID = "PersonID";
            public const string PersonUID = "PersonUID";
        }


        // Header names used by HTTP Requests and Responses.
        public static class Header {
            public static string Authorization = "Authorization";
            public static string ContentType = "content-type";
        }


        public static class Parameters {
            public static string email = "email";
            public static string password = "password";
        }

        public static class PolicyName {
            public const string Administrators = "Administrators";
            public const string ApiUsers = "ApiUsers";
            public const string CORS = "CORS";
            public const string Curators = "Curators";
            public const string JwtAuth = "JwtAuth";
        }


        public static class SQL {
            public const string errorCode = "50000";
        }

        // The JWT auth token's issuer.
        public static string TOKEN_ISSUER = "BV_BRC";


    }
}
