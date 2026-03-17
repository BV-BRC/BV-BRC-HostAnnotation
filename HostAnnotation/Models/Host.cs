using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using HostAnnotation.Utilities;

namespace HostAnnotation.Models {

    public class Host : UsefulObject {

        [Useful("filtered_text", false)]
        public string? filteredText { get; set; }

        [Useful("id", true)]
        public int id { get; set; }

        [Useful("text", true)]
        public string? text { get; set; }





    }
}
