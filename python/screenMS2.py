#!/usr/bin/env python
#
# screen MS2 with certain ion fragments
# #
# Chu Wang 10/14/2010

import sys
from sys import argv

if len(argv) < 3:
    print 'Usage: %s <ms2 file> <ms2_mz> <mz_cutoff> <intensity_cutoff>'%argv[0]
    print 'screen MS1 precursor ion with certain MS2 fragments'
    sys.exit(-1)

dHplus_mass = 1.0072765
# read in each seqeuence in the fasta file
ms2file=argv[1]
ms2mz=float(argv[2])
if len(argv)>3:
    mzcut=float(argv[3])
else:
    mzcut=0.5

mzmin=ms2mz-mzcut
mzmax=ms2mz+mzcut

if len(argv)>4:
    intcut=float(argv[4])
else:
    intcut=1000

print "# \tComments \tscreen_ms2 by Chu Wang %.5f %.2f %7i"%(ms2mz,mzcut,intcut)
Iline=''
SlineToWrite = 0
for line in open(argv[1]):
    if line[0]=='S':
        Sline=line.split()
    elif line[0] == 'I':
        Iline=line
    elif line[0] == 'Z':
        Zline=line.split()
    elif line[0] =='H':
        Hline=line
    else:
        ms2line=line.split()
        mz=float(ms2line[0])
        intensity=float(ms2line[1])
        if mz>mzmin and mz<mzmax and intensity>intcut:
            print Sline[0],' ',Sline[1],' ',Sline[3],' ', Zline[1], ' ', float(Zline[2])-dHplus_mass, line,



