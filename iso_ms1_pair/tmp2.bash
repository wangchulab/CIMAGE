#!/bin/bash

for p in $(\ls 231sol_231sol_0*.mzXML | sed 's/\.mzXML//g');
do
    cd $p\_doublet_peaks
    cat $p\_doublet.table.txt | grep -v scan |  awk '($8>=0.9&&$8<=1.05){print $0}' |  awk '($10<=0.1){print $0}' > list_0.9_1.05_0.1.txt
    for pp in $(cat list_0.9_1.05_0.1.txt | awk '{printf("%d_%d\n",$7, $6)}')
    do
	cp $p\_doublet_$pp.png ../tmp_png/;
    done
    cd ..
done