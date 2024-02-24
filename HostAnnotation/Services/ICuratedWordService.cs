﻿using System;
using System.Collections.Generic;
using HostAnnotation.Common;
using HostAnnotation.Models;


namespace HostAnnotation.Services {

    public interface ICuratedWordService {

        // Get a specific curated word.
        CuratedWord? getCuratedWord(Guid uid_);

        // Get all valid curated words.
        CuratedWords? getCuratedWords();

        // Search all curated words.
        List<CuratedWord>? searchCuratedWords(string? searchText_, Terms.curation_type? type_);

    }
}
