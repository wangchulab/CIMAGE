#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: $0 folder1 folder2
    echo folder1 and folder 2 are names of folders containing control and experiment data
    exit -1
fi

folder1=$1;
folder2=$2;

for p in $(\ls -d *)
do
    if [ -d $p ]; then
	cd $p;
	if [ -d $folder1 -a -d $folder2 ]; then
	    echo run xcms for $p with $folder1 and $folder2
	    R --vanilla --args $folder1 $folder2 < /home/chuwang/shared/R/run_xcms.R > run_xcms.Rout 2>&1
	else
	    echo no $folder1 and $folder2 in $p
	fi
	cd ..
    fi
done


