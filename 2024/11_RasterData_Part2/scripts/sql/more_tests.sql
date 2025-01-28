-- connect system/Oracle123
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\d2500_geo84.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be032_020.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be032_021.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be032_022.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be033_020.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be033_021.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\be033_022.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\s3_03_07.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\s3_03_08.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\s3_04_07.tif', 'read' );
call dbms_java.grant_permission('PUBLIC','SYS:java.io.FilePermission','D:\data\Raster\s3_04_08.tif', 'read' );


-- connect test/test
drop table georaster_table purge;
create table georaster_table
    (georid     number primary key, 
     type       varchar2(32), 
     georaster  mdsys.sdo_georaster);
     
drop table st_rdt_1 purge;
drop table st_rdt_2 purge;
drop table st_rdt_3 purge;
drop table st_rdt_4 purge;

create table st_rdt_1 of mdsys.sdo_raster 
  (primary key (rasterId, pyramidLevel, bandBlockNumber,
                rowBlockNumber, columnBlockNumber))
  lob(rasterblock) store as (nocache nologging);

create table st_rdt_2 of mdsys.sdo_raster
  (primary key (rasterId, pyramidLevel, bandBlockNumber,
                rowBlockNumber, columnBlockNumber))
  lob(rasterblock) store as (nocache nologging);

create table st_rdt_3 of mdsys.sdo_raster
  (primary key (rasterId, pyramidLevel, bandBlockNumber,
                rowBlockNumber, columnBlockNumber));

create table st_rdt_4 of mdsys.sdo_raster
  (primary key (rasterId, pyramidLevel, bandBlockNumber,
                rowBlockNumber, columnBlockNumber))
  nologging
  lob(rasterblock) store as (nocache nologging pctversion 0);

commit;


declare 
  geor MDSYS.SDO_GEORASTER;
begin
  -- initialize empty georaster objects to which the external images
  -- are to be imported
  delete from georaster_table where georid = 1;
  insert into georaster_table 
    values( 1, 'TIFF', mdsys.sdo_geor.init('ST_RDT_1', 1) );

  --
  -- import the first TIFF image
  --
  select georaster into geor 
    from georaster_table where georid = 1 for update;
  mdsys.sdo_geor.importFrom(geor, '', 'TIFF', 'file',
    'D:\data\Raster\d2500_geo84.tif');
  update georaster_table set georaster = geor where georid = 1;
  commit;
end;
/
show errors;
/



declare 
  geor MDSYS.SDO_GEORASTER;
begin
  -- initialize empty georaster objects to which the external images
  -- are to be imported
  delete from georaster_table where georid = 100;
  insert into georaster_table 
    values( 100, 'TIFF', mdsys.sdo_geor.init('ST_RDT_1') );

  --
  -- import the first TIFF image
  --
  select georaster into geor 
    from georaster_table where georid = 100 for update;
  mdsys.sdo_geor.importFrom(geor, '', 'TIFF', 'file',
    'D:\data\Raster\be032_020.tif');
  update georaster_table set georaster = geor where georid = 100;
  commit;
end;
/
show errors;

select georid, georaster
  from georaster_table 
  --where georid = 1
  order by georid;
  
select rdt.rasterid, rdt.rowBLockNumber rowblockNum, 
  rdt.columnBlockNumber colBlockNum, rdt.blockMBR blockmbr,
  dbms_lob.getLength(rdt.rasterBlock) cellLength
  from st_rdt_1 rdt, georaster_table grt
  where rdt.rasterid = grt.georaster.rasterid
  order by rdt.rasterid, rdt.rowblocknumber asc;
  
delete from georaster_table where georid = 3;
commit;

-------------------------------------------------------------------
-- create a 2-D blank GeoRaster object
-- 
-- Blank GeoRaster object means all its cells have the same value
-------------------------------------------------------------------

insert into georaster_table values (
  3,
  'BLANK', 
  sdo_geor.createBlank(20001, 
                       MDSYS.SDO_NUMBER_ARRAY(0,0),
                       MDSYS.SDO_NUMBER_ARRAY(1024,1024), 
                       122,
                       'ST_RDT_1',
                       3) );
  
