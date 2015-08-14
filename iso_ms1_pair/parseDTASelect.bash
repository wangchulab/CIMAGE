#!/bin/bash
# from DTASelect output, find, for each identified ms2 spectrum, its corresponding ms1 parent ion's scan
# number, retention time, mz value and intensity.
# save in *.ms1_ion.txt files

if [ $# -lt 1 ]; then
    echo Usage: $0 DTASelect-filter_all_fwd.uniq.txt
    exit -1
fi
tag=$(basename $0)
dta=$1
for p in $(\ls *.mzXML | sed 's/\.mzXML//g')
do
    echo $p
    cat $dta | grep $p > tmp.$tag.ms1_ion.txt
    n=$(cat tmp.$tag.ms1_ion.txt | wc -l)
    if [ $n -gt 0 ]; then
	cat tmp.$tag.ms1_ion.txt |  awk '{print $2}' | cut -f2 -d\. | awk '{printf "%d\n",$1}' > tmp.$tag.scan_num
	./scanNumToRetentionTime.bash $p.mzXML tmp.$tag.scan_num | awk '{print $2}' > tmp.$tag.rt
	./scanNumToPrecursorInt.bash $p.mzXML tmp.$tag.scan_num | awk 'BEGIN{OFS="\t"}{print $2, $3, $4}' > tmp.$tag.mz.int
	paste tmp.$tag.ms1_ion.txt  tmp.$tag.scan_num  tmp.$tag.rt  tmp.$tag.mz.int > $p.ms1_ion.txt
    fi
done

rm -rf tmp.$tag.*
