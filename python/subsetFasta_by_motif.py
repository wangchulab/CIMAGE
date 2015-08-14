#!/usr/bin/env python
#
# extract a subset of fasta sequences by tags

import sys
from sys import argv
import re

if len(argv) != 3:
    print 'Usage: %s <sequence_file> <motif>'%argv[0]
    print 'extract a subset of sequeces from sequence_file with sequence motif defined such as LXXLL'
    sys.exit(-1)

motif1 = argv[2].upper()
motif = motif1.replace('X','.')
motif = '[A-Z]*' + motif + '[A-Z]*'
motifrex = re.compile(motif)

# whether print the current entry
match = False
ipiline=''
for line in open(argv[1]):
    line = line.rstrip()
    if line[0]=='>':
        ipiline=line
    else:
        m=motifrex.match(line)
        if m:
            print ipiline
            print line
