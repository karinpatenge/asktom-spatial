-- Check loaded lidar points
SELECT COUNT(*) FROM lidar_points;

SELECT * FROM lidar_points;

SELECT
  MIN(x) minx,
  MIN(y) miny,
  MIN(z) minz,
  MAX(x) maxx,
  MAX(y) maxy,
  MAX(z) maxz
FROM
  lidar_points;

SELECT
  tile_id,
  COUNT(*)
FROM
  lidar_points
GROUP BY
  tile_id
ORDER BY
  tile_id;

-- Spatial extent of the lidar tiles
SELECT
  tile_id,
  min(x),
  min(y),
  max(x),
  max(y)
FROM
  lidar_points
GROUP BY
  tile_id
ORDER BY
  tile_id;