#!/usr/bin/perl

################################################################################
# Show CGI for displaying spectral information and results all in one package. #
# It is designed to get information from either the individual file formats    #
# (.dta and .out) or the new unified file formats (.ms2 and .sqt).  It takes   #
# information from these files and sends the information to the applet version #
# of the DTASelect GUI for viewing.  To tie stuff together it will allow for   #
# manual evaluation of spectra and will call other programs (EvalPeptide and   #
# EvallocusB) that modify the tags (Y -yes, N -no, M -Maybe, U -unevaluated)   #
# in the DTASelect.txt and the .sqt files.                                     #
################################################################################

#################################
# Get information from URL call #
#################################

# It will take three forms of URL calls

# from DTASelect.html:

# display ions form:
# http://squatch.scripps.edu/cgi-bin/displayions_html5?Dta=/wfs/raid/hayes/DKsamples/112500DK1030cont/112500DK1030cont06/112500DK1030cont06.1207.1207.2.dta
# &MassType=0&NumAxis=1&DMass1=0.0&DMass2=0.0&DMass3=16.0&DSite=00000000000000000000&Pep=SIVH%20

# just plain path:
# /wfs/raid/hayes/JaeHong/030102JaeHongnum24/030102JaeHongnum2405/030102JaeHongnum2405.3706.3706.2.dta

@name_value_pairs = split /&/, $ENV{QUERY_STRING};
#foreach my $arg (@ARGV) {
#	$arguments = $arguments . $arg . "&"
#}
#@name_value_pairs = split /&/, $arguments;
my $Dr = "";
my $Da = "";
my $Sd = "";
my $Sq = "";
my $Sc = "";
my $Pep = ""; # allows one to enter a peptide sequence manually to pass to the applet
my $Z = "";
my $fullpath = "";
my @mod_pos = ();
my @mod_cod = ();

foreach $nvp (@name_value_pairs)
	{
	if ($nvp =~ /Dr=(\S+)/) {$Dr = $1}
	if ($nvp =~ /Da=(\S+)/) {$Da = $1}
	if ($nvp =~ /Sd=(\S+)/) {$Sd = $1}
	if ($nvp =~ /Sq=(\S+)/) {$Sq = $1}
	if ($nvp =~ /Sc=(\S+)/) {$Sc = $1}
	if ($nvp =~ /Pep=(\S+)/) {$Pep = $1}
	if ($nvp =~ /Z=(\S+)/) {$Z = $1}
	if ($nvp =~ /M(\d+?)=(\S+)/) {push (@mod_pos, $1); push (@mod_code, $2);}
	if ($nvp =~ /Dta=(\S+)\.dta/)
		{
		$fullpath = $1;
		if ($fullpath =~ /(\/\S+)\/\S+?\/(\S+?)\.\d+?\.(\d+?)\.(\d)/) {$Dr = $1;$Da = $2;$Sc = $3;$Z = $4}
		}
	}

if ($Sd eq ".") {$directory_filebase = "$Da"}
if ($Sd eq "") {$directory_filebase = "$Da/$Da"}
if ($Sd =~ /\w+?/) {$directory_filebase = "$Sd/$Da"}
if ($fullpath eq "") {$fullpath = "$Dr/$directory_filebase.$Sc.*.$Z"}


#need to take a bit to put the modification data back into the peptide
my $SqMod = "";
if (@mod_pos[0] != 0)
	{
	$i = 0;
	my $modnumber = 0;
	$SqMod = $Sq;
	while ($mod_pos[$i])
		{
		$actualpos = $mod_pos[$i] + $modnumber;
		$modsymb = chr($mod_code[$i]);
		if ($SqMod =~ s/(\S{$actualpos})(\S+)/$1$modsymb$2/g)
			{
			#Most instances except when its the last amino acid
			}
		else
			{
			$SqMod =~ s/(\S+)/$1$modsymb/g;
			#Will hopefully add modification to the end
			}
		$modnumber++;
		$i++;
		}
	}
else {$SqMod = $Sq}

my $dtafile = "";
my $outfile = "";
my $ptafile = "";
my $ms2file = "";
my $sqtfile = "";

$dtafile = glob "$fullpath.dta";
$outfile = glob "$fullpath.out";
$ptafile = glob "$fullpath.pta";
$ms2file = glob "$Dr/$Da.ms2";
$sqtfile = glob "$Dr/$Da.sqt";

