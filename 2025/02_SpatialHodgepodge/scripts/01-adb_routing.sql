-------------------------
-- AskTOM Spatial Series
-- Session: February 2025
--
-- Author: Karin Patenge
-- Date: Feb 2025
-------------------------

-------------------------------
-- Topic 1: In-Database Routing
-------------------------------

-- Log in as user ADMIN to grant permission
-- for executing functions and procedures in SDO_GCDR
-- that reach out to the Oracle Maps Cloud Service
EXEC SDO_GCDR.ELOC_GRANT_ACCESS('ASKTOMUSER');

-- To revoke the granted permission, execute
-- EXEC SDO_GCDR.ELOC_REVOKE_ACCESS('ASKTOMUSER');

-- Log in as user ASKTOMUSER


/************************************************************************************************************
 * Compute Drive-Time Polygons using SDO_GCDR.ELOC_DRIVE_TIME_POLYGON
 * https://docs.oracle.com/en/database/oracle/oracle-database/23/spatl/sdo_gcdr-eloc_drive_time_polygon.html
 *
 * Computes the drive time polygon around an input location for the specified cost, and
 * returns the geometry of the polygon in SDO_GEOMETRY format.
 ************************************************************************************************************/

SELECT SDO_GCDR.ELOC_DRIVE_TIME_POLYGON(
  'fastest',                             -- route preference (shortest, fastest, or traffic)
  'Alexanderplatz 1, Berlin, 10178',     -- address (single-line address)
  'DE',                                  -- ISO-2 country code
  8,                                     -- Cost - Distance, or time bounds
  'minute',                              -- Cost unit (mile, kilometer, km, meter, hour, minute, or second)
  'auto'                                 -- Vehicle type (auto, or truck)
) polygon
FROM DUAL;

SELECT SDO_GCDR.ELOC_DRIVE_TIME_POLYGON(
  'fastest',                             -- route preference (shortest, fastest, or traffic)
  10.1,                                  -- address (lon)
  50.1,                                  -- address (lat)
  10,                                     -- Cost - "Radius" of the polygon
  'minute',                              -- Cost unit (mile, kilometer, km, meter, hour, minute, or second)
  'auto'                                 -- Vehicle type (auto, or truck)
) polygon
FROM DUAL;

-- Explanation for cost:
--   "Cost" is the drive time or drive distance to use for the area of reachability from the starting point.
--   The output polygon is the area reachable from the start point within specified cost.
--   If parameter route_preference is set to "shortest", then cost is a distance.
--   If parameter route_preference is set to "fastest", then cost is time.
DROP TABLE IF EXISTS feb25_drive_time_polygons PURGE;

TRUNCATE TABLE feb25_drive_time_polygons DROP STORAGE;

CREATE TABLE IF NOT EXISTS feb25_drive_time_polygons (
  id  NUMBER GENERATED ALWAYS AS IDENTITY,
  address VARCHAR2(255),
  country CHAR(2),
  lon NUMBER(13,8),
  lat NUMBER(13,8),
  routing_preference VARCHAR2(100),
  cost_type NUMBER,
  cost_unit VARCHAR2(100),
  vehicle_type VARCHAR2(100),
  drive_time_polygon SDO_GEOMETRY
);

-- Address in Germany
INSERT INTO feb25_drive_time_polygons (
  address,
  country,
  routing_preference,
  cost_type,
  cost_unit,
  vehicle_type
) VALUES (
  'Moorfuhrtweg 9, 22301 Hamburg',
  'DE',
  'fastest',
  20,
  'minute',
  'auto'
);

-- Address in Germany
INSERT INTO feb25_drive_time_polygons (
  address,
  country,
  routing_preference,
  cost_type,
  cost_unit,
  vehicle_type
) VALUES (
  'Bernauer Str. 100, 16515 Oranienburg',
  'DE',
  'shortest',
  15,
  'km',
  'truck'
);

