--
-- Create table to contains point clouds
--

-- Flat table
DROP TABLE IF EXISTS lidar_points CASCADE CONSTRAINTS PURGE;

CREATE TABLE IF NOT EXISTS lidar_points (
  x                     NUMBER,        -- X
  y                     NUMBER,        -- Y
  z                     NUMBER,        -- Z
  intensity             NUMBER,        -- i => Intensity
  return_number         NUMBER,        -- r => Return Number
  number_of_returns     NUMBER,        -- n => Number of Returns
  edge_of_flight_line   NUMBER,        -- e => Flightline Edge
  scan_direction_flag   NUMBER,        -- d => Scan Direction Flag
  classification        NUMBER,        -- c => Classification
  scan_angle_rank       NUMBER,        -- a => Scan Angle Rank
  r                     NUMBER,        -- R => Color red (2 bytes [0-65536])
  g                     NUMBER,        -- G => Color green (2 bytes [0-65536])
  b                     NUMBER,        -- B => Color blue (2 bytes [0-65536])
  tile_id               NUMBER,        -- tile identifier
  sourcefile            VARCHAR2(200)  -- File source
)
NOLOGGING;

SELECT COUNT(*) FROM lidar_points;

-- SDO_PC table
DROP TABLE IF EXISTS lidar_scenes_blk_01 CASCADE CONSTRAINTS PURGE;
DROP TABLE IF EXISTS lidar_scenes CASCADE CONSTRAINTS PURGE;

CREATE TABLE IF NOT EXISTS lidar_scenes (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  pc SDO_PC,
  description VARCHAR2(2000)
)
NOLOGGING;

CREATE TABLE IF NOT EXISTS lidar_points_blk_01 OF SDO_PC_BLK (
  PRIMARY KEY (
    OBJ_ID,
    BLK_ID
  )
)
LOB (POINTS) STORE AS SECUREFILE (NOCACHE NOLOGGING);
