-- Create a new table to receive extruded buildings
drop table buildings_ext;
create table buildings_ext (
  building_id         number primary key,
  gmlid               varchar2(30),
  height              number,
  ground_height       number,
  geom                sdo_geometry
);

-- Extrude the buildings
insert into buildings_ext (building_id, gmlid, height, ground_height, geom)
select building_id,
       gmlid,
       height,
       ground_height,
       sdo_util.extrude (
         geom,
         sdo_number_array (ground_height),
         sdo_number_array (height),
         0.005,
         7405
       )
from building_footprints;
commit;
