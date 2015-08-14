#!/usr/bin/env python

from sys import argv
import sys

if len(argv) != 3:
    print 'Usage: %s <in_file> <out_file>'%argv[0]
    print 'reverse the foward sequences and append to output'
    sys.exit(-1)

infile=open(argv[1],'r')
outfile=open(argv[2],'w')

revlines=[]
seq=''
for line in infile:
    outfile.write(line)
    line = line.rstrip()
    if line[0] == '>':
        if len(seq) != 0:
            newline = seq[::-1] + '\n'
            revlines.append(newline)
            seq=''
        newline = line[0] + 'Reverse_' + line[1:] +'\n'
        revlines.append(newline)
    else:
        seq = seq + line

if len(seq) != 0:
    newline = seq[::-1] + '\n'
    revlines.append(newline)

infile.close()

for line in revlines:
    outfile.write(line)

outfile.close()

