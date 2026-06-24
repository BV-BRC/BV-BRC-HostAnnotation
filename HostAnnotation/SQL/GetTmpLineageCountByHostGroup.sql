

-- Calculate the number of taxa assigned to specific host groups.
select
	algae = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'algae'
	),
	amphibian = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'amphibian'
	),
	annelid = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'annelid'
	),
	ascaridida = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'ascaridida'
	),
	avian = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'avian'
	),
	bacteria = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'bacteria'
	),
	bivalve = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'bivalve'
	),
	coral = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'coral'
	),
	crustaceans = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'crustaceans'
	),
	diatoms = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'diatoms'
	),
	fish = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'fish'
	),
	fungi = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'fungi'
	),
	gastropod = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'gastropod'
	),
	human = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'human'
	),
	insect = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'insect'
	),
	molluscs = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'molluscs'
	),
	nematode = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'nematode'
	),
	non_human_mammal = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'non-human mammal'
	),
	plant = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'plant'
	),
	reptile = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'reptile'
	),
	sea_mammal = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'sea mammal'
	),
	sponge = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'sponge'
	),
	tick = (
		select count(*)
		from tmp_lineage t
		where t.host_group = 'tick'
	)
	

/*
-- All assigned host groups
select distinct t.host_group 
from v_tmp_lineage t
order by t.host_group
*/
