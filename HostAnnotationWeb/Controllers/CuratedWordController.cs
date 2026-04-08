
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Net;

using HostAnnotation.Common;
using HostAnnotationWeb.Controllers.Parameters;
using HostAnnotation.Models;
using HostAnnotationWeb.Models;
using HostAnnotation.Services;
using HostAnnotation.Utilities;


namespace HostAnnotationWeb.Controllers {

    [ApiController]
    [Authorize(Policy = Names.PolicyName.Curators)]
    public class CuratedWordController : AuthenticatedController {

        private readonly ILogger<CuratedWordController> _logger;

        private readonly ICuratedWordService _curatedWordService;


        // C-tor
        public CuratedWordController(ICuratedWordService curatedWordService_, ILogger<CuratedWordController> logger_) {
            _curatedWordService = curatedWordService_;
            _logger = logger_;
        }


        [HttpPost]
        [Route("searchCuratedWords")]
        public async Task<ApiResponse> SearchCuratedWords([FromForm] CuratedWordParams.SearchCuratedWordsForm form) {

            var response = new ApiResponse();

            try {
                // Validate the user identity.
                if (_userIdentity == null || !_userIdentity.isValid) { throw new Exception("Invalid user identity"); }

                // Sanitize the form parameters.
                form.sanitize();

                string? searchText = form.searchText;
                Utils.isEmptyElseTrim(ref searchText);

                string? strType = form.type;
                Terms.curation_type? curationType = null;
                if (!Utils.isEmptyElseTrim(ref strType) && Enum.TryParse<Terms.curation_type>(strType, out Terms.curation_type testType)) { curationType = testType; }

                List<CuratedWord>? words = _curatedWordService.searchCuratedWords(searchText, curationType);

                response.data = words;
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
