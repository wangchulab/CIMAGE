#!/bin/bash

if [ $# -lt 1 ]; then
    echo Usage: $0 cimage.params [no_png] set_1 set_2 ...
    exit -1
fi
param=$1
shift;
if [ ! -f "$param" ];
then
    echo cannot find cimage.param file : $param
    exit -1
fi
no_png=$1
if [ "$no_png" == "no_png" ]; then
    shift;
fi

mzxml=$@

ndta=$(\ls *.csv | wc -l)
if [ "$ndta" -eq 0 ];
then
    echo No mascot csv files found and please double check your working path. Exiting ...
    exit -1
fi

# tagged and fwd
date
echo Parsing mascot csv files
csv=""
for p1 in $(echo $mzxml)
do
    for p2 in $(ls $p1\_*.csv);
    do
	mv $p2 $p2.orig
	cat $p2.orig | awk -F"," '(NF>20){print $0}' > $p2
	csv="$csv $p2"
    done
done

echo Creating input files for xcms
## create ipi number to protein name map
R --vanilla --args $csv <  $CIMAGE_PATH/R/findMs1AcrossSetsFromMascot.R > findMs1AcrossSetsFromMascot.Rout

# filter by my_list.txt
mylist=$(\ls my_list.txt 2> /dev/null | wc -l)

if [ "$mylist" -eq 1 ];
then
    echo User provides a customized list in my_list.txt -- filtering...
    mv my_list.txt my_list.txt.original
    tr '\r' '\n' < my_list.txt.original > my_list.txt
    head -1 cross_scan.table > cross_scan.table.tmp
    for ml in $(cat my_list.txt);
    do
	cat cross_scan.table | grep ^$ml >> cross_scan.table.tmp
    done
    mv cross_scan.table cross_scan.table.all
    mv cross_scan.table.tmp cross_scan.table
fi

echo Running xcms to extract chromatographic peaks
echo "R --vanilla --args $param $mzxml < $CIMAGE_PATH/R/findMs1AcrossSetsFromDTASelect.R"
R --vanilla --args $param $mzxml < $CIMAGE_PATH/R/findMs1AcrossSetsFromDTASelect.R > findMs1AcrossSetsFromDTASelect.Rout

# echo Generating graphs
# cd output
# for p in $(\ls *.pdf | sed 's/\.pdf//g')
# do
#     ##ps2pdf $p.ps
#     if [ "$no_png" == "no_png" ]; then
# 	echo no png graphic conversion as requested
#     else
# 	##pdftops $p.pdf $p.ps
# 	mkdir -p PNG
# 	npages=$(cat $p.to_excel.txt | wc -l)
# 	nblock=$(($npages/500))
# 	echo $p.pdf has $npages pages
# 	##if [ $# -lt 3 ]; then
# 	##    rotate="-rotate 90"
# 	##else
# 	##    rotate=""
# 	##fi
# 	nb=0;
# 	while [ $nb -le $nblock ]; do
# 	    ns=$(($nb*500+1))
# 	    ne=$((($nb+1)*500))
# 	    if [ $ne -ge $npages ]; then ne=$(($npages-1)); fi
# 	    mkdir -p PNG/$nb
# 	    echo converting pages $ns-$ne
# 	   ## psselect -q -p$ns-$ne $p.ps ./PNG/$nb/$p.$nb.ps
# 	    pdftk A=$p.pdf cat A$ns-$ne output ./PNG/$nb/$p.$nb.pdf
# 	    cd PNG/$nb
# 	    ##convert  $p.$nb.ps $p.$nb.png
# 	    ##rm -rf $p.$nb.ps
# 	    pdftk $p.$nb.pdf burst
# 	    for pp in $(\ls pg_*.pdf | sed 's/\.pdf//g')
# 	    do
# 		pn=$(echo $pp | cut -f2 -d\_)
# 		pn2=$(echo $pn | awk '{print $1-1}')
# 		convert $pp.pdf $p.$nb\_$pn2.png 2> /dev/null
# 	    done
# 	    rm -rf *.pdf doc_data.txt
# 	    cd ../../
# 	    nb=$(($nb+1))
# 	done
# 	##rm -rf $p.ps
#     fi
#     echo done with $p.pdf
# done
# cd ..

mkdir -p output/TEXT
cp ipi_name.table output/TEXT
cp cross_scan.table output/TEXT
cp all_scan.table output/TEXT

echo Finished
exit 0
