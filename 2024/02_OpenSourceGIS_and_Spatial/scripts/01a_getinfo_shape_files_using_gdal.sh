#!/bin/bash 

# See https://gdal.org/drivers/vector/oci.html

cd "`dirname "$0"`"
tree ${DATA}
read -p "Hit return to continue... "

SHAPE_FILES="${DATA}/shp"

#export CPL_DEBUG=ON

echo "***********************************************************"
echo Getting info about shape files from $SHAPE_FILES
echo "***********************************************************"

# The following works for all file names (including those with spaces)
find $SHAPE_FILES -name *.shp | while read g
do
  echo "***********************************************************"
  echo "Information about file ${g}"
  echo "***********************************************************"
  ogrinfo -al -so "$g"
done
