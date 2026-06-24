
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 04/08/26
-- Description: Initialize the tmp_lineage table with eBird scientific names.
-- Updated: 
-- ============================================================================================================================

CREATE OR ALTER PROCEDURE dbo.rebuildTmpLineageForEbird
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	DECLARE @listDelimiter CHAR(1) = ';';

	-- Lineage statuses
	DECLARE @PROCESSED SMALLINT = 3;

	-- The "scientific name" name class
	DECLARE @sciNameTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'ncbi_name_class.scientific_name')
	IF @sciNameTID IS NULL THROW @errorCode, 'Invalid term id for scientific name', 1

	-- Taxonomy database term IDs
	DECLARE @ebirdDbTID INT = (SELECT TOP 1 term_id FROM term WHERE term_full_key = 'taxonomy_db.ebird')
	IF @ebirdDbTID IS NULL THROW @errorCode, 'Invalid term id for eBird taxonomy db', 1

	-- Remove any existing eBird records from tmp_lineage.
	DELETE FROM tmp_lineage WHERE taxonomy_db_tid = @ebirdDbTID


	-- Class Aves and its lineage from NCBI Taxonomy.
	DECLARE @classAndLineage VARCHAR(MAX) = 'superkingdom:Eukaryota;clade:Opisthokonta;kingdom:Metazoa;clade:Eumetazoa;clade:Bilateria;clade:Deuterostomia;phylum:Chordata;'+
		'subphylum:Craniata;clade:Vertebrata;clade:Gnathostomata;clade:Teleostomi;clade:Euteleostomi;superclass:Sarcopterygii;clade:Dipnotetrapodomorpha;'+
		'clade:Tetrapoda;clade:Amniota;clade:Sauropsida;clade:Sauria;clade:Archelosauria;clade:Archosauria;clade:Dinosauria;clade:Saurischia;clade:Theropoda;' +
		'clade:Coelurosauria;class:Aves;'

	/* 
	eBird records need the following processing:

	- Remove parenthetical expressions from family names.
	- Sci names that end in " sp." might be the same as the order or family name. If so, we need to exclude 
		the order or family from the lineage.
	- Exclude scientific name 'Accipitriformes/Falconiformes sp.' because it refers to 2 orders.

	*/

	-- ===============================================================================================================================
	-- Add eBird scientific names
	-- ===============================================================================================================================
	INSERT INTO tmp_lineage (
		class_name,
		host_group,
		lineage,
		lineage_status,
		[name], 
		rank_name,
		taxonomy_db_tid, 
		taxonomy_id
	)
	SELECT
		class_name,
		host_group,
		lineage = 
			-- Class Aves and its lineage from NCBI Taxonomy.
			@classAndLineage + 

			-- Add the order rank and name.
			CASE
				WHEN order_name IS NULL THEN ''
				WHEN sci_name_no_sp = order_name THEN ''
				ELSE 'order:'+order_name+';'
			END +

			-- Add the family rank and name.
			CASE
				WHEN family_name IS NULL THEN ''
				WHEN sci_name_no_sp = family_name THEN ''
				ELSE 'family:'+family_name+';'
			END,
		lineage_status,
		[name],
		rank_name,
		taxonomy_db_tid,
		taxonomy_id
	FROM (
		SELECT
			class_name = 'Aves',

			-- BV-BRC host group
			host_group = 'Avian', 

			family_name = CASE
				WHEN LEN(e.family_name) < 1 THEN NULL

				-- Remove parenthetical expressions from family names.
				ELSE SUBSTRING(e.family_name, 0, CHARINDEX('(', e.family_name, 0) - 1)
			END,
			sci_name_no_sp = REPLACE(e.scientific_name, ' sp.', ''),
			order_name = CASE
				WHEN LEN(e.order_name) < 1 THEN NULL 
				ELSE e.order_name
			END,
			lineage_status = @PROCESSED,
			[name] = e.scientific_name,
			rank_name = CASE
				WHEN e.rank_name = 'domestic' THEN 'species'
				WHEN e.rank_name = 'form' THEN 'unclassified (form)'
				WHEN e.rank_name = 'group (monotypic)' THEN 'group (monotypic)'
				WHEN e.rank_name = 'group ' THEN 'group (polytypic)'
				WHEN e.rank_name = 'hybrid' THEN 'species hybrid'
				WHEN e.rank_name = 'intergrade' THEN 'subspecies group'
				WHEN e.rank_name = 'slash' THEN 'species pair'
				WHEN e.rank_name = 'species' THEN 'species'
				WHEN e.rank_name = 'spuh' THEN 'species group'
				WHEN e.rank_name = 'subspecies' THEN 'subspecies'
				ELSE 'species'
			END,
			taxonomy_db_tid = @ebirdDbTID, 
			taxonomy_id = e.id

		FROM ebird e

		-- Exclude this record because it refers to 2 orders and we can't determine which one is correct for the lineage.
		WHERE e.scientific_name <> 'Accipitriformes/Falconiformes sp.' 

	) filtered_ebird

END