
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 04/02/26
-- Description: Initialize the tmp_lineage table with NCBI, ITIS, and eBird scientific names.
-- Updated: 
-- ============================================================================================================================

-- Delete any existing versions.
IF OBJECT_ID('dbo.initializeTmpLineage') IS NOT NULL
	DROP PROCEDURE dbo.initializeTmpLineage
GO

CREATE PROCEDURE dbo.initializeTmpLineage
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	DECLARE @listDelimiter CHAR(1) = ';';

	-- Lineage statuses
    DECLARE @UNPROCESSED SMALLINT = 0;

	-- The "scientific name" name class
	DECLARE @sciNameTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'name_class.scientific_name')
	IF @sciNameTID IS NULL THROW @errorCode, 'Invalid term id for scientific name', 1

	-- Taxonomy database term IDs
	DECLARE @ebirdDbTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.ebird')
	IF @ebirdDbTID IS NULL THROW @errorCode, 'Invalid term id for eBird taxonomy db', 1

	DECLARE @itisDbTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.itis')
	IF @itisDbTID IS NULL THROW @errorCode, 'Invalid term id for ITIS taxonomy db', 1

	DECLARE @ncbiDbTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.ncbi')
	IF @ncbiDbTID IS NULL THROW @errorCode, 'Invalid term id for NCBI taxonomy db', 1


	-- Make sure tmp_lineage hasn't already been initialized.
	IF 0 < (SELECT COUNT(*) FROM tmp_lineage WHERE taxonomy_db_tid = @ncbiDbTID) THROW @errorCode, 'NCBI taxonomy records already exist', 1
	IF 0 < (SELECT COUNT(*) FROM tmp_lineage WHERE taxonomy_db_tid = @itisDbTID) THROW @errorCode, 'ITIS records already exist', 1

	-- In the INSERT queries below, lineage_names, lineage_ranks, and lineage_tax_ids are initialized to NULL by default.


	-- ===============================================================================================================================
	-- NCBI Taxonomy
	-- ===============================================================================================================================
	INSERT INTO tmp_lineage (
		division_or_kingdom_id, 
		lineage_status,
		name, 
		rank_name, 
		parent_taxonomy_id, 
		taxonomy_db_tid, 
		taxonomy_id
	)
	SELECT
		nnode.division_id, -- division_or_kingdom_id,
		@UNPROCESSED, -- lineage_status
		TRIM(nname.name), -- name
		TRIM(nnode.rank_name), -- rank_name,
		nnode.parent_tax_id, -- parent_taxonomy_id
		@ncbiDbTID, -- taxonomy_db_tid
		nnode.tax_id -- taxonomy_id

	FROM NCBI_TAXONOMY.dbo.ncbi_nodes nnode
	JOIN NCBI_TAXONOMY.dbo.ncbi_names nname ON nname.tax_id = nnode.tax_id 
	WHERE name_class_tid = @sciNameTID


	-- ===============================================================================================================================
	-- ITIS
	-- ===============================================================================================================================
	INSERT INTO tmp_lineage (
		division_or_kingdom_id, 
		lineage_status,
		name, 
		rank_name, 
		parent_taxonomy_id, 
		taxonomy_db_tid, 
		taxonomy_id
	)
	SELECT
		tu.kingdom_id, -- division_or_kingdom_id
		@UNPROCESSED, -- lineage_status
		tu.complete_name, -- name
		tut.rank_name, -- rank_name,
		tu.parent_tsn, -- parent_taxonomy_id
		@itisDbTID, -- taxonomy_db_tid
		tu.tsn -- taxonomy_id

	FROM ITIS_TAXONOMY.dbo.taxonomic_units tu
	JOIN ITIS_TAXONOMY.dbo.taxon_unit_types tut ON tut.kingdom_id = tu.kingdom_id AND tut.rank_id = tu.rank_id
	WHERE tu.usage IN ('accepted','valid')
	AND tu.name_usage IN ('accepted','valid')


	-- ===============================================================================================================================
	-- eBird
	-- ===============================================================================================================================
	INSERT INTO tmp_lineage (
		division_or_kingdom_id,
		lineage_names, 
		lineage_ranks,
		lineage_status,
		name, 
		rank_name, 
		parent_taxonomy_id, 
		taxonomy_db_tid, 
		taxonomy_id
	)
	SELECT
		NULL, -- division_or_kingdom_id
		lineage_names = CASE
			WHEN e.order_name IS NULL OR e.family_name IS NULL THEN ''
			ELSE TRIM(e.order_name)+@listDelimiter+' '+TRIM(e.family_name)
		END,
		ineage_ranks = CASE
			WHEN e.order_name IS NULL OR e.family_name IS NULL THEN ''
			ELSE 'order'+@listDelimiter+' family'
		END,
		@UNPROCESSED, -- lineage_status
		e.scientific_name, -- name
		rank_name = CASE
			WHEN e.rank_name = 'domestic' THEN 'species'
			WHEN e.rank_name = 'form' THEN 'unclassified (form)'
			WHEN e.rank_name = 'group (monotypic)' THEN 'species_group'
			WHEN e.rank_name = 'group (polytypic)' THEN 'species_group'
			WHEN e.rank_name = 'hybrid' THEN 'species_hybrid'
			WHEN e.rank_name = 'intergrade' THEN 'species_pair'
			WHEN e.rank_name = 'slash' THEN 'species_pair'
			WHEN e.rank_name = 'species' THEN 'species'
			WHEN e.rank_name = 'spuh' THEN 'species'
			WHEN e.rank_name = 'subspecies' THEN 'subspecies'
			ELSE ''
		END,
		NULL, -- parent_taxonomy_id
		@ebirdDbTID, -- taxonomy_db_tid
		e.id -- taxonomy_id

	FROM ebird e
	WHERE e.extinct = 0
	
END