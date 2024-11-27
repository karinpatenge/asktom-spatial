-- Clean up
drop table if exists landsat_images purge;
drop table if exists landsat_images_rdt_01 purge;
drop table if exists raster_images purge;
drop table if exists raster purge;

-- Create tables for Landsat and other raster files
create table if not exists landsat_images (
   georid              number primary key,
   source_file         varchar2(80),
   description         varchar2(256),
   georaster           sdo_georaster
);

create table if not exists landsat_images_rdt_01 of sdo_raster (
   primary key (
      rasterid, pyramidlevel, bandblocknumber,
      rowblocknumber, columnblocknumber
   )
)
lob(rasterblock) store as securefile (
   nocache nologging
);

create table if not exists raster_images (
   georid              number primary key,
   source_file         varchar2(80),
   description         varchar2(256),
   georaster           sdo_georaster
);

create table if not exists raster_images_rdt_01 of sdo_raster (
   primary key (
      rasterid, pyramidlevel, bandblocknumber,
      rowblocknumber, columnblocknumber
   )
)
lob(rasterblock) store as securefile (
   nocache nologging
);

-------------------------------------------
-- Load raster file using GDAL
-- See script ../gdal/load_raster_files.sh
------------------------------------------

-- Show loaded raster images
SELECT
  georid,
  georaster
FROM
  landsat_images
ORDER BY
  georid;

SELECT
  georid,
  georaster
FROM
  raster_images
ORDER BY
  georid;

SELECT
  rdt.rasterid,
  rdt.rowblocknumber                  rowblocknum,
  rdt.columnblocknumber               colblocknum,
  rdt.blockmbr                        blockmbr,
  dbms_lob.getlength(rdt.rasterblock) celllength
FROM
  landsat_images_rdt_01 rdt,
  landsat_images        grt
WHERE
  rdt.rasterid = grt.georaster.rasterid
ORDER BY
  rdt.rasterid,
  rdt.rowblocknumber ASC,
  rdt.columnblocknumber ASC;

SELECT
  rdt.rasterid,
  rdt.rowblocknumber                  rowblocknum,
  rdt.columnblocknumber               colblocknum,
  rdt.blockmbr                        blockmbr,
  dbms_lob.getlength(rdt.rasterblock) celllength
FROM
  raster_images_rdt_01 rdt,
  raster_images        grt
WHERE
  rdt.rasterid = grt.georaster.rasterid
ORDER BY
  rdt.rasterid,
  rdt.rowblocknumber ASC,
  rdt.columnblocknumber ASC;

--------------------------
-- Raster Algebra examples
--------------------------

-- Classify SF1 raster image
DECLARE
  gr1 SDO_GEORASTER;
  gr2 SDO_GEORASTER;
BEGIN

  DELETE FROM raster_images
  WHERE
    georid = 11;

  INSERT INTO raster_images (georid, source_file, georaster)
    VALUES (
      11,
      'Classify SF1 raster image',
      SDO_GEOR.INIT('RASTER_IMAGES_RDT_01'))
    RETURNING georaster INTO gr2;

  SELECT
    georaster
  INTO gr1
  FROM
    raster_images
  WHERE
    source_file = 'sf1.tif';

  SELECT
    georaster
  INTO gr2
  FROM
    raster_images
  WHERE
    georid = 11
  FOR UPDATE;

  SDO_GEOR_RA.CLASSIFY(
    inGeoraster => gr1,
    expression => '({0}+{1}+{2}/3)',
    rangeArray => SDO_NUMBER_ARRAY(63,127,191),
    valueArray => SDO_NUMBER_ARRAY(0,1,2,3),
    outGeoraster => gr2,
    storageParam => 'cellDepth=2BIT'
  );

  UPDATE raster_images
  SET
    georaster = gr2
  WHERE
    georid = 11;

  COMMIT;
END;
/

-- Find green cells in SF2 raster image
DECLARE
  gr1 SDO_GEORASTER;
  gr2 SDO_GEORASTER;
BEGIN

  DELETE FROM raster_images
  WHERE
    georid = 12;

  INSERT INTO raster_images (georid, source_file, georaster)
    VALUES (
      12,
      'Select green in SF2 raster image',
      SDO_GEOR.INIT('RASTER_IMAGES_RDT_01'))
    RETURNING georaster INTO gr2;

  SELECT
    georaster
  INTO gr1
  FROM
    raster_images
  WHERE
    source_file = 'sf2.tif';

  SELECT
    georaster
  INTO gr2
  FROM
    raster_images
  WHERE
    georid = 12
  FOR UPDATE;

  SDO_GEOR_RA.FINDCELLS(
    inGeoraster => gr1,
    condition => '{1}>={0}&{1}>={2}',
    storageParam => NULL,
    outGeoraster => gr2,
    bgValues => sdo_number_array (255, 255, 255)
  );

  UPDATE raster_images
  SET
    georaster = gr2
  WHERE
    georid = 12;

  COMMIT;
