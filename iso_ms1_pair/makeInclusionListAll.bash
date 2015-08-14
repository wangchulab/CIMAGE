#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: $0 name [finnigan\|velos]
    echo make MS targeted parent mass list from the doublet peak pair detection for ALL FIVE MUDPIT
    echo name is the name_0?.mzXML
    exit
fi

name=$1
finnigan=$2

cd $name\_01_doublet_peaks
/home/chuwang/svnrepos/iso_ms1_pair/makeInclusionList.bash $name\_01_doublet 100 $finnigan
cd ..

cd $name\_02_doublet_peaks
/home/chuwang/svnrepos/iso_ms1_pair/makeInclusionList.bash $name\_02_doublet 80 $finnigan
cd ..

cd $name\_03_doublet_peaks
/home/chuwang/svnrepos/iso_ms1_pair/makeInclusionList.bash $name\_03_doublet 120 $finnigan
cd ..

cd $name\_04_doublet_peaks
/home/chuwang/svnrepos/iso_ms1_pair/makeInclusionList.bash $name\_04_doublet 200 $finnigan
cd ..

cd $name\_05_doublet_peaks
/home/chuwang/svnrepos/iso_ms1_pair/makeInclusionList.bash $name\_05_doublet 60 $finnigan
cd ..