#parse the dta information
#read by line and put the first value in @masslist
#the second value in @intlist
#$masslist[0] = the parent mass
#$intlist[0] = charge state
my @masslist = ();
my @intlist = ();
if (-e "$dtafile" || -e "$ptafle") #this is the option if a .ms2 file doesn't exist
	{
	$ms2file = ""; #disable look for ms2 file if you have a dta file
	open (DTA, "$dtafile") || open (DTA, "$ptafile");
	while (<DTA>)
		{
		if ($_ =~ /(\S+?)\s(\S+?)\s/)
			{
			push (@masslist, $1);
			push (@intlist, $2);
			}
		}
	close DTA;
	}
	#else  #this is the option to find the spectral info from an .ms2 file
if (-e "$ms2file") {
	open (MS2, "$ms2file") or die "Can't find the file\n";
#	printf "opening MS2 file\n";
	$ms2line = <MS2>;
	@spectrumarray = [];
	$foundspectrum = 0;
	$linecntr = 0;
	$newfileformat = 0;
	$oldfileformat = 0;
	if ($ms2line =~ /^H/) {
		$newfileformat = 1;
	} elsif ($ms2line =~ /^:/) {
		$oldfileformat = 1;
	}
	MS2LOOP: while ($ms2line = <MS2>) {
		if ($newfileformat == 1) {
			if ($ms2line =~ /^S\s+?0+?$Sc\s+?\d+?\s+?\d/ || $ms2line =~ /^S\s+?$Sc\s+?\d+?\s+?\d/ and $foundspectrum == 0) {
                		#printf "found spectrum\n\n";
				$foundspectrum = 1;
				next MS2LOOP;
			}
			if ($foundspectrum != 0) {
                        	#read spectrum info into array called @spectrumarray
                        	if ($ms2line =~ /^S/) {
                                	if ($1 != $Sc and $foundspectrum == 1) {
                                        	last MS2LOOP;
                                	}
                        	}
                        	if ($ms2line !~ /^S/ and $ms2line !~ /^D/ and $ms2line !~ /^I/) {
                                	$spectrumarray[$linecntr] = $ms2line;
                                	$linecntr++;
                                	next MS2LOOP;
                        	}
			}
		}
		if ($oldfileformat == 1) {
			if ($ms2line =~ /:$Sc\.\d+?\.$Z/) {
#				printf "found spectrum\n\n";
                                $foundspectrum = 1;
                                next MS2LOOP;
			}
			if ($foundspectrum != 0) {
                        	#read spectrum info into array called @spectrumarray
                        	if ($ms2line =~ /^:(\d+?)\.\d+?\.\d/ || $ms2line =~ /^S/) {
                                	if ($1 != $Sc and $foundspectrum == 1) {
                                        	last MS2LOOP;
                                	}
                        	}
                        	if ($ms2line !~ /^:/ || $ms2line !~ /^S/ || $ms2line !~ /^D/ || $ms2line !~ /^I/) {
                                	$spectrumarray[$linecntr] = $ms2line;
                                	$linecntr++;
                                	next MS2LOOP;
                        	}

                	}
		}
	}
	close MS2;
#	printf "done with MS2 file\n";
	#parse @spectrumarray for spectrum info
	$i = 0;
	SPECTRUMARRAY: while ($spectrumarray[$i]) {
		if ($spectrumarray[$i] =~ /(^\d+?\.\d+?)\s($Z)\s/) {
			push (@masslist, $1);push (@intlist, $2);
		} # old
                if ($spectrumarray[$i] =~ /^Z\s+?$Z\s+?(\S+)/) {
			push (@masslist, $1);push (@intlist, $Z);
		} # new
                $i++;
                until ($spectrumarray[$i] !~ /^Z/) {	# new
                	if ($spectrumarray[$i] =~ /^Z\s+?$Z\s+?(\S+)/) {
                        	push (@masslist, $1);
                                push (@intlist, $Z);
                        }
                        $i++;
                        if ($i > @spectrumarray + 1) {
				last SPECTRUMARRAY;
			}
                }
                until ($spectrumarray[$i] !~ /:$Sc\.\d+?/) {
			$i = $i + 2;
			if ($i > @spectrumarray + 1) {
				last SPECTRUMARRAY;
			}
		}	 # old
                until ($spectrumarray[$i] =~ /:\d+?\.\d+?\./ || $spectrumarray[$i] =~ /^S/ || $i > @spectrumarray + 1) {
			if ($spectrumarray[$i] =~ /(\S+?\.\S+?)\s(\S+?)\s/) {
                        	push (@masslist, $1);
                                push (@intlist, $2);
                        }
                        $i++;
                }
                last SPECTRUMARRAY;
	}
}
#printf "done parsing MS2 information\n";
#$t = @masslist;
#for ($h=0;$h<$t;$h++) {
#	printf "mass = $masslist[$h]\n";
#}

