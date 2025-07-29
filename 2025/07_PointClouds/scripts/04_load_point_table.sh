#!/bin/bash
cd "$(dirname "$0")"

# Change the following to match your environment:
DB_SERVICE=kpadw23ai_high
DB_USER=spatialworkshop
DB_PASS=<pwd>

TXT_FILES=../../data/pc

echo Loading text files from $TXT_FILES

# The following works for all file names (including those with spaces)
find $TXT_FILES -name *.txt | while read file
do
  echo Loading $file
  sqlldr $DB_USER/$DB_PASS@$DB_SERVICE \
    control=04a_load_point_table.ctl \
    data=$file \
    direct=yes \
    rows=100000
done

# 80 mio points loaded in ~3 mins

read -p "Hit return to continue... "

