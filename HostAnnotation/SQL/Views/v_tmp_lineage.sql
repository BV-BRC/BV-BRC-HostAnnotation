
-- Delete any existing versions of the view.
IF OBJECT_ID('dbo.v_tmp_lineage') IS NOT NULL
	DROP VIEW dbo.v_tmp_lineage
GO

CREATE VIEW v_tmp_lineage AS

SELECT 

tl.id,
lstatus = CASE
	WHEN tl.lineage_status = 0 THEN 'unprocessed'
	WHEN tl.lineage_status = 1 THEN 'current_parent'
	WHEN tl.lineage_status = 2 THEN 'new_child'
	WHEN tl.lineage_status = 3 THEN 'processed'
	ELSE ''
END,
tl.rank_name,
tl.name,
tl.lineage,
taxdb.term_key AS taxonomy_db,
tl.host_group,
ISNULL(tl.class_name,'') as class_name,
tl.taxonomy_id,
tl.parent_taxonomy_id,
ISNULL(d.name, k.kingdom_name) AS division_or_kingdom
-- tl.division_or_kingdom_id

FROM tmp_lineage tl
LEFT JOIN term taxdb ON taxdb.term_id = taxonomy_db_tid
LEFT JOIN NCBI_TAXONOMY.dbo.division d ON (
	tl.division_or_kingdom_id = d.id
	AND taxdb.term_key = 'ncbi'
)
LEFT JOIN ITIS_TAXONOMY.dbo.kingdoms k ON (
	k.kingdom_id = tl.division_or_kingdom_id
	AND taxdb.term_key = 'itis'
)