#parse the out information
#several arrays:
#	@diffmod,	\((\S+?\s[\+-]\S+?)\)\s
#	@staticmod,	(\S+?=\S+?)\s

#	@Rank_Sp,	\s(\S\s\/\s{0,2}\S+?)\s+?
#	@MplusHplus, 	(\S+?)\s+?
#	@deltCn, 	(\S+?)\s+?
#	@XCorr, 	(\S+?)\s+?
#	@Sp, 		(\S+?)\s+?
#	@Ions, 		(\S+?)\s+?
#	@Reference, 	(\S+?)\s+?
#	@peptide	(\S+?)\s+?

####################
# .out file parser #
####################

my @diffmod = ();
my @staticmod = ();

my @Rank_Sp = ();
my @MplusHplus = ();
my @deltCn = ();
my @XCorr = ();
my @Sp = ();
my @Ions = ();
my @Reference = ();
my @peptide = ();

my $AvgForParent = "TRUE";
my $AvgForFrag = "FALSE";

if (-e "$outfile") # if there is a .out

	{
	open (OUT, "$outfile");
	$sqtfile = ""; #kill looking for .sqt file if .out file is present
	while (<OUT>)
		{
		if ($_ =~ m/\((\S+?\s[\+-]\S+?)\)\s/g)
			{
			push (@diffmod, $1);
			while ($_ =~ m/\G\((\S+?\s[\+-]\S+?)\)\s/g) {push @diffmod, $1}
			}

		if ($_ =~ m/(\S+?=\S+?)\s/g)
			{
			push (@staticmod, $1);
			while ($_ =~ m/\G(\S+?=\S+?)\s/g) {push @staticmod, $1}
			}

		if ($_ =~ /.+?amino acids.+?proteins.+?, (\S+?)\s/) {$dbase = $1}
		if ($_ =~ /AVG\/AVG/) {$AvgForParent = "TRUE"; $AvgForFrag = "TRUE";}
		if ($_ =~ /AVG\/MONO/) {$AvgForParent = "TRUE"; $AvgForFrag = "FALSE";}
		if ($_ =~ /MONO\/AVG/) {$AvgForParent = "FALSE"; $AvgForFrag = "TRUE";}
		if ($_ =~ /MONO\/MONO/) {$AvgForParent = "FALSE"; $AvgForFrag = "FALSE";}
		if ($_ =~ /\s(\S\s\/\s{0,2}\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s.+?(\S\.\S+?\.\S)\s+?/)
			{
			push (@Rank_Sp, $1);
			push (@MplusHplus, $2);
			push (@deltCn, $3);
			push (@XCorr, $4);
			push (@Sp, $5);
			push (@Ions, $6);
			push (@Reference, $7);
			push (@peptide, $8);
			}
		}
	close OUT;
	}


####################
# .sqt file parser #
####################

if (-e "$sqtfile") # if there is a .sqt
	{
	open (SQT, "$sqtfile");
	@sqt = <SQT>;
	close SQT;
	$i = 0;
	until ($sqt[$i] =~ /S\s+?\d+?/) #match the first "S" line - since we just want to read the header
		{
		if ($sqt[$i] =~ m/\((\S+?\s[\+-]\S+?)\)\s/g)
			{
		 	if ($1 ne "") {
				push (@diffmod, $1);
				while ($sqt[$i] =~ m/\G\((\S+?\s[\+-]\S+?)\)\s/g) {push @diffmod, $1}
				}
			}
		if ($sqt[$i] =~ m/^H\tDiffMod\s+?(.+)/g)
                        {
			if ($1 ne "") {
				push (@diffmod, $1);
                        	while ($sqt[$i] =~ m/DiffMod\s+?(.+)/g) {push @diffmod, $1}
                        	}
			}
		elsif ($sqt[$i] =~ m/^H\tDynamicMod\s+?(.+)/g)
			{
			if ($1 ne "") {
				push (@diffmod, $1);
				while ($sqt[$i] =~ m/DynamicMod\s+?(.+)/g) {push @diffmod, $1}
				}
			}
		elsif ($sqt[$i] =~ m/(\S+?=\S+?)\s/g)
		        {
			if ($1 ne "") {
				push (@staticmod, $1);
				while ($sqt[$i] =~ m/\G(\S+?=\S+?)\s/g) {push @staticmod, $1}
				}
			}
		if ($sqt[$i] =~ /.+?amino acids.+?proteins.+?, (\S+?)\s/) {$dbase = $1}
                if ($sqt[$i] =~ /AVG\/AVG/) {$AvgForParent = "TRUE"; $AvgForFrag = "TRUE";}
                if ($sqt[$i] =~ /AVG\/MONO/) {$AvgForParent = "TRUE"; $AvgForFrag = "FALSE";}
                if ($sqt[$i] =~ /MONO\/AVG/) {$AvgForParent = "FALSE"; $AvgForFrag = "TRUE";}
                if ($sqt[$i] =~ /MONO\/MONO/) {$AvgForParent = "FALSE"; $AvgForFrag = "FALSE";}
		$i++;
		}

	#slurp up all of the DTA file starting with the appropriate scan number

	my $store = 0;
	$r = 0;
	$lo = 0;
	SQTLOOP: while ($sqt[$i])
		{
		until ($sqt[$i] =~ /S\s+?$Sc\s+?\d+?\s+?$Z/)
                        {
                        #print "looking for scan\n";
                        #if I need to ge something off the "S" line.....
                        $i++;
                        if ($i >= @sqt) {last SQTLOOP}
			}
		#print "storing";
                $i++;
                until ($sqt[$i] =~ /S\s+?\d+?/ || $sqt[$i] eq $sqt[$#sqt])
			{
			#print "getting lines\n";
                        if ($sqt[$i] =~ /M\s+?(\d+?)\s+?(\d+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\S+?)\s+?(\d+?)\s+?(\d+?)\s+?(\S\.\S+?\.\S)\s+?(\S+?)/)
				{
                                $rank_sp = "$1/$2";
                                push (@Rank_Sp, $rank_sp);
                                push (@MplusHplus, $3);
                                push (@deltCn, $4);
                                push (@XCorr, $5);
                                push (@Sp, $6);
                                $ion = "$7/$8";
                                push (@Ions, $ion);
                                push (@peptide, $9);
                                push (@manual, $10);
               			$r++;
				}
			if ($sqt[$i] =~ /^L\s+?(\S+?)\s/)
                                {
				$templocus = $1;
				if ($lo + 1 == $r)
					{
					push (@Reference, $templocus);
					$lo++;
					}
                                }
			$i++;
			}
               last SQTLOOP;
               }


	}


##################
# Output webpage #
##################

print "Content-type: text/html\n\n";

print "<html>";
print "<HEAD>";
print "<TITLE>S $Da $Sc SpecShow</TITLE>";
print "</HEAD>";

print "<html>\n";

##############################################
# Section for troublshooting print statments #
##############################################

#print "<P>$Dr/$Da.ms2</P>";
#print "<P>@mod_pos, @mod_code, $actualpos, $modsymb, $SqMod</P>";
#print "<P>\ndiff  @diffmod\nstatic  @staticmod</P>";
#foreach $sequence (@peptide) {print "<P>Pep=$sequence</P>"}
#print "<P>Sq=$Sq</P>";

##########################
# First line information #
##########################

#print "<body\" ALIGN=\"CENTER\">\n";
print "<table border ALIGN=\"CENTER\">";
print "<TR><TD><B>Mass: <FONT COLOR=\"green\">$masslist[0]</B></TD>";
print "<TD colspan=\"2\"><B>Datfile: <FONT COLOR=\"green\">$Da</B></TD>";
print "<TD colspan=\"2\"><B>Scan number: <FONT COLOR=\"green\">$Sc</B></TD>";
print "<TD><B>Charge: <FONT COLOR=\"green\">$Z</B></TD>";
print "<TD colspan=\"2\"><B>Database: <FONT COLOR=\"green\">$dbase </TD></TR>";


print "<TR><TD colspan=\"8\" ALIGN=\"center\">";
#print "<applet code=\"SpectrumApplet.class\" CODEBASE=\"http://fields.scripps.edu/DTASelect1.9/\" width=970 height=500>\n";
print "<applet code=\"SpectrumApplet.class\" CODEBASE=\"http://137.131.5.161/DTASelect/\" width=970 height=500>\n";
print "<PARAM NAME=\"PreMPlusH\" VALUE=\"$masslist[0]\">\n";
print "<PARAM NAME=\"PreZ\" VALUE=\"$intlist[0]\">\n";

################################################
# Data that will be passed to DTASelect applet #
################################################

#sprintf to make intensity values intergers - thanks to the LTQ

for (@intlist) {
        $_ = sprintf ("%.i", $_);
        if ($_ < 1) {
                $_ = 1;
        }
}

#print mass intensity pairs

$i = 1;
while (defined ($masslist[$i]))
	{
	print "<PARAM NAME=\"MZ$i\" VALUE=\"$masslist[$i]\">\n";
	print "<PARAM NAME=\"Int$i\" VALUE=\"$intlist[$i]\">\n";
	$i++;
	}

#print staticmods

$i = 0;
while (defined ($staticmod[$i]))
	{
	if ($staticmod[$i] =~ /([A-Z])=(\d+?\.\d+)/)
		{
		$smr = $1;
		$smm = $2;
		}
	$num = $i + 1;
	print "<PARAM NAME=\"SMM$num\" VALUE=\"$smm\">\n";
	print "<PARAM NAME=\"SMR$num\" VALUE=\"$smr\">\n";
	$i++;
	}

#print diffmods

$i = 0;
while (defined ($diffmod[$i]))
	{
	if ($diffmod[$i] =~ /[A-Z0-9\=]+?(\S)\s*?([\+-]*?\d+\.*\d*)/ )
		{
		$dms = $1;
		$dmm = $2;
		}
	if ($diffmod[$i] =~ /[A-Z]+(\S)=([\+-]*?\d+\.*\d*)/)
                {
                $dms = $1;
                $dmm = $2;
                }

	$num = $i + 1;
	print "<PARAM NAME=\"DMM$num\" VALUE=\"$dmm\">";
	print "<PARAM NAME=\"DMS$num\" VALUE=\"$dms\">";
	$i++;
	}

#next chunck of "as is" code

print "<PARAM NAME=\"CPepMod\" VALUE=\"0.0\">\n";
print "<PARAM NAME=\"NPepMod\" VALUE=\"0.0\">\n";
print "<PARAM NAME=\"CProtMod\" VALUE=\"0.0\">\n";
print "<PARAM NAME=\"NProtMod\" VALUE=\"0.0\">\n";
print "<PARAM NAME=\"AvgForFrag\" VALUE=\"$AvgForFrag\">\n";
print "<PARAM NAME=\"AvgForParent\" VALUE=\"$AvgForParent\">\n";


#########################################
# need to know which peptide to display #
#########################################

if ($SqMod ne "")
	{
	$i = 0;
	while (defined ($peptide[$i]))
		{
		if ($peptide[$i] =~ /\.(\S+?)\./) {$modpeptide = $1}
		if ($modpeptide =~ /\Q$SqMod\E/)
			{
			$whichpeptide = $i;
			$check = $i + 1;
			last;
			}
		$i++
		}
	}

elsif ($Sq eq "")
	{
	$whichpeptide = 0;
	$check = 1;
	}
else
	{
	$i = 0;
	while (defined ($peptide[$i]))
		{
		$nakedpeptide = $peptide[$i];
		if ($nakedpeptide =~ /\.(\S+?)\./) {$nakedpeptide = $1}
		$nakedSq = $Sq;
		$nakedSq =~ s/\W//g;
		$nakedpeptide =~ s/\W//g;
		if ($nakedpeptide =~ /$nakedSq/)
			{
			$whichpeptide = $i;
			$check = $i + 1;
			last;
			}
		$i++;
		}

	}

if ($Pep ne "") {$peptide[$whichpeptide] = $Pep}

#pass that information on to the applet

print "<PARAM NAME=\"MatchSeq\" VALUE=\"$peptide[$whichpeptide]\">\n";
print "</applet>\n";
print "</TD></TR>";



###########################################
# Section to print Sequest search results #
###########################################

if( $MplusHplus[0] <= 100 ){
	print "<TR><TD><B>Rank/Probability</B></TD>";
}
else{
	print "<TR><TD><B>Rank/Sp</B></TD>";
}

if( $MplusHplus[0] <= 100 ){
	print "<TD><B>Hypergeometric</B></TD>";
}
else{
	print "<TD><B>(M+H)+</B></TD>";
}
if( $MplusHplus[0] <= 100 ){
	print "<TD><B>dErr</B></TD>";
}
else {
	print "<TD><B>deltCn</B></TD>";
}
if( $MplusHplus[0] <= 100 ){
	print "<TD><B>Error function</B></TD>";
}
else {
	print "<TD><B>XCorr</B></TD>";
}

if( $MplusHplus[0] <= 100 ){
	print "<TD><B>Confidence</B></TD>";
}
else{
	print "<TD><B>Sp</B></TD>";
}

print "<TD><B>Ions</B></TD>";
print "<TD><B>Reference</B></TD>";
print "<TD><B>Peptide</B></TD></TR>\n";

$i = 0;
foreach (@Rank_Sp)
        {
	$num = $i + 1;
	if ($num =~ /$check/) # the one to be highlighted
		{
		print "<TD><FONT COLOR=\"red\"><B> $Rank_Sp[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $MplusHplus[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $deltCn[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $XCorr[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $Sp[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $Ions[$i]</B> </TD>";
		print "<TD><FONT COLOR=\"red\"><B> $Reference[$i]</B> </TD>"; $locus_for_EvalocusB = $Reference[$i];
		print "<TD><FONT COLOR=\"red\"><B> $peptide[$i]</B> </TD></TR>\n";
		}
	else # the rest of lines
		{
		print "<TD> $Rank_Sp[$i] </TD>";
		print "<TD> $MplusHplus[$i] </TD>";
		print "<TD> $deltCn[$i] </TD>";
		print "<TD> $XCorr[$i] </TD>";
		print "<TD> $Sp[$i] </TD>";
		if ($peptide[$i] =~ /\.(\S+?)\./)
			{
			$tempcgipeptide = $1;
			$cgipeptide = $tempcgipeptide;
			@cgi_mod_symb = ();
			@cgi_mod_code = ();
			@cgi_mod_pos = ();

			while ($tempcgipeptide  =~ m/(\W)/g)
				{
				push (@cgi_mod_symb, $1);
				$tempcgipeptide =~ s/\Q$cgi_mod_symb[$#$cgi_mod_symb]\E//
				}

			$j = 0;
			while ($cgi_mod_symb[$j])
				{
				$cgi_mod_code[$j] = ord($cgi_mod_symb[$j]);
				$cgi_mod_pos[$j] = index($cgipeptide, $cgi_mod_symb[$j]);

				$cgipeptide =~ s/\Q$cgi_mod_symb[$j]\E//;
				$j++;
				}


			}
		print "<TD><A href=\"show.pl?Dr=$Dr&Da=$Da&Sc=$Sc&Sd=$Sd&Z=$Z&Sq=$cgipeptide";
		$l = 0;
		while ($cgi_mod_code[$l])
			{
			print "&M$cgi_mod_pos[$l]=$cgi_mod_code[$l]";
			$l++;
			}
		print "\"> $Ions[$i]</A> </TD>";
		print "<TD> $Reference[$i] </TD>";
		print "<TD> $peptide[$i] </TD></TR>\n";
		}
	$i++;
	}
print "</table>";


#############################################
# Section for manual evaluation of peptides #
#############################################

# Table for the peptide evaluations

print "<TABLE BORDER ALIGN=\"center\">";
print "<TR>";
print "<TD>unevaluated</TD>";
print "<TD>maybe</TD>";
print "<TD>YES</TD>";
print "<TD>NO</TD>";
print "<TD ALIGN=\"center\">Peptide evaluation</TD></TR>";
#print "<FORM target=\"Win2\" action=\"http://fields.scripps.edu/cgi-bin/Evalpeptide\" method=\"get\">\n";
print "<FORM target=\"Win2\" action=\"http://localhost/cgi-bin/Evalpeptide.pl\" method=\"get\">\n";
# need to send the full path to the DTASelect.txt, which .sqt file, the peptide that needs flagging
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"peptide_ID\" VALUE=\"$Dr&$Da&$Sc&$Z&$SqMod&U\"";
if ($manual[$whichpeptide] eq "" || $manual[$whichpeptide] =~ /U/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"peptide_ID\" VALUE=\"$Dr&$Da&$Sc&$Z&$SqMod&M\"";
if ($manual[$whichpeptide] =~ /M/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"peptide_ID\" VALUE=\"$Dr&$Da&$Sc&$Z&$SqMod&Y\"";
if ($manual[$whichpeptide] =~ /Y/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"peptide_ID\" VALUE=\"$Dr&$Da&$Sc&$Z&$SqMod&N\"";
if ($manual[$whichpeptide] =~ /N/) {print "CHECKED"}
print "></TD>";
print "<TD><INPUT TYPE=\"submit\" NAME=\"submit_peptide\" VALUE=\"Submit Spectrum\"></TD>";
print "</FORM>";
print "</TABLE>";


###################################################################################
# Code borrowed from EvalocusA in order to check the evaluation status of a locus #
###################################################################################

my $completepath = $Dr . "/DTASelect.txt";
open (DTASELECT,"$completepath") or die "Can't open $completepath: $!\n";
my $line;
my $evalflag = "not working";
LOOPONE: while ($line = <DTASELECT>)
	{
	if ($line =~ /^L\t\Q$locus_for_EvalocusB\E\t.+\t([YNUM])$/)
		{
		$evalflag = $1;
		last LOOPONE;
        	}
        }
close (DTASELECT);


###############################
# Table for locus evaluations #
###############################

print "<TABLE BORDER ALIGN=\"center\">";
print "<TR>";
print "<TD>unevaluated</TD>";
print "<TD>maybe</TD>";
print "<TD>YES</TD>";
print "<TD>NO</TD>";
print "<TD ALIGN=\"center\">Locus evaluation</TD></TR>";
#print "<FORM target=\"Win2\" action=\"http://fields.scripps.edu/cgi-bin/EvalocusB\" method=\"get\">\n";
print "<FORM target=\"Win2\" action=\"http://localhost/cgi-bin/EvalocusB.pl\" method=\"get\">\n";
# I need to pass the path where the DTASelect.txt, the locus info, and the new value of the tag (U, M, Y, N)
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"evaluate\" target=\"win2\" VALUE=\"$Dr&$locus_for_EvalocusB&U\"";
if ($evalflag =~ /U/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"evaluate\" target=\"win2\" VALUE=\"$Dr&$locus_for_EvalocusB&M\"";
if ($evalflag =~ /M/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"evaluate\" target=\"win2\" VALUE=\"$Dr&$locus_for_EvalocusB&Y\"";
if ($evalflag =~ /Y/) {print "CHECKED"}
print "></TD>";
print "<TD ALIGN=\"center\"><INPUT TYPE=\"radio\" NAME=\"evaluate\" target=\"win2\" VALUE=\"$Dr&$locus_for_EvalocusB&N\"";
if ($evalflag =~ /N/) {print "CHECKED"}
print "></TD>";
print "<TD><INPUT TYPE=\"submit\" NAME=\"submit_locus\" VALUE=\"Submit Locus\"></TD>";
print "</FORM>";
print "</TABLE>";

# button to update DTASelect.html

print "<TABLE BORDER ALIGN=\"center\">";
#print "<TR><TD> <a target=\"Win2\" HREF=\"http://fields.scripps.edu/cgi-bin/DTAupdate?Dr=$Dr\">Refresh DTASelect.html</a> </TD></TR></TABLE>";
print "<TR><TD> <a target=\"Win2\" HREF=\"http://localhost/cgi-bin/DTAupdate.pl?Dr=$Dr\">Refresh DTASelect.html</a> </TD></TR></TABLE>";

###########################################################
# another little section of print statements for checking #
###########################################################

#print "<P>@masslist, @intlist</P>";
#print "<P>@cgi_mod_symb, @cgi_mod_code, @cgi_mod_pos, $tempcgipeptide, $cgipeptide</P>";


print "</body>\n";
print "</html>\n";

