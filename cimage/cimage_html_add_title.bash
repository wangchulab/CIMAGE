#!/bin/bash

if [ $# -lt 2 ]; then
    echo Usage: $0 combined.html title
    exit -1
fi


file=$1
title=$2

cat $file | sed 's/<TITLE>\w*<\/TITLE>//g' | sed "s/<HEAD>/<HEAD><TITLE>$title<\/TITLE>/g" > $file.tmp
mv $file.tmp $file
