#!/bin/bash

## find all DTASelect-filter.txt in the current folder
## e.g.
## ./light/BLAHBLAH/DTASelect-filter.txt
## ./heavy/BLAHBLAH/DTASelect-filter.txt
## rename these DTASelect-filter.txt to DTASelect-filter_BLAHBLAH_light.txt and DTASelect-filter_BLAHBLAH_heavy.txt

for p in $(find ./ -name "DTASelect-filter.txt")
do
    p1=$(echo $p | cut -f2 -d \/)
    p2=$(echo $p | cut -f3 -d \/ | sed 's/^DTASelect_//g')
    echo  rename $p to DTASelect-filter_$p2\_$p1.txt
    cp $p DTASelect-filter_$p2\_$p1.txt
done

exit
