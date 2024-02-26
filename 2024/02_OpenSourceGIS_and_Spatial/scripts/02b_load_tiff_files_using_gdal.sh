#!/bin/bash -x
cd "$(dirname "$0")"

# Change the following to match your environment:
DB_CONNECT=${DB_HOST_NAME}:${DB_PORT}/${DB_SERVICE_NAME}
DB_USER=${DB_USER_NAME}
DB_PASS=${DB_USER_PASSWORD}

RASTER_FILES="${DATA}"
TIFF_FILES="${DATA}/tiff"

# Compress to jpeg 2000
# Uses default quality of 25%.

gdalinfo --version

I=1
for G in $( find "$TIFF_FILES" -type f -name "*.tif" ); do
  echo "***********************************************************"
  echo "Loading file $I: ${G##*/}"
  echo "***********************************************************"
  time gdal_translate -of georaster $G geor:$DB_USER/$DB_PASS@$DB_CONNECT,rasters,image -co insert="(image_id, source_file, image, image_description) values ($I, '${G##*/}', sdo_geor.init('rasters_rdt_01'), 'Test')" -co spatialextent=true -co blocking=optimalpadding
  let I=I+1
done
read -p "Hit return to continue... "

# gdalinfo geor:$DB_USER/$DB_PASS@$DB_CONNECT,rasters,image
## Do not execute gdalinfo, since it outputs the complete connection string including username and pwd

