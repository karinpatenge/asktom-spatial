#!/bin/bash
NUM_FILES=0
TOTAL_POINTS=0
TOTAL_AREA=0

LAS_FILES=~/data/pc
ls -lh $LAS_FILES

echo Filename, X_min, X_max, Y_min, Y_max, Z_min, Z_max, points, area, density

find $LAS_FILES -name *.laz | while read file
do
  NUM_POINTS=`lasinfo64 $file -nc -stdout | grep 'number of points by return' | awk '{print $6}'`
  MIN=`lasinfo64 $file -nc -stdout | grep 'min x y z:'`
  MAX=`lasinfo64 $file -nc -stdout | grep 'max x y z:'`
  MIN_X=`echo $MIN | awk '{print int($5+0.5)}'`
  MIN_Y=`echo $MIN | awk '{print int($6+0.5)}'`
  MIN_Z=`echo $MIN | awk '{print int($7+0.5)}'`
  MAX_X=`echo $MAX | awk '{print int($5+0.5)}'`
  MAX_Y=`echo $MAX | awk '{print int($6+0.5)}'`
  MAX_Z=`echo $MAX | awk '{print int($7+0.5)}'`
  #((AREA=(MAX_X-MIN_X)*(MAX_Y-MIN_Y)))
  ((DENSITY=NUM_POINTS/AREA))
  NAME="$(basename $file)"
  echo $NAME,$MIN_X,$MAX_X,$MIN_Y,$MAX_Y,$MIN_Z,$MAX_Z,$NUM_POINTS,$AREA,$DENSITY
  ((NUM_FILES++))
  ((TOTAL_POINTS+=NUM_POINTS))
  ((TOTAL_AREA+=AREA))
done
