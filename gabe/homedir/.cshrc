#if ( ${?prompt}) then
#	source /opt/intel/fce/9.1.033/bin/ifortvars.csh
#	source /opt/intel/cce/9.1.039/bin/iccvars.csh
#endif

#set path = ( /lustre/people/gabriels /tsri/dmf/bin  /usr/pbs/bin $path . /lustre/people/cociorva/bin )
set path = (/net/shared/omssa/ /net/shared/blast-2.2.20/bin/ /home/gabriels/ $path)
set history = 500
set savehist = 50

