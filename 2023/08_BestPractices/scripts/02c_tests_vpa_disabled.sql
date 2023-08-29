set define off
set sqlblanklines on
set echo on

---------------
-- Turn VPA off
---------------
alter session set spatial_vector_acceleration = false;

-- -------------------------------------
-- Add queries to be traced and analyzed
-- -------------------------------------

-------------------
-- Begin test run 1
-------------------
insert into vpa_test_results(testcaseid, testcasedesc, testrun, vpa_enabled, starttime)
values (1, 'Spatial data aggregation using SDO_AGGR_UNION', 1, 0, systimestamp);

with test as (
  select sdo_aggr_union(sdoaggrtype(g.geom,0.05))
  from gadm_fin_level2 g
  where gid_1 = 'FIN.5_1')
select count(*) from test;

update vpa_test_results
set endtime = systimestamp 
where testcaseid = 1 and testrun = 1 and vpa_enabled = 0;

commit;
-----------------
-- End test run 1
-----------------

-------------------
-- Begin test run 2
-------------------
insert into vpa_test_results(testcaseid, testcasedesc, testrun, vpa_enabled, starttime)
values (2, 'Topological relationship using SDO_RELATE and masking operators TOUCH+COVEREDBY', 1, 0, systimestamp);

with test as (
  select a.gid_2, a.name_2, b.gid_3, b.name_3
  from gadm_fin_level2 a, gadm_fin_level3 b
  where a.name_2 = 'Central Finland'
    and sdo_relate(a.geom, b.geom,'mask=touch+coveredby') = 'TRUE')
select count(*) from test;

update vpa_test_results
set endtime = systimestamp
where testcaseid = 2 and testrun = 1 and vpa_enabled = 0;

commit;
-----------------
-- End test run 2
-----------------

-------------------
-- Begin test run 3
-------------------
insert into vpa_test_results(testcaseid, testcasedesc, testrun, vpa_enabled, starttime)
values (3, 'Topological relationship using SDO_TOUCH', 1, 0, systimestamp);

with test as (
  select a.gid_2, a.name_2, b.gid_3, b.name_3
  from gadm_fin_level2 a, gadm_fin_level3 b
  where a.name_2 = 'Central Finland'
    and sdo_touch(a.geom, b.geom) = 'TRUE')
select count(*) from test;

update vpa_test_results
set endtime = systimestamp
where testcaseid = 3 and testrun = 1 and vpa_enabled = 0;

commit;
-----------------
-- End test run 3
-----------------

set echo off
set timing off