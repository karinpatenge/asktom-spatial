#!/bin/bash
cd "$(dirname "$0")"

LAS_FILES=~/data/pc
ls -lh $LAS_FILES

TILE_ID=1

echo Converting LAS/LAZ files to TXT in $LAS_FILES

find $LAS_FILES -name *.laz | while read file
do
  echo reading information from file $file
  lasinfo64 $file
  text=${file/%.laz/.txt}
  base=${file##*/}
  echo Converting file $base to $text ...
  echo ... las2txt64 -i "$file" -o $text -parse xyzirnedcaRGB -sep comma
  time las2txt64 -i "$file" -o $text -parse xyzirnedcaRGB -sep comma -verbose
  awk -F',' -v OFS=',' -v col1=$TILE_ID -v col2=$base '{print $0, col1, col2}' $text > temp && mv temp $text
  echo show header of converted file
  head -n5 $text
  ((TILE_ID++))
done


ls -lh $LAS_FILES
read -p "Hit return to continue... "


############################################################################
#  Column description  Corresponding parse character
#  x                   x coordinate
#  y                   y coordinate
#  z                   z coordinate
#  X                   X (unscaled raw X value)
#  Y                   Y (unscaled raw Y value)
#  Z                   Z (unscaled raw Z value)
#  gps_time            t (gps time)
#  intensity           i
#  scan_angle          a
#  point_source_id     p
#  classification      c
#  user_data           u
#  return_number       r
#  number_of_returns   n
#  edge_of_flight_line e
#  scan_direction_flag d
#  withheld_flag       h
#  keypoint_flag       k
#  synthetic_flag      g
#  skip                s (skip this column without warning)
#  overlap_flag        o
#  scanner_channel     l
#  R                   R (RGB red)   (2 bytes): UInt16 — range [0, 65535]
#  G                   G (RGB green) (2 bytes): UInt16 — range [0, 65535]
#  B                   B (RGB blue)  (2 bytes): UInt16 — range [0, 65535]
#  HSV_H               (HSV) HSV color model hue [0..360]
#  HSV_S                                     saturation [0..100]
#  HSV_V                                     value [0..100]
#  HSV_h               (hsv) HSV color model hue [0..1]
#  HSV_s                                     saturation [0..1]
#  HSV_v                                     value [0..1]
#  HSL_H               (HSL) HSL color model hue [0..360]
#  HSL_S                                     saturation [0..100]
#  HSL_L                                     luminance [0..100]
#  HSL_h               (hsl) HSL color model hue [0..1]
#  HSL_s                                     saturation [0..1]
#  HSL_l                                     luminance [0..1]
############################################################################

############################################################################
# Convert 2 byte colors to 1 byte:
# RGB(8bit) = RGB(2byte)/65535*255
############################################################################