-- Address in Canada (1h)
INSERT INTO feb25_drive_time_polygons (
  lon,
  lat,
  routing_preference,
  cost_type,
  cost_unit,
  vehicle_type
) VALUES (
  -114.103166,
  51.018189,
  'fastest',
  1,
  'hour',
  'auto'
);

-- (2h)
INSERT INTO feb25_drive_time_polygons (
  lon,
  lat,
  routing_preference,
  cost_type,
  cost_unit,
  vehicle_type
) VALUES (
  -114.103166,
  51.018189,
  'fastest',
  2,
  'hour',
  'auto'
);

-- (3h)
INSERT INTO feb25_drive_time_polygons (
  lon,
  lat,
  routing_preference,
  cost_type,
  cost_unit,
  vehicle_type
) VALUES (
  -114.103166,
  51.018189,
  'fastest',
  3,
  'hour',
  'auto'
);


COMMIT;

SELECT * FROM feb25_drive_time_polygons;

-- Compute drive-time polygons
DECLARE
  v_address VARCHAR2(255);
BEGIN
  FOR cur IN (
    SELECT * FROM feb25_drive_time_polygons WHERE drive_time_polygon IS NULL)
  LOOP
    IF cur.address IS NOT NULL THEN
      UPDATE feb25_drive_time_polygons
      SET drive_time_polygon = SDO_GCDR.ELOC_DRIVE_TIME_POLYGON(
        cur.routing_preference,
        cur.address,
        cur.country,
        cur.cost_type,
        cur.cost_unit,
        cur.vehicle_type
      )
      WHERE id = cur.id;
    ELSIF cur.lon IS NOT NULL AND cur.lat IS NOT NULL THEN
      UPDATE feb25_drive_time_polygons
      SET drive_time_polygon = SDO_GCDR.ELOC_DRIVE_TIME_POLYGON(
        cur.routing_preference,
        cur.lon,
        cur.lat,
        cur.cost_type,
        cur.cost_unit,
        cur.vehicle_type
      )
      WHERE id = cur.id;
    ELSE
      DBMS_OUTPUT.PUT_LINE('No update');
    END IF;
    COMMIT;
  END LOOP;
END;
/

-- Check result
SELECT * FROM feb25_drive_time_polygons;

-- Create spatial index
CREATE INDEX feb25_drive_time_polygons_sidx
ON feb25_drive_time_polygons(drive_time_polygon)
INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;


/************************************************************************************************************
 * Compute ISO Polygons using SDO_GCDR.ELOC_ISO_POLYGON
 * https://docs.oracle.com/en/database/oracle/oracle-database/23/spatl/sdo_gcdr-eloc_iso_polygon.html
 *
 * Computes the drive time polygon around an input location for the specified cost, and returns a JSON object
 * that includes the cost, cost unit, and geometry of the polygon in GeoJSON format.
 ************************************************************************************************************/

-- Time-based queries
WITH x AS (
  SELECT SDO_GCDR.ELOC_ISO_POLYGON(
    'time',                           -- determines, if the polygon is time-based or distance-based
    '9 Rue des Écoles, 75005 Paris',  -- address
    'FR',                             -- country
    10,                               -- cost
    'minute',                         -- cost unit
    'auto'                            -- vehicle type
  ) AS t
  FROM DUAL
)
SELECT
  json_value(t, '$.routeResponse.driveTimePolygon.cost') AS cost_type,
  json_value(t, '$.routeResponse.driveTimePolygon.unit') AS cost_unit,
  json_query(t, '$.routeResponse.driveTimePolygon.geometry' RETURNING clob) AS iso_polygon
FROM x;

WITH x AS (
  SELECT SDO_GCDR.ELOC_ISO_POLYGON(
    'time',                        -- determines, if the polygon is time-based or distance-based
    2.307206,                      -- longitude
    48.897210,                     -- latitude
    1,                             -- cost
    'hour',                        -- cost unit
    'truck',                       -- vehicle type
    'true'                         -- print request response
  ) AS t
  FROM DUAL
)
SELECT
  json_value(t, '$.routeResponse.driveTimePolygon.cost') AS cost_type,
  json_value(t, '$.routeResponse.driveTimePolygon.unit') AS cost_unit,
  json_query(t, '$.routeResponse.driveTimePolygon.geometry' RETURNING clob) AS iso_polygon
