#!/bin/bash -x
cd "$(dirname "$0")"

RASTER_FILES="${DATA}"
TIFF_FILES="${DATA}/tiff"

# Compress to jpeg 2000
# Uses default quality of 25%.

gdalinfo --version

I=1
for G in $( find "$TIFF_FILES" -type f -name "*.tif" ); do
  echo "***********************************************************"
  echo "Information about file $I: ${G##*/}"
  echo "***********************************************************"
  gdalinfo $G
  let I=I+1
done

