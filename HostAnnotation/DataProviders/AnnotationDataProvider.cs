
using HostAnnotation.Common;
using HostAnnotation.Models;
using HostAnnotation.Utilities;
using Newtonsoft.Json.Linq;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using static HostAnnotation.Common.Names;
using static HostAnnotation.Common.Terms;
using static System.Net.Mime.MediaTypeNames;

namespace HostAnnotation.DataProviders {

    public class AnnotationDataProvider : DataProvider {


        // C-tor
        public AnnotationDataProvider(string dbConnectionString_) : base(dbConnectionString_) { }


        public void createAnnotatedHost(int hostID_, double? scoreThreshold_ = null) {

            if (scoreThreshold_ == null) { scoreThreshold_ = Constants.DEFAULT_ANNOTATION_SCORE_THRESHOLD; }

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@annotatedHostID", SqlDbType.Int, hostID_),
                Utils.createSqlParam("@scoreThreshold", SqlDbType.Float, scoreThreshold_)
            };

            DbQueryManager.runStoredProcedure(_dbConnectionString, "dbo.createAnnotatedHost", parameters);
        }

        // Create host name/taxon name matches for a host's tokens.
        public void createHostnameTaxonMatches(int hostID_) {

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@hostID", SqlDbType.Int, hostID_)
            };

