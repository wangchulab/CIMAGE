#!/bin/bash

## compile a uniqe list of all common matched identified by both DTASelect and my program

for p in $(\ls *.ms1_ion.txt.doublet_match | cut -f1 -d\.);
do
    grep -v none $p.ms1_ion.txt.doublet_match | awk -v tag=$p '{printf "%s.%d\n", tag, $17}' ;
done  | sort | uniq > true_posistive.txt.RT_with_20
