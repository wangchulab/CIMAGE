#!/usr/bin/env python
#
# filter cimage output and keep only entries that exist in a reference list

import sys
from sys import argv

if len(argv) != 3:
    print 'Usage: %s <reference_list> <cimage_output_list>'%argv[0]
    print 'extract a subset of protein/peptide entries from cimage_output_list as defined in reference_list'
    sys.exit(-1)

#tags = open(argv[1]).read().split('\n')
#if tags[-1] == '':
#    tags = tags[:-1]

tags=[]
for line in open(argv[1]):
    line = line.rstrip()
    tags.append(line)

# whether print the current entry
match = True

for line in open(argv[2]):
    line = line.rstrip()
    if line[0]!=' ' and line[0]!='i':
        match = False
        for tag in tags:
            if line.find(tag) >= 1:
                match = True
                ##tags.remove(tag) # keep the first entry
                break

    if match:
        print line


