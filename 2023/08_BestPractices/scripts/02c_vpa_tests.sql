!cls
set serveroutput on
set echo on
set timing on

col testcaseid format a10
col vpa_enable format a10

-- Drop results table
drop table vpa_test_results purge
/

-- Re-create results table
create table vpa_test_results (
  id number generated always as identity,
  testcaseid number,
  testcasedesc varchar2(100),
  testrun number,
  vpa_enabled number default 0,
  starttime timestamp(6),
  endtime timestamp(6),
  runtime_in_millisec number
) nologging
/

-- 
-- Data origin: https://gadm.org/download_country.html
-- Data set for Testcase 1: Finland / Admin boundaries level 2
--
select gid_2, name_2, sdo_util.getnumvertices(g.geom) as num_vertices
from gadm_fin_level2 g
order by 1
fetch first 10 rows only;

pause

-- Flush shared pool
alter system flush shared_pool;
-- Disable VPA
alter session set spatial_vector_acceleration = FALSE;

-- Run with VPA disabled
@@02c_vpa_tests_01a.sql

-- Flush shared pool
alter system flush shared_pool;
-- Enable VPA
alter session set spatial_vector_acceleration = TRUE;

-- Run with VPA enabled
@@02c_vpa_tests_01b.sql

-- Report test results
select testcaseid, vpa_enabled, testcasedesc, endtime-starttime as runtime
from vpa_test_results
order by 1,2;

set timing off
set echo off
set serveroutput off

