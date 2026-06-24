
-- Export all genomes with host names mapped to host annotations.

-- CSV header: genome_id,genome_name,host_name,rank_name,scientific_name,common_name,common_name_synonyms,lineage,class_scientific_name,class_common_name,host_group,taxonomy_db,taxonomy_id

DECLARE @groupID INT = 31626

/*SELECT
	'genome_id',
	'genome_name',
	'host_name',
	'rank_name',
	'scientific_name',
	'common_name',
	'common_name_synonyms',
	'lineage',
	'class_scientific_name',
	'class_common_name',
	'host_group',
	'taxonomy_db',
	'taxonomy_id'*/

-- UNION ALL (
SELECT TOP 20000000
	g.genome_id,
	g.genome_name,
	h.text as [host_name],
	ah.rank_name,
	ah.scientific_name,
	ah.common_name,
	ah.com_name_synonyms as common_name_synonyms,
	ah.lineage,
	ah.class_sci_name as class_scientific_name,
	ah.class_common_name,
	ah.bvbrc_host_group as host_group,
	ah.taxonomy_db,
	ah.taxonomy_id

FROM genomes_041526_perl g
JOIN hosts h ON h.text = g.host_name
JOIN v_annotated_host ah ON ah.host_id = h.id
WHERE h.group_id = @groupID
AND h.text NOT IN ('no data')
AND h.id NOT IN (46127)
AND ah.rank_name IS NOT NULL
ORDER BY h.text
