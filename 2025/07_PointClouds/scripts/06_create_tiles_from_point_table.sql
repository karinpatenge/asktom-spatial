--
-- Create and populate a table containing the spatial extents of the lidar data in the point table
--

-- Set up table
DROP TABLE IF EXISTS LIDAR_TILES PURGE;

CREATE TABLE IF NOT EXISTS lidar_tiles (
  tile_id NUMBER,
  bbox SDO_GEOMETRY
);

-- Select min and max coordinate values
CREATE OR REPLACE VIEW vw_lidar_points_bbox AS
SELECT
  tile_id,
  min(x) minx,
  min(y) miny,
  max(x) maxx,
  max(y) maxy
FROM
  lidar_points
GROUP BY
  tile_id
ORDER BY
  tile_id;

SELECT * FROM vw_lidar_points_bbox;

-- Populate the tiles table with optimized polygons derived from min and max coordinate values
INSERT INTO lidar_tiles (
  tile_id,
  bbox
)
SELECT
  tile_id,
  sdo_geometry(
    2003,
    25832,
    null,
    sdo_elem_info_array(1, 1003, 3),
    sdo_ordinate_array (minx, miny, maxx, maxy))
FROM
  vw_lidar_points_bbox;

-- Register SDO metadata
DELETE FROM user_sdo_geom_metadata WHERE table_name = 'LIDAR_TILES';

INSERT INTO
  user_sdo_geom_metadata
VALUES(
  'LIDAR_TILES',
  'BBOX',
  sdo_dim_array(
    sdo_dim_element('EASTING', 280000.25, 281999.75, 0.000005),
    sdo_dim_element('NORTHING', 5652000.250, 5661999.75, 0.000005)
  ),
  25832);

COMMIT;

-- Create spatial index on lidar tiles
DROP INDEX sidx_lidar_tiles FORCE;
CREATE INDEX sidx_lidar_tiles ON lidar_tiles (bbox) INDEXTYPE IS mdsys.spatial_index_v2;


