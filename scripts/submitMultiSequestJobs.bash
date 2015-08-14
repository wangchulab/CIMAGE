#!/bin/bash

# take a normal sequest run folder with multiple ms2 and multiple sequest.params files,
# and then submit them through cheater script


## remove any old job files
rm -rf *.job

##
n1=$(ls *.ms2 | wc -l);
if [ $n1 -eq 0 ]; then
    echo ERROR! no *.ms2 files found!;
    exit
fi
n2=$(ls *_sequest.params | wc -l);
if [ $n2 -eq 0 ]; then
    echo ERROR! no *_sequest.params files found!;
    exit
fi


n=1;
for ms2 in $(\ls *.ms2 | sed 's/\.ms2$//g')
do
  for sqt in $(\ls *_sequest.params | sed 's/_sequest\.params$//g')
    do
    d="$ms2.$sqt"
    mkdir -p $d
    cd $d
    ln -s ../$ms2.ms2 ./
    ln -s ../$sqt\_sequest.params ./sequest.params
    echo submit $n\th sequest job with $sqt.sequest.params and $ms2.ms2
    if [ $n -eq 1 ]; then
	cheater
	cat $ms2.job | sed "s/$ms2/this_ms2/g" > ../sequest.job
    else
      cat ../sequest.job | sed "s/this_ms2/$ms2/g" > $ms2.job
      qsub $ms2.job
    fi
    cd ..
    n=$((n+1))
  done
done

exit 0;