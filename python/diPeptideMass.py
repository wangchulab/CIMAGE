#!/usr/bin/env python

# calculate peptide mass, either monoisotopic or AA-based avergaed mass
# mono -- absolute monoisotopic mass
# mz -- monoisotopic mass with C13 adjustment
# avg -- use average aa mass

import sys
import os
from sys import argv

from peptideParams import *

weightmap = AA_MonoMassMap
dHplus = MonoHplus
dH = MonoH
dOH = MonoOH

for aa1 in weightmap.keys():
    for aa2 in weightmap.keys():
        for aa3 in weightmap.keys():
            mass = weightmap[aa1] + weightmap[aa2] + weightmap[aa3]
            mass = mass + dH + dOH
            print aa1, aa2, aa3, mass
