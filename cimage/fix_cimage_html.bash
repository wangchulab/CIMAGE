#!/bin/bash

if [ $# -lt 1 ]; then
    echo Usage: $0 fix_cimage_html.bash cimage_output_html
    exit -1
fi

html=$1
fullhtml=$(readlink -f $html)
fullpath=$(dirname $fullhtml | sed 's/\//\\\//g')


nline=$(cat $fullhtml | grep  "Batch Annotation" | wc -l)

if [ "$nline" -eq 0 ]; then
    echo $fullhtml does not have a Batch Annotation path, nothing to fix, exit ...
    exit 0
fi

if [ "$nline" -gt 1 ]; then
    echo $fullhtml has multiple Batch Annotation paths, please fix manually, exit ...
    cat $fullhtml | grep  "Batch Annotation"
    exit 0
fi

oldfile=$(cat $fullhtml | grep "Batch Annotation" | awk -F"dset=" '{print $2}'  | awk -F"\"" '{print $1}')
oldpath=$(dirname $oldfile | sed 's/\//\\\//g')

#if [ "$fullpath" == "$oldpath" ]; then
#    echo $fullhtml has a Batch Annotation path up-to-date, nothing to fix, exit...
#    exit 0
#fi

cat $fullhtml | sed 's/mercury//g' | sed 's/\.scripps\.edu/162\.105\.22\.250/g' | sed -e "s/$oldpath/$fullpath/g" > $fullhtml.save

mv $fullhtml.save $fullhtml

exit 0


