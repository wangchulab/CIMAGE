#!/bin/bash

# a wrapper script to run findIsoMs1Centroid.R each individual mzXML file to avoid overflowing memory

if [ $# -lt 2 ]; then
    echo Usage: $0 [fast] [no_MS2] [no_peaks_n] pair.mass.delta input_mzXML_files
    exit -1;
fi

fast=""
if [ $1 == "fast" ]; then
    fast=$1
    shift
fi
noMS2=""
if [ $1 == "no_MS2" ]; then
    noMS2=$1
    shift
fi
noPeaksN=""
if [ $1 == "no_peaks_n" ]; then
    noPeaksN=$1
    shift
fi

delta=$1
shift
for p in $(echo $@ | sed 's/\.mzXML$//g')
do
    echo find double peaks with mass delta $delta from $p.mzXML
    /home/chuwang/svnrepos/iso_ms1_pair/makeScanNumToParentMzTable.bash $p.mzXML
    echo R --vanilla --args $p $delta $fast $noMS2 $noPeaksN
    R --vanilla --args $p $delta $fast $noMS2 $noPeaksN < /home/chuwang/svnrepos/R/findIsoMs1Centroid.R > $p.Rout 2> $p.err &
done

exit 0