END;
/

-- Create grayscale image of SF4 raster image
DECLARE
  gr1 SDO_GEORASTER;
  gr2 SDO_GEORASTER;
BEGIN

  DELETE FROM raster_images
  WHERE
    georid = 14;

  INSERT INTO raster_images (georid, source_file, georaster)
    VALUES (
      14,
      'SF2 raster image as grayscale',
      SDO_GEOR.INIT('RASTER_IMAGES_RDT_01'))
    RETURNING georaster INTO gr2;

  SELECT
    georaster
  INTO gr1
  FROM
    raster_images
  WHERE
    source_file = 'sf4.tif';

  SELECT
    georaster
  INTO gr2
  FROM
    raster_images
  WHERE
    georid = 14
  FOR UPDATE;

  SDO_GEOR_RA.RASTERMATHOP(
    inGeoraster => gr1,
    operation => sdo_string2_array('({0}+{1}+{2})/3'),
    storageParam => NULL,
    outGeoraster => gr2
  );

  UPDATE raster_images
  SET
    georaster = gr2
  WHERE
    georid = 14;

  COMMIT;
END;
/

-- Update SF3 raster image. Replace cell values with dominant color.
DECLARE
  gr1 SDO_GEORASTER;
  gr2 SDO_GEORASTER;
BEGIN

  SELECT
    georaster
  INTO gr1
  FROM
    raster_images
  WHERE
    georid = 13;

  SDO_GEOR_RA.RASTERUPDATE(
    georaster => gr1,
    pyramidLevel => NULL,
    conditions => SDO_STRING2_ARRAY (
      '({0}>{1})&({0}>{2})',   -- Red dominates
      '({1}>{0})&({1}>{2})',   -- Green dominates
      '({2}>{0})&({2}>{1})'    -- Blue dominates
    ),
    vals => SDO_STRING2_ARRAYSET (
      SDO_STRING2_ARRAY('255','0','0'),
      SDO_STRING2_ARRAY('0','255','0'),
      SDO_STRING2_ARRAY('0','0','255')
    )
  );

  UPDATE
    raster_images
  SET
    source_file = 'Cell values in SF3 replaced with dominant color'
  WHERE
    georid = 13;

  COMMIT;
END;
/

-- NDVI Computation using Landsat image

DECLARE
  gr1 SDO_GEORASTER;
  gr2 SDO_GEORASTER;
BEGIN

  DELETE FROM landsat_images
  WHERE
    georid = 11;

  INSERT INTO landsat_images (georid, source_file, georaster)
    VALUES (
      11,
      'LANDSAT 5 NDVI, black and white',
      SDO_GEOR.INIT('LANDSAT_IMAGES_RDT_01'))
    RETURNING georaster INTO gr2;

  SELECT
    georaster
  INTO gr1
  FROM
    landsat_images
  WHERE
    georid = 1;

  SELECT
    georaster
  INTO gr2
  FROM
    landsat_images
  WHERE
    georid = 11
  FOR UPDATE;


SDO_GEOR_RA.RASTERMATHOP(
    inGeoraster => gr1,
    condition => SDO_STRING2_ARRAY('({3}-{2})/({3}+{2})'),
    storageParam => 'celldepth=32bit_real',
    outGeoraster => gr2,
    nodata => 'TRUE');

  UPDATE landsat_images
  SET
    georaster = gr2
  WHERE
    georid = 11;

  COMMIT;
END;
/

show errors;

SELECT
  *
FROM
  landsat_images;


-- Alternative call
DECLARE
  geor1 mdsys.sdo_georaster;
  geor2 mdsys.sdo_georaster;
BEGIN
  SELECT
    image
  INTO geor1
  FROM
    landsat_images
  WHERE
    georid = 1;

  SELECT
    image
  INTO geor2
  FROM
    landsat_images
  WHERE
    georid = 11
  FOR UPDATE;

  mdsys.sdo_geor_ra.rastermathop(geor1,
                                 sdo_string2_array('({3}-{2})/({3}+{2})'),
                                 'celldepth=32bit_real',
                                 geor2,
                                 'TRUE');

  sdo_geor.setid(geor2, 'LANDSAT 5 NDVI, black and white');
  UPDATE landsat_images
  SET
    georaster = geor2
  WHERE
    georid = 11;

  COMMIT;
END;
/

show errors;