            DbQueryManager.runStoredProcedure(_dbConnectionString, "dbo.createHostnameTaxonMatches", parameters);
        }

        public void createHostTokenAnnotations(int? algorithmID_, int hostID_) {

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@algorithmID", SqlDbType.Int, algorithmID_),
                Utils.createSqlParam("@hostID", SqlDbType.Int, hostID_)
            };

            DbQueryManager.runStoredProcedure(_dbConnectionString, "dbo.createHostTokenAnnotations_SingleRun", parameters);
        }


        public bool createHostTokenVariations(string baseToken_, Terms.host_token_type baseType_, int hostID_, bool isOneOfMany_) {

            int isOneOfMany = isOneOfMany_ ? 1 : 0;

            // Create text variations on the base token.
            var variations = new HostTokenVariations(baseToken_);

            // Add the variations as SQL parameters.
            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@addSToEnd", SqlDbType.NVarChar, variations.addSToEnd),
                Utils.createSqlParam("@appendSpDot", SqlDbType.NVarChar, variations.appendSpDot),
                Utils.createSqlParam("@baseToken", SqlDbType.NVarChar, variations.baseToken),
                Utils.createSqlParam("@baseType", SqlDbType.NVarChar, Enum.GetName(baseType_)),
                Utils.createSqlParam("@hostID", SqlDbType.Int, hostID_),
                Utils.createSqlParam("@isOneOfMany", SqlDbType.Bit, isOneOfMany),
                Utils.createSqlParam("@minusOneWordLeft", SqlDbType.NVarChar, variations.minusOneWordLeft),
                Utils.createSqlParam("@minusOneWordRight", SqlDbType.NVarChar, variations.minusOneWordRight),
                Utils.createSqlParam("@minusTwoWordsLeft", SqlDbType.NVarChar, variations.minusTwoWordsLeft),
                Utils.createSqlParam("@minusTwoWordsRight", SqlDbType.NVarChar, variations.minusTwoWordsRight),
                Utils.createSqlParam("@minusThreeWordsLeft", SqlDbType.NVarChar, variations.minusThreeWordsLeft),
                Utils.createSqlParam("@minusThreeWordsRight", SqlDbType.NVarChar, variations.minusThreeWordsRight),
                Utils.createSqlParam("@prependCommon", SqlDbType.NVarChar, variations.prependCommon),
                Utils.createSqlParam("@removeCommonAppendSpDot", SqlDbType.NVarChar, variations.removeCommonAppendSpDot),
                Utils.createSqlParam("@removeCommonFromStart", SqlDbType.NVarChar, variations.removeCommonFromStart),
                Utils.createSqlParam("@removeSAppendSpDot", SqlDbType.NVarChar, variations.removeSAppendSpDot),
                Utils.createSqlParam("@removeSFromEnd", SqlDbType.NVarChar, variations.removeSFromEnd),
                Utils.createSqlParam("@removeSpDotFromEnd", SqlDbType.NVarChar, variations.removeSpDotFromEnd)
            };

            DbQueryManager.runStoredProcedure(_dbConnectionString, "dbo.createHostTokenVariations", parameters);

            return true;
        }


        /*
        // Populate the hosts filtered_text using its text value.
        public void filterHostTextByGroup(int groupID_) {

            var sql = @$"UPDATE hosts SET filtered_text =
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        REPLACE(
                                            REPLACE(
                                                REPLACE(
                                                    REPLACE(
                                                        REPLACE(
                                                            REPLACE(
                                                                REPLACE(lower(text), '''', '')
                                                            , '  ', ' ')
                                                        , '_', ' ')
                                                    , '""', '')
                                                , '`', '')
                                            , '!', '')
                                        , '.', '')
                                    , '?', '')
                                , '(', ',')
                            , ')', ',')
                        , ':', ',')
                    , ';', ',')
                , '-', ' ')

            where group_id = {groupID_} ";

            DbQueryManager.update(_dbConnectionString, sql);
        } */


        // Update a host after it has been processed.
        public void updateHostStatus(string? filteredText_, int hostID_, bool isValid_, string? messages_ = null) {

            // If the host is invalid, the filtered text might be empty, but if it's valid, the filtered text shouldn't be empty.
            if (isValid_ && string.IsNullOrEmpty(filteredText_)) { throw SmartException.create("Invalid filtered text"); }

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@filteredText", SqlDbType.NVarChar, filteredText_),
                Utils.createSqlParam("@messages", SqlDbType.NVarChar, messages_)
            };

            var sql = new StringBuilder();
            sql.AppendLine("UPDATE hosts SET ");
            sql.AppendLine("filtered_text = @filteredText, ");
            sql.AppendLine("is_processed = 1, ");
            sql.AppendLine($"is_valid = {(isValid_ ? 1 : 0)}, ");
            sql.AppendLine("messages = @messages, ");
            sql.AppendLine("processed_on = SYSDATETIMEOFFSET() ");
            sql.AppendLine($"WHERE id = {hostID_} ");

            DbQueryManager.update(_dbConnectionString, sql.ToString(), parameters);
        }

        public AnnotatedHost? getAnnotatedHost(int hostID_) {

            AnnotatedHost? annotatedHost = null;

            var sql = new StringBuilder();
            sql.AppendLine("SELECT TOP 1 ");
            sql.AppendLine(AnnotatedHost.generatePartialQuery());
            sql.AppendLine($"WHERE [host_id] = {hostID_} ");

            UsefulObject.get<AnnotatedHost>(_dbConnectionString, sql.ToString(), ref annotatedHost);

            return annotatedHost;
        }

        public List<HostQuery>? getHostsByGroup(int groupID_, int? maxHosts_) {

            List<HostQuery>? hosts = null;

            var limitText = maxHosts_ == null 
                ? "" 
                : $"TOP {maxHosts_.Value}";

            var sql = new StringBuilder();
            sql.AppendLine($"SELECT {limitText}");
            sql.AppendLine("   id, ");
            sql.AppendLine("   filtered_text, ");
            sql.AppendLine("   text ");
            sql.AppendLine("FROM hosts ");
            sql.AppendLine($"WHERE group_id = {groupID_} ");
            sql.AppendLine("AND is_processed = 0 ");
            sql.AppendLine("AND (is_valid IS NULL OR is_valid = 0) ");
            sql.AppendLine("ORDER BY text ");

            UsefulObject.get<HostQuery>(_dbConnectionString, sql.ToString(), ref hosts);

            return hosts;
        }

        public List<HostTaxonMatch>? getHostTaxaMatches(int hostID_) {

            List<HostTaxonMatch>? matches = null;

            var sql = new StringBuilder();
            sql.AppendLine("SELECT ");
            sql.AppendLine(HostTaxonMatch.generatePartialQuery());
            sql.AppendLine($"WHERE hhtm.[host_id] = {hostID_} ");

            UsefulObject.get<HostTaxonMatch>(_dbConnectionString, sql.ToString(), ref matches);
            return matches;
        }


        // Is there already a host with this filtered text? If not, create the host. Either way, return the host ID.
        // TODO: include the concept of "linked host ID".
        public int lookupHostID(string? filteredText_, string? initialText_, ref bool isNew_) {

            if (Utils.isEmptyElseTrim(ref filteredText_)) { throw SmartException.create("Invalid filtered text"); }
            if (Utils.isEmptyElseTrim(ref initialText_)) { throw SmartException.create("Invalid initial text"); }

            // Add the initial host text and filtered text as SQL parameters.
            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@filteredText", SqlDbType.NVarChar, filteredText_),
                Utils.createSqlParam("@text", SqlDbType.NVarChar, initialText_)
            };

            var sql = new StringBuilder();
            sql.AppendLine("DECLARE @isNew AS BIT = 1 ");
            sql.AppendLine("DECLARE @hostID AS INT = (");
            sql.AppendLine("    SELECT TOP 1 id ");
            sql.AppendLine("    FROM hosts ");
            sql.AppendLine($"   WHERE filtered_text = @filteredText ");
            sql.AppendLine(") ");

            // Create the host if it doesn't already exist.
            sql.AppendLine("IF @hostID IS NULL ");
            sql.AppendLine("BEGIN ");
            sql.AppendLine("	INSERT INTO hosts (");
            sql.AppendLine("        filtered_text, ");
            sql.AppendLine("		is_processed, ");
            sql.AppendLine("		text ");
            sql.AppendLine("	) VALUES (");
            sql.AppendLine("		@filteredText, ");
            sql.AppendLine("		0, ");
            sql.AppendLine("		@text ");
            sql.AppendLine("	) ");

            sql.AppendLine("	SET @hostID = (SELECT SCOPE_IDENTITY() AS [SCOPE_IDENTITY]) ");
            sql.AppendLine("END ");
            sql.AppendLine("ELSE SET @isNew = 0 ");

            // Return the host ID and "is new".
            sql.AppendLine("SELECT @hostID AS id, @isNew AS is_new ");

            DbRow? row = DbRow.selectOne(_dbConnectionString, sql.ToString(), parameters);
            if (row == null) { throw SmartException.create("An error occurred retrieving host data"); }

            int? hostID = row.get<int>("id");
            if (hostID == null) { throw SmartException.create("Unable to retrieve a host ID"); }

            isNew_ = row.get<bool>("is_new");

            return hostID.Value;
        }


        public List<AnnotatedHost>? searchAnnotatedHosts(string? searchText_) {

            if (Utils.isEmptyElseTrim(ref searchText_) || searchText_!.Length < 3) { throw SmartException.create("Please enter valid search text with at least 3 characters"); }

            List<AnnotatedHost>? annotatedHosts = null;

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@searchText", SqlDbType.NVarChar, searchText_)
            };

            var sql = new StringBuilder();
            sql.AppendLine("SELECT ");
            sql.AppendLine(AnnotatedHost.generatePartialQuery());
            sql.AppendLine("WHERE host_text LIKE '%'+@searchText+'%' ");
            sql.AppendLine("ORDER BY host_text ");

            UsefulObject.get<AnnotatedHost>(_dbConnectionString, parameters, sql.ToString(), ref annotatedHosts);

            return annotatedHosts;
        }

        /*
        // Update the host's "is valid" and (optional) "messages" attributes.
        public void updateIsValid(int hostID_, bool isValid_, string? messages_ = null) {

            var parameters = new List<SqlParameter>() {
                Utils.createSqlParam("@messages", SqlDbType.NVarChar, messages_)
            };

            var value = isValid_ ? 1 : 0;

            DbQueryManager.update(_dbConnectionString, $"UPDATE hosts SET is_valid = {value}, messages = @messages WHERE id = {hostID_} ", parameters);
        }*/


        
    }
}