FROM x;

-- Distance-based queries
WITH x AS (
  SELECT SDO_GCDR.ELOC_ISO_POLYGON(
    'distance',                       -- determines, if the polygon is time-based or distance-based
    '9 Rue des Écoles, 75005 Paris',  -- address
    'FR',                             -- country
    10,                               -- cost
    'kilometer',                      -- cost unit
    'auto'                            -- vehicle type
  ) AS t
  FROM DUAL
)
SELECT
  json_value(t, '$.routeResponse.driveTimePolygon.cost') AS cost_type,
  json_value(t, '$.routeResponse.driveTimePolygon.unit') AS cost_unit,
  json_query(t, '$.routeResponse.driveTimePolygon.geometry' RETURNING clob) AS iso_polygon
FROM x;

WITH x AS (
  SELECT SDO_GCDR.ELOC_ISO_POLYGON(
    'distance',                    -- determines, if the polygon is time-based or distance-based
    2.307206,                      -- longitude
    48.897210,                     -- latitude
    10,                            -- cost
    'km',                          -- cost unit
    'truck',                       -- vehicle type
    'true'                         -- print request response
  ) AS t
  FROM DUAL
)
SELECT
  json_value(t, '$.routeResponse.driveTimePolygon.cost') AS cost_type,
  json_value(t, '$.routeResponse.driveTimePolygon.unit') AS cost_unit,
  json_query(t, '$.routeResponse.driveTimePolygon.geometry' RETURNING clob) AS iso_polygon
FROM x;

/************************************************************************************************************
 * Compute routes using SDO_GCDR.ELOC_ROUTE
 * https://docs.oracle.com/en/database/oracle/oracle-database/23/spatl/sdo_gcdr-eloc_route.html
 *
 * Computes the route between two locations and
 * returns a JSON object that includes the route distance, route time, and geometry of the route in GeoJSON format.
 * The input locations can either be single-line addresses or be specified as lon/lat.
 ************************************************************************************************************/

WITH x AS (
  SELECT SDO_GCDR.ELOC_ROUTE(
    'fastest',                   -- route preference
    'km',                        -- distance unit
    'minute',                    -- time unit
    -71.46439, 42.75875,         -- start location (lon/lat)
    -71.46278, 42.7553,          -- destination location (lon/lat)
    'auto'                       -- vehicle type
  ) AS t
  FROM DUAL
)
SELECT json_value(t, '$.routeResponse.route.time') AS TIME,
       json_value(t, '$.routeResponse.route.distance') AS DIST,
       json_query(t, '$.routeResponse.route.geometry' RETURNING CLOB) AS route
FROM x;

WITH x AS (
  SELECT SDO_GCDR.ELOC_ROUTE(
    'fastest',                                  -- route preference
    'km',                                       -- distance unit
    'minute',                                   -- time unit
    'Bernauer Str. 100, 16515 Oranienburg',     -- start location (single-line address)
    'Alexanderplatz 1, 10178 Berlin',           -- destination location (single-line address)
    'DE',                                       -- country
    'auto'                                      -- vehicle type
  ) AS t
  FROM DUAL
)
SELECT json_value(t, '$.routeResponse.route.time') AS TIME,
       json_value(t, '$.routeResponse.route.distance') AS DIST,
       json_query(t, '$.routeResponse.route.geometry' RETURNING CLOB) AS route
FROM x;


/*******************************************************************************
 * Variations to calculate routes available:
 *   SDO_GCDR.ELOC_ROUTE_DISTANCE: Computes the route distance between 2 locations
 *   SDO_GCDR.ELOC_ROUTE_TIME: Computes the travel time between 2 locations
 *   xxSDO_GCDR.ELOC_ROUTE_GEOM: Returns the route between 2 locations as geometry
 *******************************************************************************/




