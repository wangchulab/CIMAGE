#!/bin/bash

if [ $# -lt 3 ]; then
    echo Usage: $0 name time [finnigan\|velos]
    echo make MS targeted parent mass list from the doublet peak pair detection
    echo name is the doublet_table.txt and time is the mass spec method time
    exit
fi

table=$1.table.txt
index=$1.pair_index.txt
time=$2
velos=$3

## no ms2 triggered
cat $table | awk '($NF==0){print $0}' | awk '($8>0.7&&$8<1.10&&$10<=0.3){print $0}' | sort -k 11 -nr | head -250 > tmp.table.txt
## all doublet pairs
##cat $table | awk '{print $0}' | awk '($8>0.7&&$8<1.10&&$10<=0.3){print $0}' | sort -k 11 -nr | head -250 > tmp.table.txt

for p in $(cat tmp.table.txt | awk 'BEGIN{OFS=":"}{print $5, $6}')
do
    mz=$(echo $p | cut -f1 -d\:)
    id=$(echo $p | cut -f2 -d\:)
    cat $index | awk -v id=$id '($NF==id){print $4, $6}' > tmp.id.txt
    cat tmp.id.txt | awk -v mz=$mz '{OFS="\t"};{d=($1-mz)/$1*1e6};(d<10 && d>-10) {print $1/1, $2/60-10, $2/60+10}'
done > tmp.inc.txt

cat tmp.inc.txt | awk '{printf "%6.2f\n", $1}' > tmp.mz.txt
cat tmp.inc.txt | awk '{ if ($2<=0) printf "%4.1f\n", 0.0; else printf "%4.1f\n", $2}' > tmp.start.txt
cat tmp.inc.txt | awk -v t=$time '{ if ($3>=t) printf "%4.1f\n",t; else printf "%4.1f\n", $3}' > tmp.end.txt
paste tmp.mz.txt tmp.start.txt tmp.end.txt > tmp.inc.txt

for p in $(sort -n -k 1  tmp.inc.txt | awk '{print $1}' | uniq)
do
    rt1=$(cat tmp.inc.txt | awk -v m=$p '($1==m){print $2}' | sort -n  | head -1)
    rt2=$(cat tmp.inc.txt | awk -v m=$p '($1==m){print $3}' | sort -nr | head -1)
    echo $p $rt1 $rt2
done > tmp.inc2.txt

if [ $velos == "velos" ]; then
    cat tmp.inc2.txt  | awk 'BEGIN{OFS="\t"};{print $1, $2, $3, " ", 35.0}'  >$1.inclusion.txt
else
    cat tmp.inc2.txt  | awk 'BEGIN{OFS="\t"};{print $1, $2, $3}'  >$1.inclusion.txt
fi

rm -rf tmp.id.txt tmp.inc.txt tmp.inc2.txt tmp.mz.txt tmp.start.txt tmp.end.txt tmp.table.txt

echo create $1.inclusion.txt
