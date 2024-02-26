-- Drop table
drop table rasters purge;

-- Create GeoRaster tables
create table rasters (
  image_id             number primary key,
  image_description    varchar2(255),
  image                sdo_georaster,
  source_file          varchar2(255)
);

create table rasters_rdt_01 of sdo_raster (
  primary key (
     rasterid, pyramidlevel, bandblocknumber,
     rowblocknumber, columnblocknumber
  )
)
lob(rasterblock) store as securefile (
  nocache nologging
);