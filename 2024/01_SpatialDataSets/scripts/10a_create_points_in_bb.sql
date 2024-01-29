------------------------------------------
-- Create points located in a bounding box
--   1. SDO_GEOMETRY
--   2. LAT/LON values
-- Coordinate system: WGS84 (SRID = 4326)
------------------------------------------

-- Log into your DB instance as user ASKTOM

set timing on
set serveroutput on

----------------
-- Set up tables
----------------
drop table points_geom purge;
drop table points_lonlat purge;

create table points_geom (
    id number,
    geom sdo_geometry,
    constraint points_geom_pk primary key (id) enable);

create table points_lonlat (
    id number,
    longitude number(13,10),
    latitude number(13,10),
    constraint points_lonlat_pk primary key (id) enable
) nologging nocompress
clustering by interleaved order (longitude, latitude) yes on load;

-----------------------------------------------
-- Procedures to fill tables with random points
-----------------------------------------------

-- 1. Fill with SDO_GEOMETRY points
create or replace procedure create_random_points (
    p_batch_size in number default 10
) is
    type t_points_geom is table of points_geom%ROWTYPE;
    l_tab t_points_geom := t_points_geom();

    -- Sample size
    l_batch_size number;

    l_last_id number;
    l_curr_lon number;
    l_curr_lat number;
    l_geom sdo_geometry;
begin

    l_batch_size := p_batch_size;

    -- Fetch last id from points_geom table
    select nvl(max(id),0) + 1 into l_last_id from points_geom;

    -- Populate sample as collection
    for j in 1 .. l_batch_size loop
        l_curr_lon := round(dbms_random.value(-180,180),10);
        l_curr_lat := round(dbms_random.value(-90,90),10);
        l_geom := mdsys.sdo_geometry (2001, 4326, sdo_point_type (l_curr_lat, l_curr_lon, null), null, null);
        l_tab.extend;
        l_tab(l_tab.last).id := l_last_id;
        l_tab(l_tab.last).geom := l_geom;
        l_last_id := l_last_id + 1;
    end loop;

    -- Ingest batch with points
    forall j in l_tab.first .. l_tab.last
        insert /*+ APPEND_VALUES PARALLEL */ into points_geom values l_tab(j);
    commit;
end;
/

-- Insert 150K random point geometries
declare
    l_batch_num number := 15;
begin
    for i in 1 .. l_batch_num loop
        create_random_points(10000);
    end loop;
end;
/

select * from points_geom
fetch first 10 rows only;

select count(*) from points_geom;

-- 2. Fill with lon/lat points
create or replace procedure create_random_lonlat (
    p_batch_size in number default 1000
) is
    type t_points_lonlat is table of points_lonlat%ROWTYPE;
    l_tab t_points_lonlat := t_points_lonlat();

    -- Sample size
    l_batch_size number;

    l_last_id number;
    l_curr_lon number(13,10);
    l_curr_lat number(13,10);
begin

    l_batch_size := p_batch_size;

    -- Fetch last id from points_geom table
    select nvl(max(id),0) + 1 into l_last_id from points_lonlat;

    -- Populate sample as collection
    for j in 1 .. l_batch_size loop
        l_curr_lon := round(dbms_random.value(-180,180),10);
        l_curr_lat := round(dbms_random.value(-90,90),10);
        l_tab.extend;
        l_tab(l_tab.last).id := l_last_id;
        l_tab(l_tab.last).longitude := l_curr_lon;
        l_tab(l_tab.last).latitude := l_curr_lat;
        l_last_id := l_last_id + 1;
    end loop;

    -- Ingest batch with points
    forall j in l_tab.first .. l_tab.last
        insert /*+ APPEND_VALUES PARALLEL */ into points_lonlat values l_tab(j);
    commit;
end;
/

-- Insert 15 mio random lon/lat values
declare
    l_batch_num number := 15;
begin
    for i in 1 .. l_batch_num loop
        create_random_lonlat(10000);
    end loop;
end;
/
-- ~ 115 sec

select * from points_lonlat
fetch first 10 rows only;

select count(*) from points_lonlat;

------------------------
-- Register SDO metadata
------------------------
delete from user_sdo_geom_metadata
where
    table_name = 'POINTS_GEOM';

delete from user_sdo_geom_metadata
where
    table_name = 'POINTS_LONLAT';

commit;

insert into user_sdo_geom_metadata
values (
    'POINTS_GEOM',
    'GEOM',
    sdo_dim_array(
        sdo_dim_element('Lon',-180.0,180,0.05),
        sdo_dim_element('Lat',-90.0,900,0.05)
    ),
    4326
);

insert into user_sdo_geom_metadata
values (
    'POINTS_LONLAT',
    'asktom.GET_GEOMETRY(longitude,latitude)',
    sdo_dim_array(
        sdo_dim_element('Lon',-180.0,180,0.05),
        sdo_dim_element('Lat',-90.0,900,0.05)
    ),
    4326
);
commit;


-----------------------------------
-- Helper function:
-- Create SDO_GEOMETRY from Lon/lat
-----------------------------------
create or replace function get_geometry(lon number, lat number)
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

-------------------------
-- Create spatial indexes
-------------------------
drop index points_geom_sidx force;
drop index points_lonlat_sidx force;

create index points_geom_sidx on points_geom(geom)
indextype is mdsys.spatial_index_v2 parameters('layer_gtype=POINT cbtree_index=true')
parallel;

create index points_lonlat_sidx on points_lonlat(asktom.get_geometry(longitude,latitude))
indextype is mdsys.spatial_index_v2 parameters('layer_gtype=POINT cbtree_index=true')
parallel;