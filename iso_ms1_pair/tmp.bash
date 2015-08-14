#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage $0 DTASelect.ms1_ion.txt ms1_doublet_table.txt
    exit
fi

dta=$1
doublet=$2

for p in $(cat $dta | awk '{print $5}');
do
    grep -v scan $doublet | awk '{d = ($3-'"$p"')/'"$p"'*1e6}; (d>-25&&d<25){ print $0, d}';
done > tmp.txt

cat tmp.txt | sort | uniq > $doublet.match


