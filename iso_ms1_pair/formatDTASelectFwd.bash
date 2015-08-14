#!/bin/bash
# read in a DTAselect.tagged file, extract fwd matches and reformat with certain columns
# see last line

if [ $# -lt 1 ]; then
    echo Usage $0 DTASelect.txt.tagged
    exit
fi
dta=$1

cat $dta | grep ^IPI | grep 231sol_231sol | sed 's/\*//g' | cut -c5- > tmp.txt
cat tmp.txt | awk '{print $1}' > tmp.ipi
cat tmp.txt | awk '{print $2}' > tmp.scan
cat tmp.scan | awk -F\. '{print $NF}' > tmp.charge
cat tmp.txt | awk '{printf "%10.5f\n", $7-1.0072769}' > tmp.mass # light search
#cat tmp.txt | awk '{printf "%10.5f\n", $7-1.0072769-6.01381}' > tmp.mass # heavy search
paste tmp.mass tmp.charge | awk '{printf "%10.5f\n",$1/$2+1.0072769}' > tmp.mz
cat tmp.txt | awk '{print $NF}' | awk -F\. '{print $2}' > tmp.frag

paste tmp.ipi tmp.scan tmp.charge tmp.mass tmp.mz tmp.frag 