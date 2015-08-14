#!/usr/bin/env python
#
# generate a typsin digest pattern
# read all sequences in one shot and print out only digested fragments
# not good for large sequence database
#
# Chu Wang 04/06/2009

import sys
from sys import argv
from calcMonoMass import *

if len(argv) < 3:
    print 'Usage: %s <sequence_file> <mass> <mod_mass>'%argv[0]
    print 'find sub-sequence that matches mass'
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
adduct_mass = 0.0
if (len(argv)>3):
    adduct_mass = float(argv[3])
    
# maximum number of allowed missed cleavage
mass = float(argv[2]) - adduct_mass

dHplus_mass = 1.0072765
# loop through each sequence
for key in seq_map.keys():

    fwdseq = seq_map[key]

    for i,v in enumerate(fwdseq):
        subseq = fwdseq[i:]
        curseq =''
        for j,w in enumerate(subseq):
            curseq = curseq + w
            curmass = calcMonoMass(curseq)
            dmass = abs((curmass-mass)/mass)
            ##print curseq, curmass, dmass
            if dmass < 0.000015:
                print key, curseq, curmass, dmass
            if curmass > mass:
                break




