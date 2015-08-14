#!/bin/bash

for p in $(\ls *.pdf | sed 's/\.pdf//g')
do
    ##ps2pdf $p.ps
##    if [ "$no_png" == "no_png" ]; then
	##echo no png graphic conversion as requested
##    else
	##pdftops $p.pdf $p.ps
	mkdir -p PNG
	npages=$(cat $p.to_excel.txt | wc -l)
	nblock=$(($npages/500))
	echo $p.pdf has $npages pages
	##if [ $# -lt 3 ]; then
	##    rotate="-rotate 90"
	##else
	##    rotate=""
	##fi
	nb=5;
	while [ $nb -le $nblock ]; do
	    ns=$(($nb*500+1))
	    ne=$((($nb+1)*500))
	    if [ $ne -ge $npages ]; then ne=$(($npages-1)); fi
	    mkdir -p PNG/$nb
	    echo converting pages $ns-$ne
	   ## psselect -q -p$ns-$ne $p.ps ./PNG/$nb/$p.$nb.ps
	    pdftk A=$p.pdf cat A$ns-$ne output ./PNG/$nb/$p.$nb.pdf
	    cd PNG/$nb
	    ##convert  $p.$nb.ps $p.$nb.png
	    ##rm -rf $p.$nb.ps
	    pdftk $p.$nb.pdf burst
	    for pp in $(\ls pg_*.pdf | sed 's/\.pdf//g')
	    do
		pn=$(echo $pp | cut -f2 -d\_)
		pn2=$(echo $pn | awk '{print $1-1}')
		convert $pp.pdf $p.$nb\_$pn2.png 2> /dev/null
	    done
	    rm -rf *.pdf doc_data.txt
	    cd ../../
	    nb=$(($nb+1))
	done
	##rm -rf $p.ps
##    fi
    echo done with $p.pdf
done
