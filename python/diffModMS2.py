#!/usr/bin/env python
#
# add given diff mod value to S and Z lines in the current MS2 file
# #
# Chu Wang 10/14/2010

import sys
from sys import argv

if len(argv) != 3:
    print 'Usage: %s <ms2 file> <diff mod value>'%argv[0]
    print 'modify ms2 file according to diff mod value'
    sys.exit(-1)

dHplus_mass = 1.0072765
# read in each seqeuence in the fasta file
ms2file=argv[1]
diffmod=float(argv[2])
print "H \tComments \tDiffmod_ms2 by Chu Wang %.5f"%(diffmod)
Iline=''
SlineToWrite = 0
for line in open(argv[1]):
#    line=line.strip()
    if line[0]=='S':
        Sline=line.split()
        SlineToWrite = 1
    elif line[0] == 'I':
        Iline=Iline+line
    elif line[0] == 'Z':
        Zline=line.split()
        charge=int(Zline[1])
        MassH=float(Zline[2])
        ms1=float(Sline[3])
        if MassH > diffmod:
            MassH = MassH-diffmod
            ms1 = (MassH+(charge-1)*dHplus_mass)/charge
        if SlineToWrite == 1:
            print "%s \t%s \t%s \t%.5f\n"%(Sline[0],Sline[1],Sline[2],ms1),
            print Iline,
        print "%s \t%s \t%.5f\n"%(Zline[0],Zline[1],MassH),
        Iline=''
        SlineToWrite=0
    else:
        print line,


