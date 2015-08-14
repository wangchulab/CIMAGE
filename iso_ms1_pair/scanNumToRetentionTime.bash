#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: $0 mzXML number
    exit -1
fi
tag=$(basename $0)

file=$1
shift
numbers=$@

if [ -s $1 ]; then
    numbers=$(cat $1)
fi


grep "scan num" $file | awk -F\" '{print $2}' > tmp.$tag.scan_num
grep "retentionTime" $file | awk -F\" '{print $2}' | sed 's/PT//g' | sed 's/S//g' > tmp.$tag.rt
paste -d" " tmp.$tag.scan_num tmp.$tag.rt > tmp.$tag.scan_num.rt

for p in $numbers
do
    grep "^$p " tmp.$tag.scan_num.rt | awk '{print $1, $2, $2/60.0}'
done

rm -rf tmp.$tag.*
