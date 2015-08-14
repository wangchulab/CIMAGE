#!/bin/bash

# compare isotopic doublet pairs indentified by my program to that of DTASelect
# a match is defined as 10ppm for mz && same charge states && eluted within 20 ms1 scans.
# output to *.doublet_match file
if [ $# -lt 2 ]; then
    echo Usage $0 DTASelect.ms1_ion.txt ms1_doublet_table.txt
    exit
fi

dta=$1
doublet=$2

for p in $(cat $dta | awk '{printf "%d_%f_%f\n", $3, $4, $9}');
do
    c=$(echo $p | awk -F\_ '{print $1}') # charge
    m=$(echo $p | awk -F\_ '{print $2}') # mass
    t=$(echo $p | awk -F\_ '{print $3}') # precursor scan number in xcms
    pp=$(grep -v scan $doublet | awk '{d = ($3-'"$m"')/'"$m"'*1e6; d=(d>=0?d:-d)}; {d2=($1-'"$t"');d2=(d2>=0?d2:-d2)}; (d<=10&&'"$c"'==$2&&d2<=20){ print $0, d, d2}') ;
    if [ "$pp" == "" ]; then
	pp="none"
    fi
    echo $pp;
done > tmp.txt

paste $dta tmp.txt > $dta.doublet_match

