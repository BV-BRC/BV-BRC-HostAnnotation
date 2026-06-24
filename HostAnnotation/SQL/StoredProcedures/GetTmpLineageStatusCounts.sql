

-- The taxonomy database is optional.
DECLARE @taxonomyDB VARCHAR(20) = NULL
DECLARE @taxDbTID INT = NULL

IF @taxonomyDB IS NOT NULL
BEGIN
	SELECT @taxDbTID = term_id 
	FROM term 
	WHERE term_full_key = 'taxonomy_db.' + @taxonomyDB

    IF @taxDbTID IS NULL THROW @errorCode, 'Invalid term id for taxonomy db', 1
END

-- Get lineage status counts
SELECT unprocessed = (
	SELECT COUNT(*)
	FROM tmp_lineage tl 
	WHERE tl.lineage_status = 0
	AND (@taxDbTID IS NULL OR tl.taxonomy_db_tid = @taxDbTID)
),
current_parents = (
	SELECT COUNT(*)
	FROM tmp_lineage tl 
	WHERE tl.lineage_status = 1
	AND (@taxDbTID IS NULL OR tl.taxonomy_db_tid = @taxDbTID)
),
new_children = (
	SELECT COUNT(*)
	FROM tmp_lineage tl 
	WHERE tl.lineage_status = 2
	AND (@taxDbTID IS NULL OR tl.taxonomy_db_tid = @taxDbTID)
),
processed = (
	SELECT COUNT(*)
	FROM tmp_lineage tl 
	WHERE tl.lineage_status = 3
	AND (@taxDbTID IS NULL OR tl.taxonomy_db_tid = @taxDbTID)
)
