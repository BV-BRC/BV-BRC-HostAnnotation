
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 03/18/26
-- Description: Import ITIS records into tmp_lineage
-- Updated: 
-- ============================================================================================================================

-- Delete any existing versions.
IF OBJECT_ID('dbo.importItisTmpLineage') IS NOT NULL
	DROP PROCEDURE dbo.importItisTmpLineage
GO

CREATE PROCEDURE dbo.importItisTmpLineage
	@kingdomID INT,
	@resetLineage BIT
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	-- The term ID for the ITIS database.
	DECLARE @itisDbTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.itis')
	IF @itisDbTID IS NULL THROW @errorCode, 'Invalid term id for ITIS taxonomy db', 1;

	-- Should we delete any existing ITIS records for this kingdom?
	IF @resetLineage = 1 DELETE FROM tmp_lineage WHERE taxonomy_db_tid = @itisDbTID AND division_or_kingdom_id = @kingdomID
	ELSE
		BEGIN
			-- Make sure we aren't duplicating existing records.
			DECLARE @existing INT = (
				SELECT COUNT(*) 
				FROM tmp_lineage 
				WHERE taxonomy_db_tid = @itisDbTID 
				AND division_or_kingdom_id = @kingdomID
			)
			IF @existing > 0 THROW @errorCode, 'Taxa for this kingdom have already been imported', 1;
		END

	/*
	ITIS Kingdoms
	1	Bacteria  
	2	Protozoa  
	3	Plantae   
	4	Fungi     
	5	Animalia  
	6	Chromista 
	7	Archaea   
	*/

	INSERT INTO tmp_lineage (
		division_or_kingdom_id,
		lineage_names,
		lineage_ranks,
		lineage_status,
		lineage_tax_ids,
		name,
		parent_taxonomy_id,
		rank_name,
		taxonomy_db_tid,
		taxonomy_id
	) 
	SELECT
		tu.kingdom_id,
		NULL AS lineage_names,
		NULL AS lineage_ranks,
		0 AS lineage_status,
		NULL AS lineage_tax_ids,
		TRIM(tu.complete_name) AS name,
		tu.parent_tsn,
		TRIM(tut.rank_name) AS rank_name,
		@itisDbTID AS taxonomy_db_tid,
		tu.tsn AS taxonomy_id

	FROM ITIS_TAXONOMY.dbo.taxonomic_units tu
	JOIN ITIS_TAXONOMY.dbo.taxon_unit_types tut ON tut.kingdom_id = tu.kingdom_id AND tut.rank_id = tu.rank_id
	WHERE tu.kingdom_id = @kingdomID
	AND tu.usage IN ('accepted','valid') 
	AND tu.name_usage IN ('accepted','valid') 

END