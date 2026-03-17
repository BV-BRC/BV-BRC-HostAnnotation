
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Net;

using HostAnnotation.Common;
using HostAnnotation.Models;
using HostAnnotationWeb.Models;
using HostAnnotation.Services;
using HostAnnotation.Utilities;

using HostAnnotationWeb.Controllers.Parameters;

namespace HostAnnotationWeb.Controllers {

    [ApiController]
    [Authorize(Policy = Names.PolicyName.Curators)]
    public class AnnotationController : AuthenticatedController {

        private readonly ILogger<AnnotationController> _logger;

        private readonly IAnnotationService _annotationService;


        // C-tor
        public AnnotationController(ILogger<AnnotationController> logger_, IAnnotationService annotationService_) {
            _annotationService = annotationService_;
            _logger = logger_;
        }

        [HttpPost]
        [Route("annotateHostText")]
        public async Task<ApiResponse> AnnotateHostText([FromForm] AnnotationParams.AnnotateHostTextForm form) {

            var response = new ApiResponse();

            try {
                // Validate the user identity.
                if (_userIdentity == null || !_userIdentity.isValid) { throw new Exception("Invalid user identity"); }

                form.sanitize();

                string? hostText = form.hostText;

                if (Utils.isEmptyElseTrim(ref hostText)) { throw new Exception("Invalid host text (empty)"); }

                // Annotate the host text.
                AnnotatedHost? annotatedHost = _annotationService.annotateHostText(hostText!);

                response.data = annotatedHost;
                response.statusCode = HttpStatusCode.OK;
            }
            catch (Exception ex_) {
                response.message = ex_.Message;
                response.statusCode = HttpStatusCode.InternalServerError;
            }

            return response;
        }

        [HttpPost]
        [Route("getAnnotatedHost")]
        public async Task<ApiResponse> GetAnnotatedHost([FromForm] AnnotationParams.GetAnnotatedHostForm form) {

            var response = new ApiResponse();

            try {
                // Validate the user identity.
                if (_userIdentity == null || !_userIdentity.isValid) { throw new Exception("Invalid user identity"); }

                form.sanitize();

                int hostID = -1;
                string? strHostID = form.hostID;
                if (Utils.isEmptyElseTrim(ref strHostID) || !int.TryParse(strHostID, out hostID)) { throw new Exception("Invalid host ID"); }

                // Get the annotated host by ID.
                AnnotatedHost? annotatedHost = _annotationService.getAnnotatedHost(hostID);

                response.data = annotatedHost;
                response.statusCode = HttpStatusCode.OK;
            }
            catch (Exception ex_) {
                response.message = ex_.Message;
                response.statusCode = HttpStatusCode.InternalServerError;
            }

            return response;
        }

        [HttpPost]
        [Route("getHostTaxaMatches")]
        public async Task<ApiResponse> GetHostTaxaMatches([FromForm] AnnotationParams.GetHostTaxaMatchesForm form) {

            var response = new ApiResponse();

            try {
                // Validate the user identity.
                if (_userIdentity == null || !_userIdentity.isValid) { throw new Exception("Invalid user identity"); }

                form.sanitize();

                int hostID = -1;
                string? strHostID = form.hostID;
                if (string.IsNullOrEmpty(strHostID) || !int.TryParse(strHostID, out hostID)) { throw new Exception("Invalid host ID"); }

                List<HostTaxonMatch>? matches = _annotationService.getHostTaxaMatches(hostID);

                response.data = matches;
                response.statusCode = HttpStatusCode.OK;
            }
            catch (Exception ex_) {
                response.message = ex_.Message;
                response.statusCode = HttpStatusCode.InternalServerError;
            }

            return response;
        }


        [HttpPost]
        [Route("searchAnnotatedHosts")]
        public async Task<ApiResponse> SearchAnnotatedHosts([FromForm] AnnotationParams.SearchAnnotatedHostsForm form) {

            var response = new ApiResponse();

            try {
                // Validate the user identity.
                if (_userIdentity == null || !_userIdentity.isValid) { throw new Exception("Invalid user identity"); }

                // Sanitize the form parameters.
                form.sanitize();

                string? searchText = form.searchText;
                if (Utils.isEmptyElseTrim(ref searchText) || searchText!.Length < 3) { throw new Exception("Please search using at least 3 characters"); }

                // Search annotated hosts
                List<AnnotatedHost>? results = _annotationService.searchAnnotatedHosts(searchText);

                response.data = results;
                response.statusCode = HttpStatusCode.OK;
            }
            catch (Exception ex_) {
                response.message = ex_.Message;
                response.statusCode = HttpStatusCode.InternalServerError;
            }

            return response;
        }

    }
}
