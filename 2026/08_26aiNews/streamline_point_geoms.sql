/***********************************************************
 * Solution for question during the AskTOM session:
 *
 * "Can points be stored in SDO_ELEM_INFO and SDO_ORDINATES
 * converted into points stored as SDO_POINT_TYPE?"
 *
 * Date: 2026-08-26
 * Author: Karin Patenge
 ***********************************************************/
--
-- Set up test data
--
CREATE TABLE airports_test AS
SELECT
  id,
  name,
  SDO_GEOMETRY(
    2001,
    4326,
    NULL,
    SDO_ELEM_INFO_ARRAY(1,1,1),
    SDO_ORDINATE_ARRAY(longitude_deg, latitude_deg)
  ) AS pt_geom
FROM
  airports;

SELECT
  p.id,
  p.name,
  p.pt_geom,
  v.id AS vertex_no,
  v.x AS lon,
  v.y AS lat
FROM
  airports_test p,
  TABLE(
    sdo_util.getvertices(p.pt_geom)
  ) v;

--
-- Create a function that stores points SDO_POINT_TYPE instead of SD_ELEM_INFO_ARRAY & SDO_ORDINATES_ARRAY
--
CREATE OR REPLACE FUNCTION convert_ordinates_point(
  p_geometry IN MDSYS.SDO_GEOMETRY
) RETURN MDSYS.SDO_GEOMETRY
IS
  l_longitude    NUMBER;
  l_latitude     NUMBER;
  l_vertex_count PLS_INTEGER := 0;
BEGIN
  IF p_geometry IS NULL THEN
    RETURN NULL;
  END IF;

  IF p_geometry.sdo_gtype <> 2001 THEN
    RAISE_APPLICATION_ERROR(
      -20001,
      'Expected a 2D point geometry (SDO_GTYPE = 2001).'
    );
  END IF;

  FOR v IN (
    SELECT x, y
    FROM TABLE(SDO_UTIL.GETVERTICES(p_geometry))
  ) LOOP
    l_vertex_count := l_vertex_count + 1;

    IF l_vertex_count > 1 THEN
      RAISE_APPLICATION_ERROR(
        -20002,
        'Expected exactly one vertex for the point geometry.'
      );
    END IF;

    l_longitude := v.x;
    l_latitude  := v.y;
  END LOOP;

  IF l_vertex_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'The geometry has no vertex.');
  END IF;

  RETURN MDSYS.SDO_GEOMETRY(
    2001,
    p_geometry.sdo_srid,
    MDSYS.SDO_POINT_TYPE(l_longitude, l_latitude, NULL),
    NULL,
    NULL
  );
END convert_ordinates_point;
/

SELECT
  id,
  name,
  convert_ordinates_point(pt_geom) AS pt_geom
FROM
  airports_test;

--
-- Add a new column to test the function
--
ALTER TABLE airports_test
ADD (optimized_pt_geom SDO_GEOMETRY);

--
-- Apply the function
--
UPDATE
  airports_test
SET
  optimized_pt_geom = convert_ordinates_point(pt_geom);

COMMIT;

--
-- Check the result
--
SELECT
  id,
  name,
  pt_geom,
  optimized_pt_geom
FROM
  airports_test;

--
-- Test passed
--

--
-- Performance-optimized version using that avoids calling a PL/SQL function for each point
--
MERGE INTO airports_test t
USING (
  SELECT
    a.ROWID AS rid,
    a.pt_geom.sdo_srid AS srid,
    v.x AS longitude,
    v.y AS latitude
  FROM
    airports_test a,
    TABLE(SDO_UTIL.GETVERTICES(a.pt_geom)) v
  WHERE
    a.pt_geom.sdo_gtype = 2001
    AND a.pt_geom.sdo_point IS NULL
    AND v.id = 1
) s
ON (t.ROWID = s.rid)
WHEN MATCHED THEN
  UPDATE SET t.pt_geom =
    MDSYS.SDO_GEOMETRY(
      2001,
      s.srid,
      MDSYS.SDO_POINT_TYPE(s.longitude, s.latitude, NULL),
      NULL,
      NULL
    );

COMMIT;

--
-- Check the result
--
SELECT
  id, name, pt_geom
FROM
  airports_test a;

--
-- Test passed
--

--
-- Notes:
-- For a very large table:
-- - Prefer the MERGE or an equivalent UPDATE over calling the PL/SQL function for each point geometry.
-- - Run in batches by primary-key ranges if undo/redo capacity is limited.
-- - If the geometry column has a spatial index, rebuild the index after the migration. It may be faster than maintaining it throughout the MERGE.
-- - For a full-table migration with a controlled cutover window, creating a replacement table with the same SELECT source can be faster than in-place DML, but requires recreating constraints, grants, indexes, and metadata.
--