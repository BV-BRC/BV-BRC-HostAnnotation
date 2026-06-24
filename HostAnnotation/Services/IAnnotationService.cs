using System;
using System.Collections.Generic;
using HostAnnotation.Common;
using HostAnnotation.Models;

namespace HostAnnotation.Services {

    public interface IAnnotationService {

        // Annotate all hosts with this group ID. If a non-null max hosts value is provided, that will be the maximum number of
        // hosts that will be annotated. If null, there is no maximum and all hosts in the group will be annotated. The return
        // value is the number of hosts that were annotated.
        int annotateHostGroup(int groupID_, int? maxHosts_);

        AnnotatedHost? annotateHostText(string initialText_);

        AnnotatedHost? getAnnotatedHost(int hostID_);

        List<HostTaxonMatch>? getHostTaxaMatches(int hostID_);

        List<AnnotatedHost>? searchAnnotatedHosts(string searchText_);

    }
}
