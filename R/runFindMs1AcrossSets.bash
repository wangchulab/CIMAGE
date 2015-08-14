#!/bin/bash

if [ $# -lt 3 ]; then
    echo Usage: $0 input_spreadsheet.txt set_1 set_2 ...
    exit -1
fi

infile=$1 #(echo $1 | sed 's/\.txt$//g')
shift
mzxml=$@

cat $infile | grep -v "Description" | awk 'BEGIN{FS="\t"}{print $3}' > $infile.peptide_tagged
cat $infile | grep -v "Description" | awk 'BEGIN{FS="\t"}{print $3}' | sed 's/\*//g' | cut -f2 -d \.  > $infile.peptide

# tagged and fwd
for p1 in $mzxml
do
    for p2 in $(ls DTASelect-filter_$p1\_*.txt);
    do
	/home/chuwang/svnrepos/python/tagDTASelect.py $p2 > $p2.tagged;
	cat $p2.tagged | grep "^IPI" | sed 's/\ \*//g' > $p2.tagged.fwd;
    done
done

scanfiles=""
# pull out scan number
for f in $mzxml
do
    for p in $(cat $infile.peptide_tagged )
    do
	pp=$(cat DTASelect-filter_$f\_*.fwd | awk -v frag=$p '(frag==$NF){print $1, $2, ";"}' );
	echo $p $pp;
    done  > $infile.DTASelect-filter_$f.match
    echo $f > $infile.$f.scan
    cat $infile.DTASelect-filter_$f.match  | awk '{if (NF==1) print "none";else print $3}' >> $infile.$f.scan
    scanfiles="$scanfiles $infile.$f.scan"
done

# mass
echo "mass" > $infile.peptide_mass
for p in $(cat $infile.peptide);
do
    /home/chuwang/svnrepos/python/peptideCalcMass.py $p mono;
done >> $infile.peptide_mass

echo "peptide" > $infile.peptide_seq
cat $infile.peptide >> $infile.peptide_seq

paste $infile.peptide_seq $infile.peptide_mass $scanfiles > $infile.seq_mass_scan

R --vanilla --args $infile $infile.seq_mass_scan < /home/chuwang/svnrepos/R/findMs1AcrossSets.R > $infile.findMs1AcrossSets.Rout

mkdir -p $infile\_output/PNG
cd $infile\_output
for p in $(\ls *.ps | sed 's/\.ps//g')
do
    convert $p.ps $p.png
    mv $p*.png ./PNG/
    ps2pdf $p.ps
done
cd ..

mkdir -p $infile\_output/TEXT
mv $infile.* $infile\_output/TEXT
cp $infile $infile\_output
