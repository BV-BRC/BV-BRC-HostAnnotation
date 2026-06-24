
-- Delete any existing versions of the view.
IF OBJECT_ID('dbo.v_curation') IS NOT NULL
	DROP VIEW dbo.v_curation
GO

CREATE VIEW dbo.v_curation AS

SELECT 
	c.id,
    c.search_text,
    c.search_text_filtered,
    c.alternate_text,
    c.alternate_text_filtered,
    
    taxdb.term_key AS taxonomy_db,
    c.taxonomy_db_tid,
    c.taxonomy_id,

	typeterm.term_key AS [type],
    c.type_tid,

    c.[uid],
    c.is_valid,
    c.created_by,
    c.created_on,
    c.validated_by,
    c.validated_on

FROM curation c
JOIN term typeterm ON typeterm.term_id = type_tid
LEFT JOIN term taxdb ON taxdb.term_id = taxonomy_db_tid


