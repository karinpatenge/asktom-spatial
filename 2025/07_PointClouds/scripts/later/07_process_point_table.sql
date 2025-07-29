--
-- Clipping the point table
--

-- Set up results table
DROP TABLE IF EXISTS lidar_points_clip PURGE;

CREATE TABLE IF NOT EXISTS lidar_points_clip AS
SELECT
  *
FROM
  lidar_points
WHERE
  0 = 1;

TRUNCATE TABLE lidar_points_clip DROP STORAGE;

-- Clip
DECLARE
  points_cursor sys_refcursor;
  TYPE points_list IS TABLE OF lidar_points%rowtype;
  points points_list;
BEGIN
  points_cursor :=
    SDO_PC_PKG.CLIP_PC_FLAT (
      geometry =>
        SDO_GEOMETRY (
          2003,
          25832,
          NULL,
          SDO_ELEM_INFO_ARRAY (1, 1003, 3),
          SDO_ORDINATE_ARRAY (
            281200, 5654100, 281300, 5654200
          )
        ),
      table_name    => 'LIDAR_POINTS',
      tolerance     => 0.000005,
      other_dim_qry => null,
      mask          => null   -- Default: mask=ANYINTERACT
    );
  LOOP
    FETCH points_cursor
      BULK COLLECT INTO points
      LIMIT 10000;
    FORALL I in 1 .. points.COUNT
      INSERT INTO lidar_points_clip VALUES points(i);
    EXIT WHEN points_cursor%NOTFOUND;
  END LOOP;
  CLOSE points_cursor;
END;
/

SELECT count(*) FROM lidar_points_clip;


--
-- Derive contour lines
--

-- Set up results table

DROP TABLE IF EXISTS lidar_contours PURGE;

CREATE TABLE if NOT EXISTS LIDAR_CONTOURS (
  id NUMBER PRIMARY KEY,
  elevation NUMBER,
  contour SDO_GEOMETRY
);

DELETE FROM user_sdo_geom_metadata WHERE table_name = 'LIDAR_CONTOURS';

INSERT INTO user_sdo_geom_metadata (
  table_name,
  column_name,
  diminfo,
  srid
)
VALUES (
  'LIDAR_CONTOURS',
  'CONTOUR',
  sdo_dim_array(
    sdo_dim_element('EASTING', 280000.25, 281999.75, 0.000005),
    sdo_dim_element('NORTHING', 5652000.250, 5661999.75, 0.000005)
  ),
  25832
);

COMMIT;

CREATE INDEX sidx_lidar_contours ON lidar_contours (contour)
INDEXTYPE IS mdsys.spatial_index_v2;

-- Contours
SELECT sdo_pc_pkg.create_contour_geometries (
  pc_flat_table => 'LIDAR_POINTS',
  srid => 25832,
  sampling_resolution => 50,
  elevations => sdo_ordinate_array(20, 40, 60, 80, 100, 120, 140),
  region => SDO_GEOMETRY (
    2003,
    25832,
    NULL,
    SDO_ELEM_INFO_ARRAY (1, 1003, 3),
    SDO_ORDINATE_ARRAY (
      281200, 5654100, 281300, 5654200
    )
  )
)
FROM DUAL;

SELECT sdo_pc_pkg.create_contour_geometries (
  pc_flat_table => 'LIDAR_POINTS',
  srid => 25832,
  sampling_resolution => 50,
  elevations_min => 20,
  elevations_interval => 10,
  elevations_max => 150,
  region => SDO_GEOMETRY (
    2003,
    25832,
    NULL,
    SDO_ELEM_INFO_ARRAY (1, 1003, 3),
    SDO_ORDINATE_ARRAY (
      281200, 5654100, 281300, 5654200
    )
  )
)
FROM DUAL;