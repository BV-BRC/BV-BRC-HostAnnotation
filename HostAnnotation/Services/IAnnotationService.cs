using System;
using System.Collections.Generic;
using HostAnnotation.Common;
using HostAnnotation.Models;

namespace HostAnnotation.Services {

    public interface IAnnotationService {

        // Annotate all hosts with this group ID. If "unprocessed" is true, only annotate hosts that 
        // have not yet been processed. If a non-null max hosts value is provided, only that many hosts will
        // be processed now. Otherwise, all valid hosts in the specified group (possibly only unprocessed)
        // will be annotated.
        int annotateHostGroup(int groupID_, int? maxHosts_, bool unprocessed_);

        AnnotatedHost? annotateHostText(string initialText_);

        AnnotatedHost? getAnnotatedHost(int hostID_);

        List<HostTaxonMatch>? getHostTaxaMatches(int hostID_);

        List<AnnotatedHost>? searchAnnotatedHosts(string searchText_);

    }
}
