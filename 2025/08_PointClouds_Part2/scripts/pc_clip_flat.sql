/***************************************************************************************************************
 * Working with Point Clouds in the Oracle Database 23ai
 *
 * Demo  : Clip points from a point cloud
 *
 * Author: Karin Patenge, Oracle
 * Date  : August 2025
 ***************************************************************************************************************/


-- Create a synthetic dataset with 3D point geometries

DROP TABLE IF EXISTS synthetic_3d_points PURGE;

CREATE TABLE IF NOT EXISTS synthetic_3d_points (
  id       number,
  geometry sdo_geometry
) NOLOGGING;

TRUNCATE TABLE synthetic_3d_points DROP STORAGE;

DECLARE
  curr_lon  number;
  curr_lat  number;
  increment number := .0001;
  id        number;
BEGIN
  id := 1;
  FOR lat in 52 .. 52 LOOP
    curr_lat := lat;
    FOR lon in 12 .. 12 LOOP
      --
      -- Create 1 million points per 1x1 degree cell
      --
      FOR i in 1 .. 1000 LOOP
        curr_lon := lon;
        FOR j IN 1 .. 1000 LOOP
          INSERT INTO
            synthetic_3d_points
          VALUES (
            id,
            sdo_geometry (
              3001,
              4978,
              sdo_point_type (
                curr_lon,
                curr_lat,
                mod (abs (dbms_random.random), 100)
              ),
              null,
              null
            )
          );
          curr_lon := curr_lon + increment;
          id := id + 1;
        END LOOP;
        COMMIT;
        curr_lat := curr_lat + increment;
      END LOOP;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

DELETE FROM user_sdo_geom_metadata WHERE table_name = 'SYNTHETIC_3D_POINTS';

INSERT INTO user_sdo_geom_metadata VALUES (
  'SYNTHETIC_3D_POINTS',
  'GEOMETRY',
  sdo_dim_array(
    sdo_dim_element('X', -180, 180, 0.001),
    sdo_dim_element('Y', -90, 90, 10),
    sdo_dim_element('Z', -100, 500, 10)),
  4978
);

COMMIT;

DROP INDEX IF EXISTS synthetic_3d_points_sidx FORCE;

CREATE INDEX IF NOT EXISTS synthetic_3d_points_sidx ON synthetic_3d_points (geometry) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2 PARAMETERS ('layer_gtype=POINT sdo_indx_dims=3');

SELECT count(*) FROM synthetic_3d_points;

-- Create an XYZ staging table to create a PC table

DROP TABLE IF EXISTS points_inptab PURGE;

CREATE TABLE IF NOT EXISTS points_inptab  AS
SELECT
  p.geometry.sdo_point.x val_d1,
  p.geometry.sdo_point.y val_d2,
  p.geometry.sdo_point.z val_d3
FROM
  synthetic_3d_points p;

SELECT * FROM points_inptab FETCH FIRST 10 ROWS ONLY;

-- Create a PC table from the XYZ staging table using CREATE_PC_UNIFIED

DROP TABLE IF EXISTS synthetic_3d_pc PURGE;

CREATE TABLE IF NOT EXISTS synthetic_3d_pc (
  id          number,
  point_cloud sdo_pc
) NOLOGGING;

TRUNCATE TABLE synthetic_3d_pc DROP STORAGE;

BEGIN
  sdo_pc_pkg.create_pc_unified (
    pc_type    => 'Flat',
    inp_table  => 'POINTS_INPTAB',
    base_table => 'SYNTHETIC_3D_PC',
    data_table => 'SYNTHETIC_3D_PC_XYZ',
    pc_id      => 1,
    pc_tol     => 0.00000001,
    blk_size   => 10000,
    create_pyramid => 0
  );
END;
/

SELECT * FROM synthetic_3d_pc;

SELECT * FROM synthetic_3d_pc_xyz FETCH FIRST 10 ROWS ONLY;
SELECT count(*) FROM synthetic_3d_pc_xyz;

SELECT * FROM synthetic_3d_pc WHERE id = 1;

-- Clip the PC and store the result in table CLIP_RESULT

DROP TABLE IF EXISTS pc_clip_result PURGE;

SELECT
  min(p.geometry.sdo_point.x) val_d1_min,
  max(p.geometry.sdo_point.x) val_d1_max,
  min(p.geometry.sdo_point.y) val_d2_min,
  max(p.geometry.sdo_point.y) val_d2_max,
  min(p.geometry.sdo_point.z) val_d3_min,
  max(p.geometry.sdo_point.z) val_d3_min
FROM
  synthetic_3d_points p;

BEGIN
  sdo_pc_pkg.clip_pc_into_table(
    pc_table => 'SYNTHETIC_3D_PC',
    pc_column => 'POINT_CLOUD',
    id_column => 'ID',
    id => '1',
    query => mdsys.sdo_geometry(
      2001,
      4326,
      null,
      sdo_elem_info_array(1,1003,3),
      sdo_ordinate_array(12.0004, 52.0003, 12.0006, 52.0007)
    ),
    where_clause => null,
    result_table_name => 'PC_CLIP_RESULT',
    lods => sdo_lods_type(1)
  );
END;
/

-- Show the result

SELECT * FROM pc_clip_result FETCH FIRST 10 ROWS ONLY;
SELECT COUNT(*) FROM pc_clip_result;