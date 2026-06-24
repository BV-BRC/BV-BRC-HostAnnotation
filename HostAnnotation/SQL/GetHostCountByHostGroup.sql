

-- Get number of hosts in each host group.
select
	algae = SUM(CASE WHEN ah.bvbrc_host_group = 'algae' THEN 1 ELSE 0 END),
	amphibian = SUM(CASE WHEN ah.bvbrc_host_group = 'amphibian' THEN 1 ELSE 0 END),
	annelid = SUM(CASE WHEN ah.bvbrc_host_group = 'annelid' THEN 1 ELSE 0 END),
	ascaridida = SUM(CASE WHEN ah.bvbrc_host_group = 'ascaridida' THEN 1 ELSE 0 END),
	avian = SUM(CASE WHEN ah.bvbrc_host_group = 'avian' THEN 1 ELSE 0 END),
	bacteria = SUM(CASE WHEN ah.bvbrc_host_group = 'bacteria' THEN 1 ELSE 0 END),
	bivalve = SUM(CASE WHEN ah.bvbrc_host_group = 'bivalve' THEN 1 ELSE 0 END),
	coral = SUM(CASE WHEN ah.bvbrc_host_group = 'coral' THEN 1 ELSE 0 END),
	crustaceans = SUM(CASE WHEN ah.bvbrc_host_group = 'crustaceans' THEN 1 ELSE 0 END),
	diatoms = SUM(CASE WHEN ah.bvbrc_host_group = 'diatoms' THEN 1 ELSE 0 END),
	fish = SUM(CASE WHEN ah.bvbrc_host_group = 'fish' THEN 1 ELSE 0 END),
	fungi = SUM(CASE WHEN ah.bvbrc_host_group = 'fungi' THEN 1 ELSE 0 END),
	gastropod = SUM(CASE WHEN ah.bvbrc_host_group = 'gastropod' THEN 1 ELSE 0 END),
	human = SUM(CASE WHEN ah.bvbrc_host_group = 'human' THEN 1 ELSE 0 END),
	insect = SUM(CASE WHEN ah.bvbrc_host_group = 'insect' THEN 1 ELSE 0 END),
	molluscs = SUM(CASE WHEN ah.bvbrc_host_group = 'molluscs' THEN 1 ELSE 0 END),
	nematode = SUM(CASE WHEN ah.bvbrc_host_group = 'nematode' THEN 1 ELSE 0 END),
	non_human_mammal = SUM(CASE WHEN ah.bvbrc_host_group = 'non-human mammal' THEN 1 ELSE 0 END),
	plant = SUM(CASE WHEN ah.bvbrc_host_group = 'plant' THEN 1 ELSE 0 END),
	reptile = SUM(CASE WHEN ah.bvbrc_host_group = 'reptile' THEN 1 ELSE 0 END),
	sea_mammal = SUM(CASE WHEN ah.bvbrc_host_group = 'sea mammal' THEN 1 ELSE 0 END),
	sponge = SUM(CASE WHEN ah.bvbrc_host_group = 'sponge' THEN 1 ELSE 0 END),
	tick = SUM(CASE WHEN ah.bvbrc_host_group = 'tick' THEN 1 ELSE 0 END),
	total = SUM(1)

from v_annotated_host ah
join hosts h on h.id = ah.host_id
where h.group_id = 31626
