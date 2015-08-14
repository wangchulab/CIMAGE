#!/usr/bin/env python
#
# take a uniprot database and if the line does not have GN= tag, add from the gene name

import sys
from sys import argv
import re

if len(argv) != 2:
    print 'Usage: %s <sequence_file>'%argv[0]
    print 'add GN= tag to uniprot database if it does not have one'
    sys.exit(-1)

# whether print the current entry
ipiline=''
for line in open(argv[1]):
    line = line.rstrip()
    if line[0]=='>':
        if line.find('GN=') != -1:
            ipiline=line
        else:
            f=line.split(' ')[0]
            f2=line.split('|')[-1]
            name=f2.split('_')[0]
            newname=' GN='+name+' PE='
            ipiline=line.replace(' PE=',newname)
        print ipiline
    else:
        print line
