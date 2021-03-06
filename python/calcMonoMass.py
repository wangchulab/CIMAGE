def calcMonoMass( pepseq ):

    weightmap = {
        'G' :  57.0214636,
        'A' :  71.0371136,
        'S' :  87.0320282,
        'P' :  97.0527636,
        'V' :  99.0684136,
        'T' : 101.0476782,
        #'C' : 103.0091854,
        'C' : 160.0216454, #103.0091854+57.01246,
        'L' : 113.0840636,
        'I' : 113.0840636,
        'X' : 113.0840636,
        'N' : 114.0429272,
        'O' : 114.0793126,
        'B' : 114.5349350,
        'D' : 115.0269428,
        'Q' : 128.0585772,
        'K' : 128.0949626,
        'Z' : 128.5505850,
        'E' : 129.0425928,
        'M' : 131.0404854,
        'H' : 137.0589116,
        'F' : 147.0684136,
        'R' : 156.1011106,
        'Y' : 163.0633282,
        'W' : 186.0793126,
        }

    dHplus = 1.0072765
    dH = 1.0078250
    dOH = 15.9949146 + dH

    mass = 0.0
    for c in pepseq:
        if c in weightmap:
            mass = mass + weightmap[c]
        else:
            print "unrecognized sequence", c
            assert 0
    mass = mass + dH + dOH
    return mass
