#!/bin/bash

for p in $(cat mzXML.list );
do
    echo $p;
    ./compareToDTASelect.bash $p.ms1_ion.txt $p\_doublet_peaks/$p\_doublet.table.txt
done

