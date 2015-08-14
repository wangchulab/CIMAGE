#!/usr/bin/env python
#  calculate peptide mass, either monoisotopic or AA-based avergaed mass

import sys
from sys import argv

if len(argv) < 3:
    print 'Usage: <base_mass> <charge1> <charge2> ...'
    print 'calculate m/z values from base_mass'
    sys.exit()

from peptideParams import *

base_mass = float(argv[1])
for charge in argv[2:]:
    print (base_mass+int(charge)*MonoHplus)/int(charge),
