#!/bin/bash

# take a normal sequest run folder with ms2 and sequest.params file,
# replace the diff mod line with different amino acids,
# and then submit them through cheater script

if [ $# -eq 0 ]; then
    echo submit multiple sequest jobs with diff mods on all 20 or specified amino acids.
    echo Usage: $0 [all] or ["A C D ..."]
    exit -1;
fi

allaa=" A C D E F G H I K L M N P Q R S T V W Y "

if [ $1 == "all" ]; then
    aas=$allaa
else
    aas=$@
fi

if ! grep -q replace_me sequest.params; then
    echo add a line like \"diff_search_options = 291.34224 replace_me\" into sequest.params file
    echo exiting...
    exit -1
fi

## remove any old job files
rm -rf *.job

n=1;
for a in $aas
do
  d="diff_mod_$a"
  mkdir -p $d
  cd $d
  ln -s ../*.ms2 ./
  cat ../sequest.params | sed "s/replace_me/$a/g" > sequest.params
  echo submit $n\th sequest job with diff mod on amino acid $a
  if [ $n -eq 1 ]; then
      cheater
      cp *.job ../
  else
      ln -s ../*.job ./
      for f in $(\ls *.job)
      do
	qsub $f
      done
  fi
  cd ..
  n=$((n+1))
done

exit 0;