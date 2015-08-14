#!/usr/bin/env python
#
# extract a subset of fasta sequences by tags

import sys
from sys import argv

if len(argv) != 3:
    print 'Usage: %s <sequence_file> <tag_file>'%argv[0]
    print 'extract a subset of sequeces from sequence_file as defined in tag_file'
    sys.exit(-1)

tags = open(argv[2]).read().split('\n')
if tags[-1] == '':
    tags = tags[:-1]

# whether print the current entry
match = False

for line in open(argv[1]):
    line = line.rstrip()
    if line[0]=='>':
        if line.find("Reverse") == 1:
            break
        match = False
        for tag in tags:
            if line.find(tag) > 0:
                match = True
                tags.remove(tag) # keep the first entry
                break

    if match:
        print line


