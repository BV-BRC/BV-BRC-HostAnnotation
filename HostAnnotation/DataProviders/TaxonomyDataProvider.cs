
using System.Data;
using System.Data.SqlClient;
using System.Text;

using HostAnnotation.Common;
using HostAnnotation.Models;
using HostAnnotation.Utilities;

namespace HostAnnotation.DataProviders {

    public class TaxonomyDataProvider : DataProvider {

        // C-tor
        public TaxonomyDataProvider(string dbConnectionString) : base(dbConnectionString) { }


        // Get a specific taxon name.
        public TaxonName? getTaxonName(int id_) {

            TaxonName? taxonName = null;

            var sql = new StringBuilder();
            sql.AppendLine("SELECT TOP 1 ");
            sql.AppendLine(TaxonName.generatePartialQuery());
            sql.AppendLine($"WHERE id = {id_} ");

            UsefulObject.get<TaxonName>(_dbConnectionString, sql.ToString(), ref taxonName);

            return taxonName;
        }


        public List<TaxonName>? search(string? searchText_, Terms.taxonomy_db? taxonomyDB_ = null) {

            List<TaxonName>? taxonNames = null;

            if (Utils.isEmptyElseTrim(ref searchText_) || searchText_!.Length < 3) { throw SmartException.create("Please enter at least 3 characters"); }
            
            var parameters = new List<SqlParameter>() { 
                Utils.createSqlParam("@searchText", SqlDbType.NVarChar, searchText_) 
            };

            string taxonomyDB = taxonomyDB_ == null ? "NULL" : $"'{Terms.enumString(taxonomyDB_.Value)}'";

            var sql = new StringBuilder();

            // If a taxonomy DB constraint was provided, lookup its term ID.
            sql.AppendLine($"DECLARE @taxDB AS VARCHAR(60) = {taxonomyDB} ");
            sql.AppendLine("DECLARE @taxDbTID AS INT = CASE ");
            sql.AppendLine("	WHEN @taxDB IS NULL OR LEN(@taxDB) < 1 THEN NULL ");
            sql.AppendLine("	ELSE (");
            sql.AppendLine("		SELECT TOP 1 term_id ");
            sql.AppendLine("		FROM term ");
            sql.AppendLine("		WHERE term_full_key = 'taxonomy_db.'+@taxDB ");
            sql.AppendLine("	) ");
            sql.AppendLine("END ");

            // Search the taxon names.
            sql.AppendLine("SELECT ");
            sql.AppendLine(TaxonName.generatePartialQuery());
            sql.AppendLine("WHERE [name] LIKE '%'+@searchText+'%' ");
            sql.AppendLine("AND (@taxDbTID IS NULL OR (@taxDbTID IS NOT NULL AND taxonomy_db_tid = @taxDbTID)) ");
            sql.AppendLine("ORDER BY [name], rank_name ");

            UsefulObject.get<TaxonName>(_dbConnectionString, parameters, sql.ToString(), ref taxonNames);

            return taxonNames;
        }

    }
}
