#!/usr/bin/env python
#
# generate a typsin digest pattern
# read one sequence at a time and produce its digested fragments with protein names and starting positions
# suitable for large sequence databases
#
# Chu Wang 04/07/2009

import sys
from sys import argv

if len(argv) != 3:
    print 'Usage: %s <sequence_file> <allowed_miss_cleavage>'%argv[0]
    print 'generate a list of trypsin digested peptides with protein name and start position number'
    sys.exit(-1)

amc = int(argv[2])

# function to digest a sequece, return a list of (start, stop)
def tryp_digest( sequence, amc):
    seq = sequence.upper()
    l = len(seq)
    start = 0
    new_start = 0
    frags=[]
    while start < l:
        missed = 0
        for i in range(start, l):
            if i == l-1 :
                frags.append((start,i+1))
                if missed==0:
                    new_start = l
                break
            if (seq[i]=='R' or seq[i]=='K'):
                if seq[i+1] != 'P':
                    frags.append( (start,i+1) )
                    missed = missed + 1
                    if missed == 1:
                        new_start = i+1
                    if ( missed > amc):
                        break
        start = new_start

    return frags

# read in each seqeuence in the fasta file
seq_name = 'seq_name'
seq_line=''
seq_count = 0
for line in open(argv[1]):
    line = line.rstrip()
    if line[0]=='>':
        seq_count = seq_count + 1
        if len(seq_line) != 0:
            frags = tryp_digest( seq_line, amc )
            for f in frags:
                print seq_name, f[0], seq_line[f[0]:f[1]]
        # find the name of next read sequence
        stop = line.find('|')
        if stop == -1:
            stop = len(line)
        seq_name = line[1:stop]
        if ( len(seq_name) == 0 ):
            seq_name = 'sequence'+str(seq_count)
        seq_line = ''
    else:
        seq_line = seq_line + line
# last sequence
frags = tryp_digest( seq_line, amc )
for f in frags:
    print seq_name, f[0], seq_line[f[0]:f[1]]
