SET PATH=c:\cygwin\bin;%PATH%
cd c:\Xcalibur\data
rsync -avzr -e ssh --delete --exclude "*.ms2" --exclude "*.ms1" --exclude "*.mzXML" * bfclab@home.scripps.edu:/snfs/cravatt/orbi_finnigan/
cd c:\Documents and Settings\Finnigan\desktop
rsync -avzr -e ssh --delete methods bfclab@home.scripps.edu:/snfs/cravatt/orbi_finnigan/
rsync -avzr -e ssh --delete calibration_records bfclab@home.scripps.edu:/snfs/cravatt/orbi_finnigan/
#pause


