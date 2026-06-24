
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 04/06/26
-- Description: Iteratively populate the tmp_lineage table for all taxonomy databases. Note that tmp_lineage should have 
--              already been populated with taxa from all taxonomy databases before running this script.
-- Updated:
-- 04/13/26 dmd: Instead of only assigning the “human” host group to homo sapiens, I assigned it to genus homo so it will 
--               be inherited by child taxa; (Parvorder) Pinnipedia is no longer in NCBI or ITIS, so I'm now assigning the 
--               host group "sea mammals" to Families Odobenidae, Otariidae, and Phocidae.
-- ============================================================================================================================
CREATE OR ALTER PROCEDURE dbo.rebuildTmpLineage
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

    -- A constant error code to use when throwing exceptions.
    DECLARE @errorCode AS INT = 50000

    -- Lineage statuses
    DECLARE @UNPROCESSED SMALLINT = 0;
    DECLARE @CURRENT_PARENT SMALLINT = 1;
    DECLARE @NEW_CHILD SMALLINT = 2;
    DECLARE @PROCESSED SMALLINT = 3;

    DECLARE @processedCount INT = 0
    DECLARE @unprocessedCount INT = 0

    -- Taxonomy DB term IDs
    DECLARE @ebirdTaxDbTID INT
    DECLARE @itisTaxDbTID INT
    DECLARE @ncbiTaxDbTID INT

    -- Lookup the taxonomy DB term IDs.
    SELECT @ebirdTaxDbTID = term_id FROM term WHERE term_full_key = 'taxonomy_db.ebird'
    IF @ebirdTaxDbTID IS NULL THROW @errorCode, 'Invalid term id for the eBird taxonomy db', 1

    SELECT @itisTaxDbTID = term_id FROM term WHERE term_full_key = 'taxonomy_db.itis'
    IF @itisTaxDbTID IS NULL THROW @errorCode, 'Invalid term id for the ITIS taxonomy db', 1

    SELECT @ncbiTaxDbTID = term_id FROM term WHERE term_full_key = 'taxonomy_db.ncbi'
    IF @ncbiTaxDbTID IS NULL THROW @errorCode, 'Invalid term id for the NCBI taxonomy db', 1


    -- Reset the lineage and host group of every record in the temp lineage table 
    -- and set all lineage statuses to "unprocessed" (0).
    UPDATE tmp_lineage SET 
        class_name = NULL, 
        host_group = NULL, 
        lineage = NULL,
        lineage_status = @UNPROCESSED


    -- Assign BV-BRC host groups to their associated parent taxa.
    UPDATE tmp_lineage SET host_group = CASE
	    WHEN name = 'Chlorophyta' OR name = 'Rhodophyta' OR name = 'Stramenopiles' THEN 'Algae'
	    WHEN name = 'Amphibia' THEN 'Amphibian'
	    WHEN name = 'Annelida' THEN 'Annelid'
 	    WHEN name = 'Ascaridomorpha' THEN 'Ascaridida'
 	    WHEN name = 'Aves' THEN 'Avian'
 	    WHEN name = 'Bacteria' THEN 'Bacteria'
	    WHEN name = 'Bivalvia' THEN 'Bivalve'
 	    WHEN name = 'Scleractinia' THEN 'Coral'
 	    WHEN name = 'Crustacea' THEN 'Crustaceans'
 	    WHEN name = 'Bacillariophyta' THEN 'Diatoms'
 	    WHEN name = 'Actinopterygii' THEN 'Fish'
 	    WHEN name = 'Fungi' THEN 'Fungi'
 	    WHEN name = 'Gastropoda' THEN 'Gastropod'
 	    WHEN name = 'Homo' THEN 'Human'
        WHEN name = 'Insecta' THEN 'Insect'
        WHEN name = 'Mammalia' THEN 'Non-human mammal'
        WHEN name = 'Mollusca' THEN 'Molluscs'
 	    WHEN name = 'Nematoda' THEN 'Nematode'
 	    WHEN name = 'Viridiplantae' THEN 'Plant'
 	    WHEN name = 'Sauropsida' OR name = 'Crocodylia' OR name = 'Lepidosauria' OR name = 'Testudines' THEN 'Reptile'
        WHEN name = 'Cetacea' OR name = 'Sirenia' OR name = 'Odobenidae' OR name = 'Otariidae' OR name = 'Phocidae'
            THEN 'Sea Mammal'
        WHEN name = 'Porifera' THEN 'Sponge'
 	    WHEN name = 'Ixodida' THEN 'Tick'
        ELSE NULL
    END
    WHERE name IN (
        'Actinopterygii',
        'Amphibia',
        'Annelida',
        'Ascaridomorpha',
        'Aves',
        'Bacillariophyta',
        'Bacteria',
        'Bivalvia',
        'Cetacea',
        'Chlorophyta',
        'Crocodylia',
        'Crustacea',
        'Fungi',
        'Gastropoda',
        'Homo',
        'Insecta',
        'Ixodida',
        'Lepidosauria',
        'Mammalia',
        'Mollusca',
        'Nematoda',
        'Odobenidae', 
        'Otariidae',
        'Phocidae',
        -- 'Pinnipedia'
        'Porifera',
        'Rhodophyta',
        'Sauropsida',
        'Scleractinia',
        'Sirenia',
        'Stramenopiles',
        'Testudines',
        'Viridiplantae'
    )

    -- ===============================================================================================================================
    -- Process NCBI Taxonomy records
    -- ===============================================================================================================================

    PRINT 'Processing NCBI Taxonomy records:'

    -- Get the top-level taxonomy ID of NCBI Taxonomy hosts.
    DECLARE @ncbiRootTaxID INT = (SELECT TOP 1 taxonomy_id FROM tmp_lineage WHERE name = 'cellular organisms')
    IF @ncbiRootTaxID IS NULL THROW @errorCode, 'Unable to find the NCBI taxon "cellular organisms"', 1

    -- Tag the immediate children of "cellular organisms" as current parents (NCBI Taxonomy).
    UPDATE tmp_lineage SET lineage_status = @CURRENT_PARENT 
    WHERE taxonomy_db_tid = @ncbiTaxDbTID
    AND parent_taxonomy_id = @ncbiRootTaxID

    -- Populate lineage for NCBI Taxonomy records.
    EXEC dbo.populateTmpLineage @taxonomyDB = 'ncbi'


    -- Calculate the number of processed and unprocessed NCBI records.
    SET @processedCount = (
        SELECT COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @ncbiTaxDbTID
        AND lineage_status = @PROCESSED
    )
    SET @unprocessedCount = (
        SELECT COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @ncbiTaxDbTID
        AND lineage_status = @UNPROCESSED
    )

    -- Display the result counts.
    PRINT '     Processed taxa: '+CAST(@processedCount AS VARCHAR(12))
    PRINT '     Unprocessed taxa: '+CAST(@unprocessedCount AS VARCHAR(12))
    PRINT ''

    -- ===============================================================================================================================
    -- Process ITIS records
    -- ===============================================================================================================================

    PRINT 'Processing ITIS records:'

    -- Tag the immediate children of TSN 0 in ITIS as current parents.
    UPDATE tmp_lineage SET lineage_status = @CURRENT_PARENT 
    WHERE taxonomy_db_tid = @itisTaxDbTID
    AND parent_taxonomy_id = 0

    -- Populate lineage for ITIS records.
    EXEC dbo.populateTmpLineage @taxonomyDB = 'itis'

    -- Calculate the number of processed and unprocessed ITIS records.
    SET @processedCount = (
        SELECT COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @itisTaxDbTID
        AND lineage_status = @PROCESSED
    )
    SET @unprocessedCount = (
        SELECT COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @itisTaxDbTID
        AND lineage_status = @UNPROCESSED
    )

    -- Display the result counts.
    PRINT '     Processed taxa: '+CAST(@processedCount AS VARCHAR(12))
    PRINT '     Unprocessed taxa: '+CAST(@unprocessedCount AS VARCHAR(12))
    PRINT ''

    -- ===============================================================================================================================
    -- Process eBird records
    -- ===============================================================================================================================

    PRINT 'Processing eBird records:'

    -- Populate lineage for eBird records.
    EXEC dbo.rebuildTmpLineageForEbird

    -- Calculate the number of processed and unprocessed eBird records.
    SET @processedCount = (
        SELECT COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @ebirdTaxDbTID
        AND lineage_status = @PROCESSED
    )
    SET @unprocessedCount = 0

    -- Display the result counts.
    PRINT '     Processed taxa: '+CAST(@processedCount AS VARCHAR(12))
    PRINT '     Unprocessed taxa: '+CAST(@unprocessedCount AS VARCHAR(12))
    PRINT ''
END