DECLARE
   geor          MDSYS.SDO_GEORASTER;
   rid           NUMBER := 0;
   raster        MDSYS.SDO_RASTER;
   geom          MDSYS.SDO_GEOMETRY;
   col           NUMBER;
   row           NUMBER;
   colTileOrig   NUMBER;
   rowTileOrig   NUMBER;
   rowTileNum    NUMBER := 1;
   colTileNum    NUMBER := 1;
   i             NUMBER;
   j             NUMBER;
   m             NUMBER;
   n             NUMBER;
   amt           NUMBER;
   pos           NUMBER;
   val           NUMBER(1,0);
   val2          NUMBER(1,0);
   val3          NUMBER(1,0);
   blockSize     NUMBER;
   cellBuf       RAW(32767);
   cellBuf1      RAW(10000);
   cellBuf2      RAW(10000);
   cellBuf3      RAW(10000);
   cellBlock     BLOB;
   cellBlockID   NUMBER;
   cnt           NUMBER;
   stmt          varchar2(1000);
BEGIN
   
   -- assume the georaster object is 512 x 512
   -- blocked into 8*8 tiles of size 64 x 64 
   -- 3 bands or layers and cell depth is 8 bit unsigned

   dbms_output.enable(1000000);

   col := 512;
   row := 512;
   colTileOrig := 0;
   rowTileOrig := 0;
   blockSize := 64;

   --select count(*) into cnt from georaster_table a
   --  where a.georid = 4;
   --if cnt > 0 then
    -- select a.georaster.rasterid into rid 
      -- from georaster_table a where a.georid = 4;
     --delete from st_rdt_1 a where a.rasterID = rid;
   delete from georaster_table where georid = 4;
   --END IF;

   INSERT INTO GEORASTER_TABLE VALUES(
     4, 
     'TRUECOLOR',
     MDSYS.SDO_GEOR.init('ST_RDT_1', 4)
   );

   -- populate spatial extent and metadata 
   select a.georaster into geor from georaster_table a
     where a.georid = 4 for update;

   rid := geor.rasterID;
   dbms_output.put_line('rasterID = '||rid);
   
   geor.rasterType := 21001;
   geor.spatialExtent := 
     MDSYS.SDO_GEOMETRY(2003, NULL, NULL,
       MDSYS.SDO_ELEM_INFO_ARRAY(1,1003,3), 
       MDSYS.SDO_ORDINATE_ARRAY(rowTileOrig, colTileOrig,
                                row-1, col-1));
   geor.metadata := 
