SELECT * FROM rasters;

SELECT * FROM rasters_rdt_01
ORDER BY rasterid, bandblocknumber, rowblocknumber, columnblocknumber;

SELECT COUNT(*) FROM rasters_rdt_01;

DECLARE
     gr sdo_georaster;
BEGIN
     FOR rec in (SELECT image_id FROM rasters ORDER BY image_id) LOOP
       SELECT image INTO gr FROM rasters WHERE image_id=rec.image_id FOR UPDATE;
       -- Generate pyramids using bilinear resampling and write them back
       sdo_geor.generatePyramid(gr, 'resampling=bilinear', null, 'parallel=4');

       UPDATE rasters SET image=gr WHERE image_id=rec.image_id;
       COMMIT;
     END LOOP;
  END;
/

SELECT * FROM rasters_rdt_01
ORDER BY rasterid, pyramidlevel, bandblocknumber, rowblocknumber, columnblocknumber;

SELECT COUNT(*) FROM rasters_rdt_01;
