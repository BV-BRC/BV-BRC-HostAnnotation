
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ==========================================================================================================
-- Author: don dempsey
-- Created on: 02/22/24
-- Description: Create host name/taxon name matches for a host's tokens.
-- Updated: 03/17/26 dmd: Renamed from "searchTaxonName".
-- ==========================================================================================================

-- Delete any existing versions.
IF OBJECT_ID('dbo.createHostnameTaxonMatches') IS NOT NULL
	DROP PROCEDURE dbo.createHostnameTaxonMatches
GO

CREATE PROCEDURE dbo.createHostnameTaxonMatches
	@hostID AS INT
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	BEGIN TRY

		--==========================================================================================================
		-- Lookup term IDs
		--==========================================================================================================

		-- NCBI name classes
		DECLARE @commonNameClassTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'ncbi_name_class.common_name')
		DECLARE @scientificNameClassTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'ncbi_name_class.scientific_name')

		-- Taxonomy databases
		DECLARE @itisDbTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.itis')

		-- Taxon match types
		DECLARE @customTextMatchTypeTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxon_match_type.custom_text')
		DECLARE @directMatchTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxon_match_type.direct_match')
		DECLARE @directMatchXRefTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxon_match_type.direct_match_cross_reference')
		DECLARE @indirectMatchTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxon_match_type.indirect_match')
		DECLARE @indirectMatchXRefTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxon_match_type.indirect_match_cross_reference')
		


		--==========================================================================================================
		-- Store all mapped host tokens in a table variable.
		--==========================================================================================================
		DECLARE @hostTokens AS dbo.HostTokenTableType 
		INSERT INTO @hostTokens (
			id,
			filtered_text
		)
		SELECT 
			t.id, 
			t.filtered_text

		FROM hosts_host_token_map m
		JOIN host_token t ON t.id = m.host_token_id
		WHERE m.host_id = @hostID


		--==========================================================================================================
		-- Direct matches
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			host_token_id,
			is_active,
			match_type_tid,
			taxon_name_id
		)
		SELECT 
			ht.id,
			tn.is_valid,
			@directMatchTID,
			tn.id

		FROM @hostTokens ht
		JOIN taxon_name tn ON tn.filtered_name = ht.filtered_text
		
		-- Existing taxon name direct matches on the host token.
		LEFT JOIN host_token_taxon_name_match existing_match ON (
			existing_match.host_token_id = ht.id
			AND existing_match.taxon_name_id = tn.id
			AND existing_match.match_type_tid = @directMatchTID
		)

		-- Exclude existing hostname/taxon name matches.
		WHERE existing_match.id IS NULL

		
		--==========================================================================================================
		-- Indirect matches
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			host_token_id,
			is_active,
			match_type_tid,
			parent_match_id,
			taxon_name_id
		)
		SELECT 
			direct_token.id AS host_token_id,
			indirect_tn.is_valid AS is_active,
			@indirectMatchTID,
			direct_tnm.id AS parent_match_id,
			indirect_tn.id AS taxon_name_id

		-- Existing direct matches
		FROM @hostTokens ht
		JOIN host_token_taxon_name_match direct_tnm ON direct_tnm.host_token_id = ht.id
		JOIN host_token direct_token ON direct_token.id = direct_tnm.host_token_id
		JOIN taxon_name direct_tn ON direct_tn.id = direct_tnm.taxon_name_id

		-- Other taxon names with the same taxonomy DB/ID as the matching taxon names.
		JOIN taxon_name indirect_tn ON (
			indirect_tn.taxonomy_db_tid = direct_tn.taxonomy_db_tid
			AND indirect_tn.taxonomy_id = direct_tn.taxonomy_id
			AND indirect_tn.id <> direct_tn.id
		)

		-- If there are any existing matches with this host token ID and taxon name ID, we will exclude them.
		LEFT JOIN host_token_taxon_name_match existing_tnm ON (
			existing_tnm.host_token_id = direct_token.id
			AND existing_tnm.taxon_name_id = indirect_tn.id
		)

		WHERE direct_tnm.match_type_tid = @directMatchTID

		-- Exclude existing matches
		AND existing_tnm.id	IS NULL

		
		--==========================================================================================================
		-- Direct xrefs
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			host_token_id,
			is_active,
			match_type_tid,
			parent_match_id,
			taxon_name_id
		)
		SELECT 
			indirect_tnm.host_token_id AS host_token_id,
			direct_xref_tn.is_valid,
			@directMatchXRefTID,
			indirect_tnm.id AS parent_match_id,
			direct_xref_tn.id AS taxon_name_id

		-- Existing indirect matches
		FROM @hostTokens ht
		JOIN host_token_taxon_name_match indirect_tnm ON indirect_tnm.host_token_id = ht.id
		JOIN taxon_name indirect_tn ON indirect_tn.id = indirect_tnm.taxon_name_id

		-- Taxon name matches for the indirect match with the same name but a different taxonomy DB or taxonomy ID.
		JOIN taxon_name direct_xref_tn ON (
			direct_xref_tn.filtered_name = indirect_tn.filtered_name
			AND direct_xref_tn.id <> indirect_tn.id
			AND (
				direct_xref_tn.taxonomy_db_tid <> indirect_tn.taxonomy_db_tid
				OR direct_xref_tn.taxonomy_id <> indirect_tn.taxonomy_id
			)
		)

		-- Existing host token/taxon name matches
		LEFT JOIN host_token_taxon_name_match existing_tnm ON (
			existing_tnm.host_token_id = indirect_tnm.host_token_id
			AND existing_tnm.taxon_name_id = direct_xref_tn.id
		)

		WHERE indirect_tnm.match_type_tid = @indirectMatchTID

		-- Exclude existing host token/taxon name matches.
		AND existing_tnm.id IS NULL
		
		
		--==========================================================================================================
		-- Indirect xrefs
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			host_token_id,
			is_active,
			match_type_tid,
			parent_match_id,
			taxon_name_id
		)
		SELECT 
			direct_xref_token.id AS host_token_id,
			indirect_xref_tn.is_valid AS is_active,
			@indirectMatchXRefTID,
			direct_xref_tnm.id AS parent_match_id,
			indirect_xref_tn.id AS taxon_name_id

		-- Existing direct cross reference matches
		FROM @hostTokens ht
		JOIN host_token_taxon_name_match direct_xref_tnm ON direct_xref_tnm.host_token_id = ht.id
		JOIN host_token direct_xref_token ON direct_xref_token.id = direct_xref_tnm.host_token_id
		JOIN taxon_name direct_xref_tn ON direct_xref_tn.id = direct_xref_tnm.taxon_name_id

		-- Other taxon names with the same taxonomy DB/ID as the matching taxon names.
		JOIN taxon_name indirect_xref_tn ON (

			-- Same taxonomy DB and ID as the direct xref taxon name.
			indirect_xref_tn.taxonomy_db_tid = direct_xref_tn.taxonomy_db_tid
			AND indirect_xref_tn.taxonomy_id = direct_xref_tn.taxonomy_id

			-- But not the direct xref taxon name.
			AND indirect_xref_tn.id <> direct_xref_tn.id
		)

		-- If there are any existing matches with this host token ID and taxon name ID, we will exclude them.
		LEFT JOIN host_token_taxon_name_match existing_tnm ON (
			existing_tnm.host_token_id = direct_xref_token.id
			AND existing_tnm.taxon_name_id = indirect_xref_tn.id
		)

		WHERE direct_xref_tnm.match_type_tid = @directMatchXRefTID

		-- Exclude existing matches
		AND existing_tnm.id	IS NULL


		--==========================================================================================================
		-- Indirect ITIS synonyms
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			host_token_id,
			is_active,
			match_type_tid,
			parent_match_id,
			taxon_name_id
		)	
		SELECT 
			direct_match.host_token_id,
			is_active = CASE
				WHEN valid_taxon_name.id IS NOT NULL THEN 1
				WHEN invalid_taxon_name.id IS NOT NULL THEN 0
				ELSE 0
			END,
			@indirectMatchTID AS match_type_tid,
			direct_match.id AS parent_match_id,
			taxon_name_id = CASE
				WHEN valid_taxon_name.id IS NOT NULL THEN valid_taxon_name.id
				WHEN invalid_taxon_name.id IS NOT NULL THEN invalid_taxon_name.id
				ELSE NULL
			END

		FROM @hostTokens h 
		JOIN host_token_taxon_name_match direct_match ON direct_match.host_token_id = h.id
		JOIN taxon_name match_tn ON match_tn.id = direct_match.taxon_name_id

		--==========================================================================================================
		-- Map invalid direct matches to valid ITIS synonyms
		--==========================================================================================================
		LEFT JOIN [ITIS_TAXONOMY].dbo.synonym_links valid_synonyms ON (

			-- Invalid direct match
			match_tn.is_valid = 0

			-- The direct match is the synonym's "invalid" TSN
			AND valid_synonyms.tsn = match_tn.taxonomy_id
		)

		--==========================================================================================================
		-- The taxon names of valid synonyms
		--==========================================================================================================
		LEFT JOIN taxon_name valid_taxon_name ON (
			valid_synonyms.tsn IS NOT NULL
			AND valid_taxon_name.taxonomy_db_tid = @itisDbTID
			AND valid_taxon_name.taxonomy_id = valid_synonyms.tsn_accepted
			AND valid_taxon_name.id <> match_tn.id
		)

		--==========================================================================================================
		-- Map valid direct matches to invalid ITIS synonyms
		--==========================================================================================================
		LEFT JOIN [ITIS_TAXONOMY].dbo.synonym_links invalid_synonyms ON (
	
			-- Valid direct match
			match_tn.is_valid = 1

			-- The direct match is the synonym's "valid" TSN
			AND invalid_synonyms.tsn_accepted = match_tn.taxonomy_id
		)

		--==========================================================================================================
		-- The taxon names of invalid synonyms
		--==========================================================================================================
		LEFT JOIN taxon_name invalid_taxon_name ON (
			invalid_synonyms.tsn IS NOT NULL
			AND invalid_taxon_name.taxonomy_db_tid = @itisDbTID
			AND invalid_taxon_name.taxonomy_id = invalid_synonyms.tsn
			AND invalid_taxon_name.id <> match_tn.id
		)

		--==========================================================================================================
		-- If there are any existing matches, we will exclude them.
		--==========================================================================================================
		LEFT JOIN host_token_taxon_name_match existing_match ON (
			existing_match.host_token_id = h.id
			AND existing_match.parent_match_id = direct_match.id
			AND existing_match.match_type_tid = @indirectMatchTID
			AND existing_match.taxon_name_id = CASE 
				WHEN valid_taxon_name.id IS NOT NULL THEN valid_taxon_name.id
				WHEN invalid_taxon_name.id IS NOT NULL THEN invalid_taxon_name.id
				ELSE NULL
			END
		)

		WHERE direct_match.match_type_tid = @directMatchTID

		-- Only consider ITIS matches
		AND match_tn.taxonomy_db_tid = @itisDbTID

		-- Make sure there was a taxon name for either a valid or invalid synonym
		AND (valid_taxon_name.id IS NOT NULL OR invalid_taxon_name.id IS NOT NULL)

		-- Exlude existing matches
		AND existing_match.id IS NULL



		--==========================================================================================================
		-- Custom name table matches
		--==========================================================================================================
		INSERT INTO host_token_taxon_name_match (
			custom_name,
			custom_name_class_tid,
			host_token_id,
			is_active,
			match_type_tid
		)

		--==========================================================================================================
		-- Custom annotation matches for common names
		--==========================================================================================================
		SELECT 
			ca.common_name AS custom_name,
			@commonNameClassTID AS name_class_tid,
			ht.id,
			ca.is_active,
			@customTextMatchTypeTID AS custom_text_match_tid

		FROM @hostTokens ht
		JOIN custom_annotation ca ON ca.search_text = ht.filtered_text

		-- Existing custom annotation matches on the host token (common names only).
		LEFT JOIN host_token_taxon_name_match existing_match ON (
			existing_match.host_token_id = ht.id
			AND existing_match.match_type_tid = @customTextMatchTypeTID
			AND existing_match.custom_name = ca.common_name
			AND existing_match.custom_name_class_tid = @commonNameClassTID
		)

		-- Exclude existing hostname/taxon name matches.
		WHERE existing_match.id IS NULL

		UNION ALL (

			--==========================================================================================================
			-- Custom annotation matches for scientific names
			--==========================================================================================================
			SELECT 
				ca.scientific_name AS custom_name,
				@scientificNameClassTID AS name_class_tid,
				ht.id,
				ca.is_active,
				@customTextMatchTypeTID AS custom_text_match_tid

			FROM @hostTokens ht
			JOIN custom_annotation ca ON ca.search_text = ht.filtered_text

			-- Existing custom annotation matches on the host token (scientific names only)
			LEFT JOIN host_token_taxon_name_match existing_match ON (
				existing_match.host_token_id = ht.id
				AND existing_match.match_type_tid = @customTextMatchTypeTID
				AND existing_match.custom_name = ca.scientific_name
				AND existing_match.custom_name_class_tid = @scientificNameClassTID
			)

			-- Exclude existing hostname/taxon name matches.
			WHERE existing_match.id IS NULL
		)


	END TRY
	BEGIN CATCH
		DECLARE @errorMsg AS VARCHAR(200) = ERROR_MESSAGE()
		RAISERROR(@errorMsg, 18, 1)
	END CATCH 
END