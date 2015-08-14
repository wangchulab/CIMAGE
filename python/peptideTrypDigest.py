#!/usr/bin/env python
#
# generate a typsin digest pattern
# read all sequences in one shot and print out only digested fragments
# not good for large sequence database
#
# Chu Wang 04/06/2009

import sys
from sys import argv

if len(argv) != 3:
    print 'Usage: %s <sequence_file> <allowed_miss_cleavage>'%argv[0]
    print 'generate a list of trypsin digested peptides'
    sys.exit(-1)

# read in each seqeuence in the fasta file
seq_line=''
seq_name='seq_name'
seq_count = 0
seq_map = {}
for line in open(argv[1]):
    line = line.rstrip()
    if line[0]=='>':
        if ( seq_name != 'seq_name' ):
            seq_map[ seq_name ] = seq_line
            seq_count = seq_count + 1
            seq_line =''
        seq_name = line[1:]
        if ( len(seq_name) == 0 ):
            seq_name = 'sequence'+str(seq_count)
        continue
    else:
        seq_line = seq_line + line
# last sequence
seq_map[ seq_name ] = seq_line
seq_count = seq_count + 1

#adduct_mass = 1176.59276
#adduct_mass = 792.36941
#adduct_mass = float(argv[3])

# maximum number of allowed missed cleavage
amc = int(argv[2])

dHplus_mass = 1.0072765
# loop through each sequence
for key in seq_map.keys():

    fwdseq = seq_map[key]

    revseq = fwdseq.upper()[::-1]

    prevC = revseq[0]

    newrevseq=prevC

    for c in revseq[1:]:
        if c == 'R' or c == 'K':
            if prevC != 'P':
                newrevseq = newrevseq + '-'
        newrevseq = newrevseq + c
        prevC = c

    #find fragments without missed cleavages
    rawfrags = newrevseq[::-1].split('-')

    #join fragments as if there were missed cleavage
    allfrags = []
    nrawfrags = len(rawfrags)
    for start in range(nrawfrags):
        for stop in [ x+start+1 for x in range(amc+1) ]:
            if ( stop > nrawfrags):
                continue
            allfrags.append( "".join(rawfrags[start:stop]) )

    #print 'sequence M+H'
    for frag in allfrags:
        print frag



