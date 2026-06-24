
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 03/18/26
-- Description: Import NCBI records into tmp_lineage
-- Updated: 
-- ============================================================================================================================

-- Delete any existing versions.
IF OBJECT_ID('dbo.importNcbiTmpLineage') IS NOT NULL
	DROP PROCEDURE dbo.importNcbiTmpLineage
GO

CREATE PROCEDURE dbo.importNcbiTmpLineage
	@divisionID INT,
	@resetLineage BIT
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	
	DECLARE @ncbiDbTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.ncbi')

	DECLARE @scientificNameTID AS INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'ncbi_name_class.scientific_name')

	-- Should we delete any existing NCBI records for this division?
	IF @resetLineage = 1
		DELETE FROM tmp_lineage 
		WHERE taxonomy_db_tid = @ncbiDbTID 
		AND division_or_kingdom_id = @divisionID
	ELSE
		BEGIN
			-- Make sure we aren't duplicating existing records.
			DECLARE @existing INT = (
				SELECT COUNT(*) 
				FROM tmp_lineage 
				WHERE taxonomy_db_tid = @ncbiDbTID 
				AND division_or_kingdom_id = @divisionID
			)
			IF @existing > 0 THROW @errorCode, 'Taxa for this division have already been imported', 1
		END


	-- Import NCBI scientific names
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
		@divisionID,
		null AS lineage_names,
		null AS lineage_ranks,
		0 AS lineage_status, -- unprocessed
		null AS lineage_tax_ids,
		nam.name,
		nod.parent_tax_id,
		nod.rank_name,
		@ncbiDbTID AS taxonomy_db_tid,
		nod.tax_id

	FROM NCBI_TAXONOMY.dbo.ncbi_names nam
	JOIN NCBI_TAXONOMY.dbo.ncbi_nodes nod ON nod.tax_id = nam.tax_id
	WHERE nam.name_class_tid = @scientificNameTID
	AND nod.division_id = @divisionID

END