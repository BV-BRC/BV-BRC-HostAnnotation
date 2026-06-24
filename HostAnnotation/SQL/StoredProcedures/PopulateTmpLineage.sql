
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================
-- Author: don dempsey
-- Created on: 03/18/26
-- Description: Iteratively populate lineage using this table.
-- Updated: 
--      dmd 04/06/26 - Added BV-BRC host group and improved class name determination, removed initialization code so that 
--          taxa must be flagged as "current parents" prior to running this script.
-- ============================================================================================================================
CREATE OR ALTER PROCEDURE dbo.populateTmpLineage
	@taxonomyDB VARCHAR(255)
AS
BEGIN
	SET XACT_ABORT, NOCOUNT ON

	-- A constant error code to use when throwing exceptions.
	DECLARE @errorCode AS INT = 50000

	DECLARE @currentIteration SMALLINT = 0;
    DECLARE @listDelimiter CHAR(1) = ';';
    DECLARE @maxIterations SMALLINT = 50;
    DECLARE @taxDbTID SMALLINT;
    DECLARE @unprocessedCount INT;

    -- Lineage statuses
    DECLARE @UNPROCESSED SMALLINT = 0;
    DECLARE @CURRENT_PARENT SMALLINT = 1;
    DECLARE @NEW_CHILD SMALLINT = 2;
    DECLARE @PROCESSED SMALLINT = 3;


    -- Start time
    DECLARE @start DATETIME = SYSDATETIME();

	-- Lookup the taxonomy DB term ID.
    SELECT @taxDbTID = term_id FROM term WHERE term_full_key = 'taxonomy_db.' + @taxonomyDB
    IF @taxDbTID IS NULL THROW @errorCode, 'Invalid term id for taxonomy db', 1

    -- Top-level taxa for this taxonomy DB should be tagged as "current parent" 
    -- prior to running this script.
    IF (SELECT COUNT(*) 
        FROM tmp_lineage 
        WHERE taxonomy_db_tid = @taxDbTID
        AND lineage_status = @CURRENT_PARENT
    ) < 1 THROW @errorCode, 'No current parents have been specified', 1

    -- Initialize the number of unprocessed nodes.
    SELECT @unprocessedCount = COUNT(*)
    FROM tmp_lineage
    WHERE taxonomy_db_tid = @taxDbTID
    AND lineage_status = @UNPROCESSED;

    -- Loop over this update as long as there are unprocessed taxa or we have exceeded the maximum number of iterations.
    WHILE @unprocessedCount > 0 AND @currentIteration <= @maxIterations
    BEGIN

        -- Update child nodes with the parent's lineage, the BV-BRC host group, and the scientific name of the taxonomic class.
        UPDATE c
        SET
            c.lineage_status = @NEW_CHILD,

            c.lineage = CASE
                WHEN p.lineage IS NULL OR LEN(p.lineage) < 1 THEN p.rank_name+':'+p.name
                ELSE p.lineage + @listDelimiter + p.rank_name+':'+p.name
            END,

            -- The scientific name of the taxon's class rank.
            c.class_name = CASE
                WHEN c.rank_name = 'class' THEN c.name ELSE p.class_name
            END,

            -- Use the parent's BV-BRC host group if it has been assigned.
            c.host_group = CASE
                WHEN c.host_group IS NOT NULL THEN c.host_group
                WHEN p.host_group IS NOT NULL AND LEN(p.host_group) > 0 THEN p.host_group 
                ELSE NULL
            END

        FROM tmp_lineage c
        INNER JOIN tmp_lineage p ON p.taxonomy_id = c.parent_taxonomy_id
        WHERE p.taxonomy_db_tid = @taxDbTID
        AND c.taxonomy_db_tid = @taxDbTID
        AND p.lineage_status = @CURRENT_PARENT;

        -- Update the current parents as "processed".
        UPDATE tmp_lineage
        SET lineage_status = @PROCESSED
        WHERE taxonomy_db_tid = @taxDbTID
        AND lineage_status = @CURRENT_PARENT;

        -- Update the new children as the current parents.
        UPDATE tmp_lineage
        SET lineage_status = @CURRENT_PARENT
        WHERE taxonomy_db_tid = @taxDbTID
        AND lineage_status = @NEW_CHILD;

        -- How many are still unprocessed?
        SELECT @unprocessedCount = COUNT(*)
        FROM tmp_lineage
        WHERE taxonomy_db_tid = @taxDbTID
        AND lineage_status = @UNPROCESSED;

        -- Increment the current iteration.
        SET @currentIteration = @currentIteration + 1;
    END;

    -- End time
    DECLARE @end DATETIME = SYSDATETIME();

    -- Calculate the duration
    DECLARE @duration INT = DATEDIFF(SECOND, @start, @end); -- Get duration in seconds

    -- Convert seconds to hours, minutes, and seconds
    DECLARE @hours INT = @duration / 3600;
    DECLARE @minutes INT = (@duration % 3600) / 60;
    DECLARE @seconds INT = @duration % 60;

    -- Display the results
    -- PRINT 'Start Time: ' + CONVERT(VARCHAR, @start, 120); -- 120 for YYYY-MM-DD HH:MI:SS
    -- PRINT 'End Time: ' + CONVERT(VARCHAR, @end, 120);

    DECLARE @elapsed VARCHAR(100) = ''

    IF @hours > 0
    BEGIN
        IF LEN(@elapsed) > 0 SET @elapsed = @elapsed + ', '
        SET @elapsed = @elapsed + CONVERT(VARCHAR, @hours)+' hour'
        IF @hours <> 1 SET @elapsed = @elapsed + 's' 
    END
    IF @minutes > 0
    BEGIN
        IF LEN(@elapsed) > 0 SET @elapsed = @elapsed + ', '
        SET @elapsed = @elapsed + CONVERT(VARCHAR, @minutes)+' minute'
        IF @minutes <> 1 SET @elapsed = @elapsed + 's' 
    END
    IF @seconds > 0
    BEGIN
        IF LEN(@elapsed) > 0 SET @elapsed = @elapsed + ', '
        SET @elapsed = @elapsed + CONVERT(VARCHAR, @seconds)+' second'
        IF @seconds <> 1 SET @elapsed = @elapsed + 's' 
    END

    PRINT '     Duration: ' + @elapsed
    PRINT '     Number of iterations: '+CAST(@currentIteration AS VARCHAR(12))

END