#!/bin/bash

# from my program's output, make a combined table based on two sets of cutoffs
## coefficient between 0.7 and 1.10; intercept < 0.3
## coefficient between 0.9 and 1.05; intercept < 0.1

rm -rf list_0.7_1.10_0.3.txt list_0.9_1.05_0.1.txt
for p in $(\ls *.mzXML | sed 's/\.mzXML//g');
do
    cat $p\_doublet_peaks/$p\_doublet.table.txt | grep -v scan | \
	awk -v tag=$p '($8>=0.7 && $8<=1.10 && $10<=0.3){ printf "%s %s.%d.%d\n", $0, tag, $7, $6 }' >> list_0.7_1.10_0.3.txt

    cat $p\_doublet_peaks/$p\_doublet.table.txt | grep -v scan | \
	awk -v tag=$p '($8>=0.9 && $8<=1.05 && $10<=0.1){ printf "%s %s.%d.%d\n", $0, tag, $7, $6 }' >> list_0.9_1.05_0.1.txt

done
