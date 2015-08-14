#!/bin/bash

# take a mzXML file and create a two-column table with scan_number versus parentMZ value(from filterLine) of each ms2 scan.
# assume MS/MS format

if [ $# -lt 1 ]; then
    echo Usage: $0 mzXML
    exit -1
fi

tag=$(basename $0)

file=$1

grep "scan num" $file | awk -F\" '{print $2}' > tmp.$tag.scan_num
grep "filterLine" $file | awk -F\@ '{print $1}' | awk '{print $NF}' > tmp.$tag.pmz
echo "scanNum parentMz" > $1.scanNum_parentMz
paste -d" " tmp.$tag.scan_num tmp.$tag.pmz | grep -v "]" >> $1.scanNum_parentMz
rm -rf tmp.$tag.*