XMLTYPE('<georasterMetadata xmlns="http://xmlns.oracle.com/spatial/georaster">
	<objectInfo>
		<rasterType>21001</rasterType>
		<ID>IMAGE_12732</ID>
		<majorVersion>1</majorVersion>
		<minorVersion>12</minorVersion>
		<isBlank>false</isBlank>
		<defaultRed>1</defaultRed>
		<defaultGreen>2</defaultGreen>
		<defaultBlue>3</defaultBlue>
	</objectInfo>
	<rasterInfo>
		<cellRepresentation>UNDEFINED</cellRepresentation>
		<cellDepth>8BIT_U</cellDepth>
		<totalDimensions>3</totalDimensions>
		<dimensionSize type="COLUMN">
			<size>512</size>
		</dimensionSize>
		<dimensionSize type="ROW">
			<size>512</size>
		</dimensionSize>
		<dimensionSize type="BAND">
			<size>3</size>
		</dimensionSize>
		<ULTCoordinate>
			<row>0</row>
			<column>0</column>
			<band>0</band>
		</ULTCoordinate>
		<blocking>
			<type>REGULAR</type>
			<totalRowBlocks>8</totalRowBlocks>
			<totalColumnBlocks>8</totalColumnBlocks>
			<totalBandBlocks>1</totalBandBlocks>
                        <rowBlockSize>64</rowBlockSize>
                        <columnBlockSize>64</columnBlockSize>
                        <bandBlockSize>3</bandBlockSize>
		</blocking>
		<interleaving>BSQ</interleaving>
		<pyramid>
			<type>NONE</type>
			<maxLevel>0</maxLevel>
		</pyramid>
                <compression>
                        <type>NONE</type>
                </compression>
	</rasterInfo>
	<spatialReferenceInfo>
		<isReferenced>true</isReferenced>
		<isRectified>true</isRectified>
		<description>georeferenced landsat TM image</description>
		<SRID>82394</SRID>
		<spatialResolution dimensionType="X">
			<resolution>30.0</resolution>
		</spatialResolution>
		<spatialResolution dimensionType="Y">
			<resolution>30.0</resolution>
		</spatialResolution>
		<spatialTolerance>0.01</spatialTolerance>
		<modelCoordinateLocation>UPPERLEFT</modelCoordinateLocation>
		<modelType>FunctionalFitting</modelType>
		<polynomialModel rowOff="0" columnOff="0" xOff="0" yOff="0" zOff="0" rowScale="1" columnScale="1" xScale="1" yScale="1" zScale="1">
			<pPolynomial nVars="2" order="1" nCoefficients="3">
				<polynomialCoefficients>33772.93015929653 0 -0.03333333333333333</polynomialCoefficients>
			</pPolynomial>
			<qPolynomial nVars="0" order="0" nCoefficients="1">
				<polynomialCoefficients>1</polynomialCoefficients>
			</qPolynomial>
			<rPolynomial nVars="2" order="1" nCoefficients="3">
				<polynomialCoefficients>-606.1258322236894 0.03333333333333333 0</polynomialCoefficients>
			</rPolynomial>
			<sPolynomial nVars="0" order="0" nCoefficients="1">
				<polynomialCoefficients>1</polynomialCoefficients>
			</sPolynomial>
		</polynomialModel>
	</spatialReferenceInfo>
	<temporalReferenceInfo>
		<isReferenced>false</isReferenced>
	</temporalReferenceInfo>
	<bandReferenceInfo>
		<isReferenced>false</isReferenced>
		<description>3 band TM imagery</description>
		<radiometricResolutionDescription>8-bit </radiometricResolutionDescription>
		<spectralUnit>MILLIMETER</spectralUnit>
		<spectralTolerance>0.0</spectralTolerance>
		<minSpectralResolution dimensionType="S">
			<resolution>0.094</resolution>
		</minSpectralResolution>
		<spectralExtent>
			<min>0.43</min>
			<max>0.75</max>
		</spectralExtent>
	</bandReferenceInfo>
	<layerInfo>
                <layerDimension>BAND</layerDimension>
                <subLayer>
                        <layerNumber>1</layerNumber>
                        <layerDimensionOrdinate>0</layerDimensionOrdinate>
                        <layerID>TM2</layerID>
                        <scalingFunction>
                                <a0>0</a0>
                                <a1>20</a1>
                                <b0>1</b0>
                                <b1>0</b1>
                        </scalingFunction>
                        <statisticDataset>
                                <samplingFactor>1</samplingFactor>
                                <MIN>48</MIN>
                                <MAX>57</MAX>
                                <MEAN>53</MEAN>
                                <MEDIAN>53</MEDIAN>
                                <MODEVALUE>48</MODEVALUE>
                                <STD>4</STD>
                        </statisticDataset>
                </subLayer>
                <subLayer>
                        <layerNumber>2</layerNumber>
                        <layerDimensionOrdinate>1</layerDimensionOrdinate>
                        <layerID>TM3</layerID>
                        <scalingFunction>
                                <a0>0</a0>
                                <a1>10</a1>
                                <b0>1</b0>
                                <b1>0</b1>
                        </scalingFunction>
                </subLayer>
                <subLayer>
                        <layerNumber>3</layerNumber>
                        <layerDimensionOrdinate>2</layerDimensionOrdinate>
                        <layerID>TM4</layerID>
                        <scalingFunction>
                                <a0>0</a0>
                                <a1>15</a1>
                                <b0>1</b0>
                                <b1>0</b1>
                        </scalingFunction>
                </subLayer>
	</layerInfo>
	<sourceInfo>Landsat TM image</sourceInfo>
</georasterMetadata>');

   update georaster_table a set a.georaster = geor where a.georid = 4;

   rowTileNum := row/blockSize; -- assume exact division
   colTileNum := col/blockSize;
   val := 0;

   dbms_output.enable(1000000);
   dbms_output.put_line('col number = '||col);
   dbms_output.put_line('row number = '||row);
   dbms_output.put_line('block size = '||blockSize);
   dbms_output.put_line('colTileNum = '||colTileNum);
   dbms_output.put_line('rowTileNum = '||rowTileNum);


   FOR i IN 0..(rowTileNum-1) LOOP
     FOR j IN 0..(colTileNum-1) LOOP
       -- create the block MBR
       geom := MDSYS.SDO_GEOMETRY(2003, NULL, NULL,
                  MDSYS.SDO_ELEM_INFO_ARRAY(1,1003,3), 
                  MDSYS.SDO_ORDINATE_ARRAY(rowTileOrig, colTileOrig,
                        rowTileOrig+blockSize-1, colTileOrig+blockSize-1)); 
       
       cellBlockID := i*1000 + j; 
       dbms_output.put_line('Processing Block: '||cellBlockID);

       -- create the raster block object
       raster := MDSYS.SDO_RASTER(rid, 0, 0, i, j, geom, EMPTY_BLOB());

       -- insert it into the table
       INSERT INTO ST_RDT_1 VALUES (raster);
     
       select b.rasterblock into cellBlock from ST_RDT_1 b
             where b.rasterID = rid and 
                   b.pyramidlevel = 0 and
                   b.bandblocknumber = 0 and
                   b.rowblocknumber = i and
                   b.columnblocknumber = j
             for update;


       -- populate the raster blobs with some random data
       -- here they range from 48 ~ 57

       IF val > 9 THEN
          val := 0;
       END IF;

       amt := blockSize * blockSize;
       cellBuf1 := utl_raw.cast_to_raw(RPAD(to_char(val), amt, to_char(val)));
       if val > 7 THEN
         val2 := val - 1;
         val3 := val - 2;
       ELSE
         val2 := val + 1;
         val3 := val + 2;
       END IF;
       cellBuf2 := utl_raw.cast_to_raw(RPAD(to_char(val2), amt, to_char(val2)));
       cellBuf3 := utl_raw.cast_to_raw(RPAD(to_char(val3), amt, to_char(val3)));
       cellBuf  := utl_raw.concat(cellBuf1, cellBuf2, cellBuf3);
       DBMS_LOB.OPEN(cellBlock, DBMS_LOB.LOB_READWRITE);
       pos := 1;
       amt := amt * 3;
       dbms_output.put_line(' --- populating cells');
       DBMS_LOB.write(cellblock, amt, pos, cellBuf);
       DBMS_LOB.CLOSE(cellBlock);

       colTileOrig := colTileOrig + blockSize;
       val := val + 1;
     END LOOP;
     colTileOrig := 0;
     rowTileOrig := rowTileOrig + blockSize;
     val := 0;
   END LOOP;
   
END;
/
show errors

COMMIT;


select t.georid,
       mdsys.sdo_geor.validategeoraster(t.georaster) isvalid
  from georaster_table t order by georid;  

select t.georid,
       mdsys.sdo_geor.schemavalidate(t.georaster) isvalid
  from georaster_table t;

select t.georid,
       mdsys.sdo_geor.validateBlockMBR(t.georaster) isvalid
  from georaster_table t order by georid;  
  
-- Query georaster
-- display the whole metadata document as XML document
--column meta format a100 heading "The Metadata of the GeoRaster object"
--select a.georaster.metadata meta
--  from georaster_table a where georid = 4;


-- query the version of the georaster object
select georid, sdo_geor.getVersion(georaster) "Version"
  from georaster_table where georid = 4;

select georid, sdo_geor.getVersion(georaster) "Version"
  from georaster_table;


-- query the ID of the georaster object
select georid, 
       sdo_geor.getID(georaster) ID 
  from georaster_table where georid = 4;

select georid, 
       sdo_geor.getID(georaster) ID 
  from georaster_table;

-- query if the georaster object is blank
-- print the cell value if it is blank
select georid,
       sdo_geor.isBlank(georaster) "isBlank",
       sdo_geor.getBlankCellValue(georaster) "blankCellValue"
  from georaster_table
  order by georid;


-- query the default color layers of a true color georaster object
select georid, 
       sdo_geor.getDefaultColorLayer(georaster) defaultColorLayers
  from georaster_table where georid = 4;
select georid, 
       sdo_geor.getDefaultColorLayer(georaster) defaultColorLayers
  from georaster_table;
  
select georid, 
       sdo_geor.getDefaultRed(georaster) "defaultRedLayer",
       sdo_geor.getDefaultGreen(georaster) "defaultGreenLayer",
       sdo_geor.getDefaultBlue(georaster) "defaultBlueLayer"
  from georaster_table where georid = 4;

select georid, 
       sdo_geor.getDefaultRed(georaster) "defaultRedLayer",
       sdo_geor.getDefaultGreen(georaster) "defaultGreenLayer",
       sdo_geor.getDefaultBlue(georaster) "defaultBlueLayer"
  from georaster_table;

-- query the total number of spatial and band dimensions
-- and their sizes which tell the size of the GeoRaster object
select georid, 
       sdo_geor.getSpatialDimNumber(georaster) "totalSpatialDimNumber",
       sdo_geor.getSpatialDimSizes(georaster) spatialDimSizes,
       sdo_geor.getBandDimSize(georaster) "bandSize"
  from georaster_table
  order by georid;


-- query cell depth
select georid, 
       sdo_geor.getCellDepth(georaster) "cellDepth"
  from georaster_table
  order by georid;


-- query the Upper-Left-Top point coordinate
-- as (row, col) if one layer or (row, column, band) if multi-layer
select georid, 
       sdo_geor.getULTCoordinate(georaster) "ULTCoordinate"
  from georaster_table
  order by georid;


-- query interleaving type
select georid, 
       sdo_geor.getInterleavingType(georaster) "InterLeavingType"
  from georaster_table
  order by georid;


-- query cell blocking
select georid, 
       sdo_geor.getBlockingType(georaster) "BlockingType",
       sdo_geor.getBlockSize(georaster) BlockSizes
  from georaster_table
  order by georid;


-- query Spatial Reference System information
select georid, 
       sdo_geor.isSpatialReferenced(georaster) "isSpatialReferenced",
       sdo_geor.isRectified(georaster) "isRectified",
       sdo_geor.isOrthoRectified(georaster) "isOrthoRectified"
  from georaster_table
  order by georid;
select georid, 
       sdo_geor.getModelSRID(a.georaster) "ModelSRID",
       sdo_geor.getSpatialResolutions(a.georaster) resolutions
  from georaster_table a
  where sdo_geor.isSpatialReferenced(a.georaster) = 'TRUE'
        and georid = 4;


-- for all layer-related get and set functions,
-- layerNumber = 0 means the object layer
-- for subLayers, layerNumber is from 1 ~ n


-- query total layer number. it equals the total band number
select georid, 
       sdo_geor.getTotalLayerNumber(georaster) "TotalLayerNumber"
  from georaster_table
  order by georid;


-- query layer ID which is typically a user-specified unique string
select georid, 
       sdo_geor.getLayerID(georaster, 1) "layer1",
       sdo_geor.getLayerID(georaster, 2) "layer2",
       sdo_geor.getLayerID(georaster, 3) "layer3"
  from georaster_table
  where georid = 4;


-- query scaling function for a specific layer
select georid, 
       sdo_geor.getScaling(georaster, 1) "scalingFunction"
  from georaster_table;


-- query whether or not the specified layer is (or say, can be 
-- considered as) a grayscale image
select georid, 
       sdo_geor.hasGrayScale(georaster, 1) "hasGrayScale"
  from georaster_table
  order by georid;


-- query whether or not the specified layer is (or say, can be 
-- considered as) a pseudocolor image
select georid, 
       sdo_geor.hasPseudoColor(georaster, 1) "hasPseudoColor"
  from georaster_table
  order by georid;



-------------------------------------------------------------------
-- Query GeoRaster Object Cell (or say, Raster) Data
-- 
-- Blank GeoRaster object means all its cells have the same value
-------------------------------------------------------------------

-- query a single cell value by specifying cell coordinate
-- in cell space and physical band number
select georid, 
       sdo_geor.getCellValue(georaster, 0, 100, 300, 0)
          "Value of Cell(100,300,0)"
  from georaster_table where georid = 4;

select georid, 
       sdo_geor.getCellValue(georaster, 0, 100, 300, 0)
          "Value of Cell(100,300,0)"
  from georaster_table;

-- query a single cell value by specifying cell coordinate
-- in cell space and logical layer number
select georid, 
       sdo_geor.getCellValue(georaster, 0,
         sdo_geometry(2001,null,null, 
                      mdsys.sdo_elem_info_array(1,1,1),
                      mdsys.sdo_ordinate_array(100,300)), 
         1) "Value"
  from georaster_table where georid = 4;

-- Copy georaster objects                    
declare
  gr1 mdsys.sdo_georaster;
  gr2 mdsys.sdo_georaster;
  cnt integer := 0;
begin
  --
  -- copy a blank georaster object
  --

  -- 1. initialize an empty georaster to hold the copy
  delete from georaster_table where georid = 5;
  insert into georaster_table 
    values (5, 'Blank Copy', sdo_geor.init('ST_RDT_1', 5))
    returning georaster into gr2;

  -- 2. the source blank georaster object
  select georaster into gr1
    from georaster_table where georid = 3;

  -- 3. make copy
  sdo_geor.copy(gr1, gr2);

  -- 4. store it into the georaster table
  update georaster_table set georaster = gr2 where georid = 5;


  --
  -- copy a truecolor georaster object
  --

  -- 1. initialize an empty georaster to hold the copy if not exist
  select count(*) into cnt from georaster_table where georid = 6;
  if (cnt = 0) then
   insert into georaster_table 
     values (6, 'Truecolor Reformat', sdo_geor.init('ST_RDT_2', 6));
  end if;
  select georaster into gr2 
    from georaster_table where georid = 6 for update;
 
  -- 2. the source 3-band truecolor georaster object
  select georaster into gr1 from georaster_table where georid = 4;

  -- 3. make copy
  sdo_geor.copy(gr1, gr2);

  -- 4. store it into the georaster table
  update georaster_table set georaster = gr2 where georid = 6;

  commit;
end;
/

-- quick check on the results
-- georid 5 is identical to georid 3
-- georid 6 is identical to georid 5
@validate_georaster.sql
@query_georaster.sql



-------------------------------------------------------------------
-- change the format of a GeoRaster Object
-------------------------------------------------------------------

declare
  gr1 mdsys.sdo_georaster;
  gr2 mdsys.sdo_georaster;
  cnt integer := 0;
begin
  --
  -- changeFormat of a georaster object
  --

  -- 1. the source georaster object
  select georaster into gr1 
    from georaster_table where georid = 6;

  -- 2. make changes
  sdo_geor.changeFormat(gr1, 'blocksize=(128,128,3) interleaving=BIP');

  -- 3. update it in the georaster table
  update georaster_table set georaster = gr1 where georid = 6;

  commit;

  --
  -- changeFormatCopy a georaster object
  --

  -- 1. initialize an empty georaster to hold the copy if not exist
  select count(*) into cnt from georaster_table where georid = 7;
  if (cnt = 0) then
   insert into georaster_table 
     values (7, 'TRUECOLOR', sdo_geor.init('ST_RDT_3', 7));
  end if;
  select georaster into gr2 
    from georaster_table where georid = 7 for update;

  -- 2. the source georaster object
  select georaster into gr1 from georaster_table where georid = 4;

  -- 3. make format changes and copy 
  sdo_geor.changeFormatCopy(gr1, 'blocksize=(128,128,3) interleaving=BIP', gr2);

  -- 4. update it in the georaster table
  update georaster_table set georaster = gr2 where georid = 7;

  commit;
end;
/
commit;


-- Subset georaster
declare
  gr1 mdsys.sdo_georaster;
  gr2 mdsys.sdo_georaster;
  cnt integer := 0;
begin
  --
  -- subset a blank georaster object
  --

  -- 1. initialize an empty georaster to hold the copy
  delete from georaster_table where georid = 8;
  insert into georaster_table
    values (8, 'Blank Subset', sdo_geor.init('ST_RDT_3', 8))
    returning georaster into gr2;

  -- 2. the source blank georaster object
  select georaster into gr1
    from georaster_table where georid = 3 for update;

  -- 3. crop 
  sdo_geor.subset(gr1, 
                  sdo_geometry(2003, NULL, NULL,
                     mdsys.sdo_elem_info_array(1, 1003, 3),
                     mdsys.sdo_ordinate_array(100,256,500,1000)),
                  null, null, gr2);

  -- 4. store it into the georaster table
  update georaster_table set georaster = gr2 where georid = 8;


  --
  -- subset a truecolor georaster object
  --

  -- 1. initialize an empty georaster to hold the subset if not exist
  select count(*) into cnt from georaster_table where georid = 9;
  if (cnt = 0) then
   insert into georaster_table 
     values (9, 'Truecolor Subset', sdo_geor.init('ST_RDT_3', 9));
  end if;
  select georaster into gr2 
    from georaster_table where georid = 9 for update;
 
  -- 2. the source 3-band truecolor georaster object
  select georaster into gr1 from georaster_table where georid = 4;

  -- 3. make crop and subset 2 bands
  sdo_geor.subset(gr1, 
                  sdo_geometry(2003, NULL, NULL,
                    mdsys.sdo_elem_info_array(1, 1003, 3),
                    mdsys.sdo_ordinate_array(100,200,355,455)),
                  '2,1', 'blocksize=(32,32,2)', gr2);

  -- 4. store it into the georaster table
  update georaster_table set georaster = gr2 where georid = 9;

  commit;
end;
/

-- quick check on the results
@query_georaster.sql

select sdo_geor.getCellValue(georaster,0,254,224,1) v1,
       sdo_geor.getCellValue(georaster,0,231,290,1) V2,
       sdo_geor.getCellValue(georaster,0,245,375,1) V3,
       sdo_geor.getCellValue(georaster,0,245,420,1) V4,
       sdo_geor.getCellValue(georaster,0,224,454,1) v5
  from georaster_table where georid=9;
  
declare
  gr mdsys.sdo_georaster;
begin

  -- 1. the source 3-band truecolor georaster object
  select georaster into gr 
    from georaster_table where georid = 6 for update;

  -- 2. generate pyramids
  sdo_geor.generatePyramid(gr, 'resampling=NN');

  -- 3. update the original georaster object
  update georaster_table set georaster = gr where georid = 6;

  commit;
end;
/
  
select pyramidLevel, count(*) from st_rdt_2 group by pyramidLevel;
select unique pyramidLevel, dbms_lob.getlength(rasterblock) 
  from st_rdt_2
  order by pyramidLevel;

select substr(sdo_geor.getPyramidType(georaster),1,10) pyramidType,
       sdo_geor.getPyramidMaxLevel(georaster) maxLevel
  from georaster_table where georid=6;

-- query a single cell value by specifying cell coordinate
-- in cell space and physical band number
select georid, 
       sdo_geor.getCellValue(georaster, 1, 100, 100, 0)
          "Cell value at pyramid level 1",
       sdo_geor.getCellValue(georaster, 2, 100, 100, 0)
          "Cell value at pyramid level 2"
  from georaster_table
  where georid = 6;

declare
  gr mdsys.sdo_georaster;
begin
  -- 1. the source 3-band truecolor georaster object
  select georaster into gr from georaster_table 
    where georid = 6 for update;

  -- 2. generate pyramids
  sdo_geor.deletePyramid(gr);

  -- 3. update the original georaster object
  update georaster_table set georaster = gr where georid = 6;

  commit;
end;
/

-- quick check on the results

select pyramidLevel, count(*) from st_rdt_2 group by pyramidLevel;
select unique pyramidLevel, dbms_lob.getlength(rasterblock) 
  from st_rdt_2
  order by pyramidLevel;

select substr(sdo_geor.getPyramidType(georaster),1,10) pyramidType,
       sdo_geor.getPyramidMaxLevel(georaster) maxLevel
  from georaster_table where georid=6;

-- Compression
select substr(sdo_geor.getCompressionType(georaster),1,15) comptype,
       sdo_geor.calcCompressionRatio(georaster) compRatio 
  from georaster_table;

declare
  gr1 sdo_georaster;
  gr2 sdo_georaster;
begin
  select georaster into gr1 from georaster_table where georid=1;
  insert into georaster_table 
    values (11, 'DEFLATE', sdo_geor.init('ST_RDT_1'))
    returning georaster into gr2;
  sdo_geor.changeFormatCopy(gr1, 'blocksize=(256,128,3) compression=DEFLATE',
                            gr2);
  update georaster_table set georaster=gr2 where georid=11;
  commit;
end;
/
