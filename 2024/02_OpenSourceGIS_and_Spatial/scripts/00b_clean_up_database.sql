--------------------
-- Clean up database
--------------------

-- Truncate table with raster data
truncate table rasters drop storage;

-- Drop tables with vector data
drop table us_blockgroups purge;
drop table us_counties purge;
drop table us_interstates purge;
drop table us_parks purge;
drop table us_rivers purge;
drop table us_states purge;
drop table world_continents purge;
drop table world_countries purge;
drop table nyc_borough_boundaries purge;
drop table nyc_subway_lines purge;

-- Unregister SDO metadata
delete from user_sdo_geom_metadata;
commit;

select * from user_sdo_geom_metadata order by table_name;

