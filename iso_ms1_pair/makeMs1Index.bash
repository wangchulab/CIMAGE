#!/bin/bash

if [ $# -lt 1 ]; then
    echo Usage: $0 mzXML
    exit -1
fi

cat $1 | grep msLevel | awk -F\" 'BEGIN{c1=0;c2=0}{c1=c1+1; if($2=="1"){c2=c2+1; print c2,c1}}'

