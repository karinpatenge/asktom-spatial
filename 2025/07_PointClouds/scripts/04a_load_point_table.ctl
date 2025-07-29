-- Control file to load point cloud data into a staging table
LOAD DATA
  APPEND
  INTO TABLE lidar_points
  FIELDS TERMINATED BY ',' (
  x,
  y,
  z,
  intensity,
  return_number,
  number_of_returns,
  edge_of_flight_line,
  scan_direction_flag,
  classification,
  scan_angle_rank,
  r,
  g,
  b,
  tile_id,
  sourcefile
)