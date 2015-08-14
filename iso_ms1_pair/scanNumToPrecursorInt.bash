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
grep "msLevel" $file | awk -F\" '{print $2}' > tmp.$tag.ms_level
paste -d" " tmp.$tag.scan_num tmp.$tag.ms_level | awk 'BEGIN{ms1=0}{if($2==1){ms1=ms1+1}else{print $1, ms1}}' > tmp.$tag.scan_num.ms_level_2
grep "precursorMz" $file | awk -F\> '{print $2}'| awk -F\< '{print $1}' > tmp.$tag.preMz
grep "precursorMz" $file | awk -F\" '{print $2}' > tmp.$tag.preInt

n1=$(cat tmp.$tag.scan_num.ms_level_2 | wc -l)
n2=$(cat tmp.$tag.preMz | wc -l)
n3=$(cat tmp.$tag.preInt | wc -l)

if [ $n1 -ne $n2 -o $n1 -ne $n3 ]; then
    echo bad format $n1 $n2 $3
    exit -1;
fi
paste tmp.$tag.scan_num.ms_level_2 tmp.$tag.preMz tmp.$tag.preInt > tmp.$tag.scan.mz.int

for p in $numbers
do
    grep "^$p " tmp.$tag.scan.mz.int
done

rm -rf tmp.$tag.*