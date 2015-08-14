#!/bin/bash

if [ $# -lt 5 ]; then
    echo Usage: $0 full_path_fasta mod_mass tryp_status output_folder mzXML_files
    echo tryp_status:
    echo negative -- non-tryptic
    echo zero -- fully tryptic
    echo positive -- fully tryptic with n missed cleavages
    exit
fi

fasta=$1;
shift;
mass=$1;
shift;
tryp=$1;
shift;
output=$1;
shift;
mzXML=$@;

rm -rf $output
mkdir -p $output

for p in $(ls $mzXML | sed 's/\.mzXML//g');
do
    cat $p\_doublet_peaks/$p\_doublet.table.txt | grep -v scan | \
	awk -v tag=$p '($8>=0.7 && $8<=1.10 && $10<=0.3){ printf "%s %s.%d.%d\n", $0, tag, $7, $6 }' >> $output/list_0.7_1.10_0.3.txt

    cat $p\_doublet_peaks/$p\_doublet.table.txt | grep -v scan | \
	awk -v tag=$p '($8>=0.9 && $8<=1.05 && $10<=0.1){ printf "%s %s.%d.%d\n", $0, tag, $7, $6 }' >> $output/list_0.9_1.05_0.1.txt
done

if [ $tryp -lt 0 ]; then
    echo to be done
else
    cd $output
    /home/chuwang/svnrepos/python/peptideTrypDigestRich.py $fasta $tryp > tryp_digest.$tryp.seq
    for seq in $(cat tryp_digest.$tryp.seq | awk '{print $NF}' )
    do
	/home/chuwang/svnrepos/python/peptideCalcMass.py $seq mono | awk -v tag=$mass '{printf "%10.5f %10.5f\n", $1, $1+tag}' >> tryp_digest.$tryp.mass
    done
    paste -d " " tryp_digest.$tryp.seq tryp_digest.$tryp.mass > tryp_digest.$tryp
    for l in list_0.7_1.10_0.3.txt
    do
	for t in $(cat $l | awk '{print $NF}' )
	do
	    line=$(cat $l | awk -v tt=$t '(tt==$NF){print $0}')
	    mono=$(echo $line | awk '{print $3}')
	    cat tryp_digest.$tryp | awk -v mm=$mono '{d=($NF-mm)/$NF*1e6}; { print $0, d}' > tmp.match
	    cat tmp.match | awk -v li="$line" '($NF>-15&&$NF<15){print $0, li}' >> match.txt
	done
	echo "name seqpos sequence peptide.mass expected.mass ppm scan charge mono.mass mono.mz peak.mz peaks.id peaks.count pcor icpt max.residual max.peakIntensity sn n.ms2 tag" > tmp.match
	sort -k 2 -n match.txt >> tmp.match
	mv tmp.match match.$l
	/home/chuwang/svnrepos/iso_ms1_pair/textTableSingleToHtml.pl
    done
    mkdir -p img
    cd img
    for im in $(cat ../match.txt | grep -v sequence | awk '{print $NF}')
    do
	im1=$(echo $im | cut -f1 -d\.)
	im2=$(echo $im | cut -f2 -d\.)
	im3=$(echo $im | cut -f3 -d\.)
	ln -s ../../$im1\_doublet_peaks/$im1\_doublet_$im2\_$im3.png ./$im.png
    done
    cd ..
    cd ..
fi