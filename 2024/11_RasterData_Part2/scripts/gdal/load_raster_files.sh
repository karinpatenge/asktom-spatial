#! /usr/bin/bash

cd ~/data

gdalinfo  ./tiff/LT50440342011261PAC01.tif
gdalinfo ./tiff/sf1.tif
gdalinfo ./tiff/sf2.tif
gdalinfo ./tiff/sf3.tif
gdalinfo ./tiff/sf4.tif

gdal_translate -of georaster ./tiff/LT50440342011261PAC01.tif georaster:$DB_CONNECTION,landsat_images,georaster \
   -co insert="(GEORID, SOURCE_FILE, GEORASTER) values (1, 'LT50440342011261PAC01.tif', sdo_geor.init('landsat_images_rdt_01'))" \
   -co blockxsize=512 -co blockysize=512 -co interleave=bip \
   -co spatialextent=true -co blocking=optimalpadding -co genpyramid=nn

gdal_translate -of georaster ./tiff/sf1.tif georaster:$DB_CONNECTION,raster_images,georaster -co insert="(GEORID, SOURCE_FILE, GEORASTER) values (1, 'sf1.tif', sdo_geor.init('raster_images_rdt_01'))" -co blockxsize=512 -co blockysize=512 -co blockbsize=3 -co interleave=bip -co spatialextent=true -co blocking=optimalpadding -co genpyramid=nn
gdal_translate -of georaster ./tiff/sf2.tif georaster:$DB_CONNECTION,raster_images,georaster -co insert="(GEORID, SOURCE_FILE, GEORASTER) values (2, 'sf2.tif', sdo_geor.init('raster_images_rdt_01'))" -co blockxsize=512 -co blockysize=512 -co blockbsize=3 -co interleave=bip -co spatialextent=true -co blocking=optimalpadding -co genpyramid=nn
gdal_translate -of georaster ./tiff/sf3.tif georaster:$DB_CONNECTION,raster_images,georaster -co insert="(GEORID, SOURCE_FILE, GEORASTER) values (3, 'sf3.tif', sdo_geor.init('raster_images_rdt_01'))" -co blockxsize=512 -co blockysize=512 -co blockbsize=3 -co interleave=bip -co spatialextent=true -co blocking=optimalpadding -co genpyramid=nn
gdal_translate -of georaster ./tiff/sf4.tif georaster:$DB_CONNECTION,raster_images,georaster -co insert="(GEORID, SOURCE_FILE, GEORASTER) values (4, 'sf4.tif', sdo_geor.init('raster_images_rdt_01'))" -co blockxsize=512 -co blockysize=512 -co blockbsize=3 -co interleave=bip -co spatialextent=true -co blocking=optimalpadding -co genpyramid=nn
