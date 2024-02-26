/***************************************************************************************************************
 * Data source laz files: https://github.com/PDAL/data/tree/master/liblas
 * Convert .laz to text using LAStools
 * Load text files into the Oracle Database (23c) using SQLcl

 * %LASHOME%\bin\lasinfo -no_check "Palm Beach Pre Hurricane.laz" -v
 * %LASHOME%\bin\lasinfo -no_check "Palm Beach Post Hurricane.laz" -v

 * %LASHOME%\bin\las2txt -i "Palm Beach Pre Hurricane.laz" -o PalmBeach_PreHurricane.txt -parse xyzirndecaupM -sep semicolon
 * %LASHOME%\bin\las2txt -i "Palm Beach Post Hurricane.laz" -o PalmBeach_PostHurricane.txt -parse xyzirndecaupM -sep semicolon
 ***************************************************************************************************************/

drop table if exists input_table purge;
create table if not exists lidar_input_table (
    x                       number(38,10)           -- X coordinate
    , y                     number(38,10)           -- Y coordinate
    , z                     number(38,10)           -- Z height
    , intensity             number(38,0)            -- intensity
    , number_of_return      number(38,0)            -- number of this return
    , number_of_returns     number(38,0)            -- number of returns for given pulse
    , direction_of_scan     number(38,0)            -- direction of scan flag
    , edge_of_flight_line   number(38,0)            -- edge of flight line flag
    , classification        number(38,0)            -- classification
    , scanAangle            number(38,0)            -- scan angle
    , user_data             number(38,0)            -- user data
    , point_source_id       number(38,0)            -- point source ID
    , gps_time              number(38,10)           -- gps time
    , red                   number(38,0)            -- red channel of RGB color
    , green                 number(38,0)            -- green channel of RGB color
    , blue                  number(38,0)            -- blue channel of RGB color
    , point_index           number(38,0)            -- the index for each point
);

create or replace view vw_lidar_input_table as
select
    '' as rid
    , x as val_d1
    , y as val_d2
    , z as val_d3
from
    lidar_input_table;

---------------------
-- Working with PCs
---------------------

-- Clean up
drop table if exists lidar_scenes_blks purge;
drop table if exists lidar_scenes purge;

-- Create tables
create table if not exists lidar_scenes (
    id number primary key
    , point_cloud sdo_pc
    , description varchar2(2000)
)
nologging;

create table if not exists lidar_scenes_blks of sdo_pc_blk (
    primary key (
        obj_id, blk_id
    )
)
lob (points) store as securefile (compress high nocache nologging);


-- Load settings
set load batch_rows 1000 batches_per_commit 1000 mapnames (X=X, Y=Y, Z=Z)
set loadformat delimited column_names on delimiter ; enclosures off

-- Load 1st data set
truncate table lidar_input_table;

load table lidar_input_table PalmBeach_PreHurricane.txt

select count(*) from lidar_input_table;

insert into lidar_scenes (
    id
    , point_cloud
    , description
) values (
    1
    , sdo_pc_pkg.init (
        basetable            => 'LIDAR_SCENES'
        , basecol            => 'POINT_CLOUD'
        , blktable           => 'LIDAR_SCENES_BLKS'
        , ptn_params         => 'BLK_CAPACITY=10000'
        , pc_tol             => 0.05
        , pc_tot_dimensions  => 3
        , pc_extent          => sdo_geometry (
            2003
            , null
            , null
            , sdo_elem_info_array(1, 1003, 3)
            , sdo_ordinate_array(960000, 890000, 980000, 910000))
    )
    , 'Palm Beach Pre Hurricane from https://github.com/PDAL/data/tree/master/liblas'
);
commit;

--
-- Load the point cloud from the point table
-- WARNING: this takes some minutes to complete!
-- Note that this creates a spatial index on the blocks table.
--
declare
  pc sdo_pc;
begin
  -- Read PC metadata
  select point_cloud into pc
  from lidar_scenes
  where id = 1;

  -- Load the point cloud
  sdo_pc_pkg.create_pc (pc, 'VW_LIDAR_INPUT_TABLE');
end;
/
commit;

-- Load 2nd data set
truncate table lidar_input_table;

load table lidar_input_table PalmBeach_PostHurricane.txt

select count(*) from lidar_input_table;


insert into lidar_scenes (
    id
    , point_cloud
    , description
) values (
    2
    , sdo_pc_pkg.init (
        basetable            => 'LIDAR_SCENES'
        , basecol            => 'POINT_CLOUD'
        , blktable           => 'LIDAR_SCENES_BLKS'
        , ptn_params         => 'BLK_CAPACITY=10000'
        , pc_tol             => 0.05
        , pc_tot_dimensions  => 3
        , pc_extent          => sdo_geometry (
            2003
            , null
            , null
            , sdo_elem_info_array(1, 1003, 3)
            , sdo_ordinate_array(960000, 890000, 980000, 910000))
    )
    , 'Palm Beach Post Hurricane from https://github.com/PDAL/data/tree/master/liblas'
);
commit;


declare
  pc sdo_pc;
begin
  -- Read PC metadata
  select point_cloud into pc
  from lidar_scenes
  where id = 2;

  -- Load the point cloud
  sdo_pc_pkg.create_pc (pc, 'VW_LIDAR_INPUT_TABLE');
end;
/
commit;



-- Get extent
select
    min(val_d1) minx, min(val_d2) miny, min(val_d3) minz
    , max(val_d1) maxx, max(val_d2) maxy, max(val_d3) maxz
from vw_lidar_input_table;

/*
      MINX       MINY       MINZ       MAXX       MAXY       MAXZ
---------- ---------- ---------- ---------- ---------- ----------
968669.842 892322.496 -36.8083382  974241.66 909259.356 266.065115

*/

-- SDO metadata
delete from user_sdo_geom_metadata where table_name = 'LIDAR_SCENES_BLKS';
insert into user_sdo_geom_metadata
values (
    'LIDAR_SCENES_BLKS'
    , 'BLK_EXTENT'
    , sdo_dim_array(
        sdo_dim_element('X', 968669.842, 974241.66, 0.05)
        , sdo_dim_element('Y', 892322.496, 909259.356, 0.05)
        , sdo_dim_element('Z', -36.8083382, 266.065115, 0.05))
    , null
);
commit;
