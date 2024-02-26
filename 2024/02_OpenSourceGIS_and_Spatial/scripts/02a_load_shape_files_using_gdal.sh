#!/bin/bash 

# See https://gdal.org/drivers/vector/oci.html

cd "`dirname "$0"`"

# Change the following to match your environment:
DB_CONNECT=${DB_HOST_NAME}:${DB_PORT}/${DB_SERVICE_NAME}
DB_USER=${DB_USER_NAME}
DB_PASS=${DB_USER_PASSWORD}

SHAPE_FILES="${DATA}/shp"

#export CPL_DEBUG=ON

echo Loading shape files from $SHAPE_FILES

# The following works for all file names (including those with spaces)
find $SHAPE_FILES -name *.shp | while read g
do
  file_name=${g##*/}
  # Strip out extension from file name to form table name
  table_name=${file_name%.*}
  # Replace spaces in table name with underscores
  table_name=${table_name// /_}
  # Make table name upper case
  table_name=${table_name^^}
  echo Loading file: \"$file_name\" into $table_name
  time ogr2ogr -f OCI OCI:$DB_USER/$DB_PASS@$DB_CONNECT: "$g" \
    --config OCI_FID fid\
    -nln $table_name\
    -progress \
    -lco DIM=2 \
    -lco SRID=4326 \
    -lco GEOMETRY_NAME=geom \
    -lco SPATIAL_INDEX=NO \
    -lco DIMINFO_X="-180,180,1" -lco DIMINFO_Y="-90,90,1" \
    -lco OVERWRITE=YES \
    -lco ADD_LAYER_GTYPE=NO \
    -lco PRECISION=NO \
    -lco LAUNDER=YES
done
