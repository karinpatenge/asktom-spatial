/***************************************************************************************************************
 * Working with Point Clouds in the Oracle Database 23ai
 *
 * Demo  : Detect changes in point clouds
 *
 * Author: Karin Patenge, Oracle
 * Date  : August 2025
 ***************************************************************************************************************/

/*
 * Steps:
 *  0. Check and view .las/.laz
 *  1. Convert .las/.laz to .txt
 *  2. Create staging table to upload the .txt files
 *  3. Upload the .txt files into the database
 *  4. Create Point Cloud objects in the database
 *  5. Create difference of the two point clouds
 */

/*
 * Step 0:
 *
 * Data source laz files: https://github.com/PDAL/data/tree/master/liblas
 *
 * Check using LASTOOLS:
 *   lasinfo64 -no_check "Palm Beach Pre Hurricane.laz" -v
 *   lasinfo64 -no_check "Palm Beach Post Hurricane.laz" -v
 *
 * View using LASTOOLS:
 *   lasview
 */


/*
 * Step 1:
 *
 * Convert:
 *   las2txt64 -i "Palm Beach Pre Hurricane.laz" -o PalmBeach_PreHurricane_xyz.csv -parse xyz -sep semicolon
 *   las2txt64 -i "Palm Beach Post Hurricane.laz" -o PalmBeach_PostHurricane_xyz.csv -parse xyz -sep semicolon
 */


/*
 * Step 2:
 *
 * Create table structures and views
 */

-- Clean up first

DROP TABLE IF EXISTS pc_inptab PURGE;
DROP TABLE IF EXISTS lidar_scenes PURGE;
DROP TABLE IF EXISTS lidar_scenes_xyz_pre PURGE;
DROP TABLE IF EXISTS lidar_scenes_xyz_post PURGE;
DROP TABLE IF EXISTS lidar_scenes_diff_pre_post PURGE;

CREATE TABLE IF NOT EXISTS pc_inptab (
  val_d1    number(38,10),           -- x coordinate
  val_d2    number(38,10),           -- y coordinate
  val_d3    number(38,10)            -- z height

) NOLOGGING;

CREATE TABLE IF NOT EXISTS lidar_scenes (
  id          number,
  point_cloud sdo_pc
) NOLOGGING;


/*
 * Step 3:
 *
 * Upload the data using SQLcl
 */

TRUNCATE TABLE pc_inptab DROP STORAGE;

-- SQLcl settings
-- sql /nolog
-- connect <user>/<pwd>@<service>

set load batch_rows 100 batches_per_commit 100
set timing on
set loadformat column_names off
set loadformat delimiter ;
set loadformat delimited

-- Load the first dataset: Palm Beach - Pre Hurricane

LOAD TABLE pc_inptab PalmBeach_PreHurricane_xyz.csv
-- INFO Number of rows processed: 2,580,410
-- Total Elapsed: 00:01:29.424

/*
 * Step 4:
 *
 * Create Point Cloud object for Palm Beach Pre Hurricane
 */

SELECT count(*) FROM pc_inptab;

-- Insert from staging table into LIDAR_SCENES table

TRUNCATE TABLE lidar_scenes DROP STORAGE;

BEGIN
  sdo_pc_pkg.create_pc_unified (
    pc_type    => 'Flat',
    inp_table  => 'PC_INPTAB',
    base_table => 'LIDAR_SCENES',
    data_table => 'LIDAR_SCENES_XYZ_PRE',
    pc_id      => 111,
    pc_tol     => 0.05,
    blk_size   => 10000,
    srid       => null
  );
END;
/

-- Check the results

SELECT * FROM LIDAR_SCENES;
SELECT * FROM lidar_scenes_xyz_pre FETCH FIRST 10 ROWS ONLY;

/*
 * Repeat step 3:
 *
 * Upload the data using SQLcl
 */

TRUNCATE TABLE pc_inptab DROP STORAGE;

-- Load the second dataset: Palm Beach - Post Hurricane

LOAD TABLE lidar_staging_table PalmBeach_PostHurricane.csv
-- INFO Number of rows processed: 1,924,631
-- Total Elapsed: 00:00:44.089

SELECT count(*) FROM pc_inptab;

/*
 * Repeat step 4:
 *
 * Create Point Cloud object for Palm Beach Post Hurricane
 */

BEGIN
  sdo_pc_pkg.create_pc_unified (
    pc_type    => 'Flat',
    inp_table  => 'PC_INPTAB',
    base_table => 'LIDAR_SCENES',
    data_table => 'LIDAR_SCENES_XYZ_POST',
    pc_id      => 222,
    pc_tol     => 0.05,
    blk_size   => 10000,
    srid       => null
  );
END;
/

-- Check results
SELECT * FROM lidar_scenes;
SELECT * FROM lidar_scenes_xyz_post FETCH FIRST 10 ROWS ONLY;


/*
 * Step 5:
 *
 * Create the difference between the two point clouds
 * using SDO_PC_PKG.PC_DIFFERENCE
 */

-- Check first the extents of the x, y, z values in the two data tables attached to the Point Cloud objects in table LIDAR_SCENES.

SELECT round(min(val_d1)) AS min_x, round(min(val_d2)) AS min_y, round(min(val_d3)) AS min_z,round(max(val_d1)) AS max_x, round(max(val_d2)) AS max_y, round(max(val_d3)) AS max_z FROM lidar_scenes_xyz_pre;
SELECT round(min(val_d1)) AS min_x, round(min(val_d2)) AS min_y, round(min(val_d3)) AS min_z,round(max(val_d1)) AS max_x, round(max(val_d2)) AS max_y, round(max(val_d3)) AS max_z FROM lidar_scenes_xyz_post;

-- Make sure the result table for the next step does not exist

DROP TABLE IF EXISTS lidar_scenes_xyz_diff_pre_post PURGE;

-- Determine all points in the first Point Cloud object that have no neighboring points in the second Point Cloud object.ALTER

BEGIN
  sdo_pc_pkg.pc_difference(
    pc_table1           =>  'LIDAR_SCENES',
    pc_column1        =>  'POINT_CLOUD',
    id_column1        =>  'ID',
    id1               =>  '111',
    pc_table2         =>  'LIDAR_SCENES',
    pc_column2        =>  'POINT_CLOUD',
    id_column2        =>  'ID',
    id2               =>  '222',
    result_table_name =>  'LIDAR_SCENES_XYZ_DIFF_PRE_POST',
    tol               =>  1,
    query_geom        =>  sdo_geometry (
      2003,
      null,
      null,
      sdo_elem_info_array(1, 1003, 3),
      sdo_ordinate_array(0, 0, 1000000, 1000000))
  );
END;
/

-- Check the results

SELECT * FROM lidar_scenes_xyz_diff_pre_post FETCH FIRST 10 ROWS ONLY;
SELECT count(*) FROM lidar_scenes_xyz_diff_pre_post;

