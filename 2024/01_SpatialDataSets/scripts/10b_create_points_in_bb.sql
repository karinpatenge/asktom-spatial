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
drop table points_geom_bb purge;
drop table points_lonlat_bb purge;

create table points_geom_bb (
    id number,
    geom sdo_geometry,
    constraint points_geom_bb_pk primary key (id) enable);

create table points_lonlat_bb (
    id number,
    longitude number(13,10),
    latitude number(13,10),
    constraint points_lonlat_bb_pk primary key (id) enable
) nologging nocompress
clustering by interleaved order (longitude, latitude) yes on load;

-----------------------------------------------
-- Procedures to fill tables with random points
-----------------------------------------------

-- 1. Fill with SDO_GEOMETRY points
create or replace procedure create_random_points_bb (
    p_batch_size in number default 10,
    p_lower_left_x in number default 0.0,
    p_lower_left_y in number default 0.0,
    p_upper_right_x in number default 0.0,
    p_upper_right_y in number default 0.0
) is
    type t_points_geom_bb is table of points_geom_bb%ROWTYPE;
    l_tab t_points_geom_bb := t_points_geom_bb();

    -- Sample size
    l_batch_size number;

    l_last_id number;
    l_curr_lon number;
    l_curr_lat number;
    l_geom sdo_geometry;
begin

    l_batch_size := p_batch_size;

    if
        p_lower_left_x < -180.0 or
        p_lower_left_x > 180 or
        p_upper_right_x < -180.0 or
        p_upper_right_x > 180.0 or
        p_lower_left_x < -180.0 or
        p_lower_left_x > 180 or
        p_upper_right_x < -180.0 or
        p_upper_right_x > 180.0
    then
        dbms_output.put_line('Invalid value(s) for the bounding box.');
        dbms_output.put_line('X must be >= -180 and <= 180.');
        dbms_output.put_line('Y must be >= -90 and <= 90.');
    else

    -- Fetch last id from points_geom_bb table
    select nvl(max(id),0) + 1 into l_last_id from points_geom_bb;

    -- Populate sample as collection
    for j in 1 .. l_batch_size loop
        l_curr_lon := round(dbms_random.value(p_lower_left_x,p_upper_right_x),10);
        l_curr_lat := round(dbms_random.value(p_lower_left_y,p_upper_right_y),10);
        l_geom := mdsys.sdo_geometry (2001, 4326, sdo_point_type (l_curr_lat, l_curr_lon, null), null, null);
        l_tab.extend;
        l_tab(l_tab.last).id := l_last_id;
        l_tab(l_tab.last).geom := l_geom;
        l_last_id := l_last_id + 1;
    end loop;

    -- Ingest batch with points
    forall j in l_tab.first .. l_tab.last
        insert /*+ APPEND_VALUES PARALLEL */ into points_geom_bb values l_tab(j);
    commit;
    end if;
end;
/

-- Insert 150K random point geometries
declare
    l_batch_num number := 15;
begin
    for i in 1 .. l_batch_num loop
        create_random_points_bb(10000);
    end loop;
end;
/

select * from points_geom_bb
fetch first 10 rows only;

select count(*) from points_geom_bb;

-- 2. Fill with lon/lat points
create or replace procedure create_random_lonlat_bb (
    p_batch_size in number default 1000,
    p_lower_left_x in number default 0.0,
    p_lower_left_y in number default 0.0,
    p_upper_right_x in number default 0.0,
    p_upper_right_y in number default 0.0
) is
    type t_points_lonlat_bb is table of points_lonlat_bb%ROWTYPE;
    l_tab t_points_lonlat_bb := t_points_lonlat_bb();

    -- Sample size
    l_batch_size number;

    l_last_id number;
    l_curr_lon number(13,10);
    l_curr_lat number(13,10);
begin

    l_batch_size := p_batch_size;

    -- Fetch last id from points_geom_bb table
    select nvl(max(id),0) + 1 into l_last_id from points_lonlat_bb;

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
        insert /*+ APPEND_VALUES PARALLEL */ into points_lonlat_bb values l_tab(j);
    commit;
end;
/

-- Insert 150K random lon/lat values
declare
    l_batch_num number := 15;
begin
    for i in 1 .. l_batch_num loop
        create_random_lonlat_bb(10000);
    end loop;
end;
/

select * from points_lonlat_bb
fetch first 10 rows only;

select count(*) from points_lonlat_bb;

------------------------
-- Register SDO metadata
------------------------
delete from user_sdo_geom_metadata
where
    table_name = 'POINTS_GEOM_BB';

delete from user_sdo_geom_metadata
where
    table_name = 'POINTS_LONLAT_BB';

commit;

insert into user_sdo_geom_metadata
values (
    'POINTS_GEOM_BB',
    'GEOM',
    sdo_dim_array(
        sdo_dim_element('Lon',-180.0,180,0.05),
        sdo_dim_element('Lat',-90.0,900,0.05)
    ),
    4326
);

insert into user_sdo_geom_metadata
values (
    'POINTS_LONLAT_BB',
    'ASKTOM.GET_GEOMETRY(longitude,latitude)',
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
drop index points_geom_bb_sidx force;
drop index points_lonlat_bb_sidx force;

create index points_geom_bb_sidx on points_geom_bb(geom)
indextype is mdsys.spatial_index_v2 parameters('layer_gtype=POINT cbtree_index=true')
parallel;

create index points_lonlat_bb_sidx on points_lonlat_bb(asktom.get_geometry(longitude,latitude))
indextype is mdsys.spatial_index_v2 parameters('layer_gtype=POINT cbtree_index=true')
parallel;