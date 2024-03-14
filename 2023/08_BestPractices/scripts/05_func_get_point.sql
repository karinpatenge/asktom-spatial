!cls
set define off
set sqlblanklines on
set serveroutput on
set pause off
set timing on
set echo on

-------------------------------------------------
-- Define function to create a point from lon/lat
-------------------------------------------------
create or replace function get_point_wgs84 (lon number, lat number)
   return sdo_geometry deterministic parallel_enable as
begin
   if lon is null or lat is null
   then
      return null;
   else
      return sdo_geometry(2001, 4326, sdo_point_type(lon,lat,null),null,null);
   end if;
end;
/

--------------------
-- Call the function
--------------------
select get_point_wgs84(10.0, 50.0) from dual;

-- Result:
-- MDSYS.SDO_GEOMETRY(2001, 4326, MDSYS.SDO_POINT_TYPE(10, 50, NULL), NULL, NULL)

-- Drop spatial index if exists
drop index points_sidx force;
-- Delete SDO metadata if exist
delete from user_sdo_geom_metadata where table_name = 'POINTS';
commit;

------------------------
-- Register SDO Metadata
------------------------
insert into user_sdo_geom_metadata values (
	'POINTS',
    'SPATIALUSER.GET_POINT_WGS84(LONGITUDE,LATITUDE)',
	sdo_dim_array(sdo_dim_element('Lon', -180, 180, .05),
			sdo_dim_element('Lat', -90, 90, .05)),
	4326);

commit;

--------------------------------------
-- Total number of points in the table
--------------------------------------
select count(*) from points;


--------------------------------------
-- Create function-based spatial index
--------------------------------------
create index points_sidx on points (
  get_point_wgs84(longitude, latitude)
) indextype is mdsys.spatial_index_v2 
parameters('layer_gtype=POINT cbtree_index=TRUE');

-----------------------------------
-- Use function-based spatial index
-----------------------------------
select count(*)
from points
where sdo_anyinteract (
  get_point_wgs84(longitude,latitude),
  sdo_geometry(
    2003,
    4326,
    null,
    sdo_elem_info_array(1,1003,3),
    sdo_ordinate_array(10, 50, 12, 53)))='TRUE';

select count(*)
from points
where sdo_anyinteract (
  get_point_wgs84(longitude,latitude),
  sdo_geometry(
    2003,
    4326,
    null,
    sdo_elem_info_array(1,1003,3),
    sdo_ordinate_array(10, 55, 12, 60)))='TRUE';

select count(*)
from points
where sdo_anyinteract (
  get_point_wgs84(longitude,latitude),
  (select geom from gadm_fra_level0))='TRUE';



set echo off
set timing off
set pause off