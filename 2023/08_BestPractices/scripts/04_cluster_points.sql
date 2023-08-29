!cls
set define off
set sqlblanklines on
set pause on
set timing on
set echo on

set timing on

drop table points purge;

create table points (
  id number,
  capture_time date,
  longitude	number,
  latitude number
) nologging nocompress;

pause

-- Create 1 Mio random points
insert /*+ APPEND */ into points (
  id,
  capture_time,
  longitude,
  latitude
)
  select
    rownum,
    sysdate - rownum/(24*3600) as capture_time,
    round(dbms_random.value(0,15),7) as longitude,
    round(dbms_random.value(45,65),7) as latitude
  from
    (select 1 from dual connect by level <= 1000),
    (select 1 from dual connect by level <= 1000);

commit;

select count(*) from points;

select id, capture_time, longitude, latitude
from points
fetch first 10 rows only;

pause

-----------------------------------------------------
-- Attribute clustering
-- Only available for direct path insert operations,
--   for example from staging table or external table
-- Documentation: 19c https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/attribute-clustering.html#GUID-7B007A3C-53C2-4437-9E71-9ECECF8B4FAB
-----------------------------------------------------

drop table points_clustered purge;

create table points_clustered (
  id number,
  capture_time date,
  longitude	number,
  latitude number,
  capture_time_as_epoch number
)
nocompress nologging
clustering by interleaved order (capture_time, longitude, latitude) yes on load;

pause

-- Create 1 Mio random but points clustered by interleaved order
insert /*+ APPEND */ into points_clustered (
  id,
  capture_time,
  longitude,
  latitude
)
  select
    rownum,
    sysdate - rownum/(24*3600) as capture_time,
    round(dbms_random.value(0,15),7) as longitude,
    round(dbms_random.value(45,65),7) as latitude
  from
    (select 1 from dual connect by level <= 1000),
    (select 1 from dual connect by level <= 1000);

commit;

select count(*) from points;

select id, capture_time, longitude, latitude
from points_clustered
fetch first 10 rows only;

set timing off
set echo off
set pause off