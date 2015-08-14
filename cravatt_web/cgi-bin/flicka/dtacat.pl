#!/usr/local/bin/perl

#-------------------------------------
#	DTA Cat,
#	(C)2002 Harvard University
#	
#	W. S. Lane/B. Guaraldi
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 02/11/02 by Ben Guaraldi
# Last Modified: 05/29/02 by Ben Guaraldi
#
# Description: Finds all DTA files in a directory 
# within a certain scan and MH+ tolerance and 
# concatenates them.

################################################
# find and read in standard include file
{
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}

#######################################
# Initial output

&MS_pages_header("DTA Cat","FF00FF");

print "<hr><br>\n";

&cgi_receive;

# If there's no directory, get some user input.
if (!defined $FORM{"Directory"}) {
	&get_alldirs;
	&output_form;
}

# Otherwise, go ahead and cat the two files.
&interpret_formdata;


######################################
##PERLDOC##
# Function : interpret_formdata
# Argument : none
# Globals  : none
# Returns  : none
# Descript : interprets the data passed into dtacat
# Notes    : 
##ENDPERLDOC##

sub interpret_formdata {

# Declare our variables.  We'll use the what was submitted in the form if there was anything submitted;
# else we use the default.

my $directory = $FORM{"Directory"};
my $mhtolerance = defined $FORM{"MHTolerance"} ? $FORM{"MHTolerance"} : $DEFS_DTACAT{"MHTolerance"};
my $scantolerance = defined $FORM{"ScanTolerance"} ? $FORM{"ScanTolerance"} : $DEFS_DTACAT{"ScanTolerance"};
my $operation = defined $FORM{"Operations"} ? $FORM{"Operations"} : $DEFS_DTACAT{"Operations"};
$dryrun = (!$FORM{"Confirm"});

# We're either summing or averaging.  If we're averaging, we'll sum and then
# divide by two; if we're summing, we'll sum and then divide by one.

$average = ($operation eq "Average");
my $deleteoriginals = defined $FORM{"DeleteOriginalDTAs"} ?
	($FORM{"DeleteOriginalDTAs"} eq "on" ? 1 : 0) :
	($DEFS_DTACAT{"DeleteOriginalDTAs"} eq "yes" ? 1 : 0) ;

# Right now the directory and files are hard-coded in.  Soon, we'll let the user
# choose the directory and somehow figure out which files we want.

# $fqdirectory is the fully-qualified directory.

my $fqdirectory = "$seqdir/$directory/";

# Start the page...

print <<EOM;
	<p>
	<div class="normaltext">
EOM

# We scroll through the possible z's, looking for DTA files to match.

# The range of z values (that's the charge) is from 1 to 5.  We're using 0 to 6
# to be safe.

my @list;
my ($z, $j, $k);
my $firstfile;
my $allcattedfilecount;
$cattedfilecount = 2;

# Open the directory list into @fulllist.

opendir(DIR, $fqdirectory);
my @fulllist = grep /\.dta$/, readdir(DIR);
closedir DIR;

# We'll now scroll through the file list, by z.
# z should be from 1 to 5, so 0 through 6 should give us a wide berth.

for ($z = 0; $z < 7; $z++) {
	# Whittle down the list to only those files that end with "$z.dta".
	@list = grep /\.$z\.dta$/, @fulllist;
	
	# $j and $k step through the file list.
	
	$j = 0;
	$k = 1;
	$firstfile = 1;
	$cattedfilecount = 2;

	while ( $j <= $#list - 1 ) {
		# $j should be at most $#list-1 so that $k can be at most $#list.

		# If $list[$j] and $list[$k] have firstscans within $scantolerance of each other,
		# then we should cat them.

		if ( abs(&getfirstscan($list[$k]) - &getfirstscan($list[$j])) < $scantolerance ) {
			$exception = &cat($list[$j], $list[$k], $fqdirectory, $mhtolerance, $deleteoriginals);
			# $exception is the errors we ran into. 
			# e.g., $list[$k] has already been catted, the MH+ numbers are too far away, etc....
			if ($exception eq "") {
				# If there were no errors, then change $list[$j] to be the new file,
				# and mark $list[$k] as already catted.
				if ($firstfile) {
					$details .= (&getfirstscan($list[$j]));
					$firstfile = 0;
				}
				$cattedfilecount++;
				$details .= ", " . (&getfirstscan($list[$k]));
				$list[$j] = &fullfilename($list[$j], $list[$k]);
				$list[$k] = "dtacattedxxx" . $list[$k];
				$k++;
			} else {
				# The two files didn't merge, but we may still be within $scantolerance,
				# so try the next $k.  Also, print out the error if we're interested.
				# &error($exception);
				$k++;
			}
			if ($k > $#list) {
				# We've tried every $k, so finish up the detail line...
				if ($firstfile == 0) {
					$details .= (" -> " . $list[$j] . "<BR>\n");
					$allcattedfilecount += ($cattedfilecount - 1);
					$cattedfilecount = 2;
					$firstfile = 1;
				}
				# ...then move onto the next $j, making sure that it's not already catted.
				$j++;
				while ($list[$j] =~ /^dtacattedxxx/) { $j++; }
				$k = $j + 1;
			}
		} else {
			# If we're outside of $scantolerance, finish up the detail line...
			if ($firstfile == 0) {
				$details .= (" -> " . $list[$j] . "<BR>\n");
				$allcattedfilecount += ($cattedfilecount - 1);
				$cattedfilecount = 2;
				$firstfile = 1;
			}
			# ...then move onto the next $j, making sure that it's not already catted.
			$j++;
			while ($list[$j] =~ /^dtacattedxxx/) { $j++; }
			$k = $j + 1;
		}
	}
}

my $plural;

if (!$allcattedfilecount) { $allcattedfilecount = 0; }
if ($allcattedfilecount != 1) { $plural = "s"; }

if (!$dryrun) {
	
	my $date = localtime;

	open LOG, ">>" . $fqdirectory . $directory . ".log";
	print LOG "DTA Cat run on $date    Catted $allcattedfilecount file$plural\n";
	close LOG;
	
	print <<EOM;
	<br>
	<image src="/images/circle_1.gif">&nbsp;DTA Cat finished.  Catted $allcattedfilecount file$plural.
	<A HREF="$webcgi/sequest_launcher.pl?directory=$directory&continue_unfinished=1&defined_clear_existing=0">Run Sequest on new dtas?</A>
	</div>
EOM
	
	@text = ("Run Sequest","Create DTA", "Sequest Summary","View DTA Chromatogram");
	@links = ("sequest_launcher.pl","create_dta.pl","runsummary.pl?directory=$newdir","dta_chromatogram.pl");
	&WhatDoYouWantToDoNow(\@text, \@links);

	print <<EOF;
	<BR>
	<DIV CLASS="smalltext">
	$details
	</DIV>
	</BODY>
	</HTML>
EOF

} else {

	print <<EOF;
	DTA Cat will cat approximately $allcattedfilecount file$plural.  (The number is approximate because the averaging of MH+
		values can bring other files into or out of MH+ tolerance.)
	</DIV>

	<DIV><P>
	<A HREF="dtacat.pl?$ENV{'QUERY_STRING'}&Confirm=1">Click here to continue...</A>
	</P></DIV>

	<DIV CLASS="smalltext">
	$details
	</DIV>

	</BODY>
	</HTML>
EOF
	
}

exit;

}

##PERLDOC##
# Function : fullfilename
# Argument : two dta file names
# Globals  : none
# Returns  : their 'joined' file name
# Descript : takes two file names and returns their 'joined' file name
# Notes    : dta filenames are in the form of prefix.firstscan.lastscan.z.dta.
#			 This function takes the min of the two firstscans and the max
#			 of the two lastscans and returns prefix.firstscanmin.lastscanmax.z.dta.
#			 The prefix, the z and the dta should be the same for both files.
##ENDPERLDOC##

sub fullfilename {

# This subroutine takes two file names and returns their 'joined' file name.

my ($dta1_file, $dta2_file) = @_;

my @dta1_filespecs = split(/\./, $dta1_file);
my @dta2_filespecs = split(/\./, $dta2_file);

return $dta1_filespecs[0] . "." . &min($dta1_filespecs[1], $dta2_filespecs[1])
	. "." . &max($dta1_filespecs[2], $dta2_filespecs[2]) . "." . $dta1_filespecs[3] . ".dta";

}

##PERLDOC##
# Function : cat
# Argument : two dta filenames, their directory, the mh tolerance, and whether to delete the originals
# Globals  : uses $dryrun
# Returns  : returns an error if something went wrong
# Descript : actually cats the files
# Notes    : the directory must be fully-qualified
##ENDPERLDOC##

sub cat {

my ($dta1_file, $dta2_file, $fqdirectory, $mhtolerance, $deleteoriginals) = @_;

# We're finding out the specific parts of the DTA filename.
# The spec is:
#	prefix.firstscan.lastscan.z.dta

my @dta1_filespecs = split(/\./, $dta1_file);
my @dta2_filespecs = split(/\./, $dta2_file);

# First, we'll check that the second file hasn't already been used...

if ($dta2_file =~ /^dtacattedxxx/) {
		return "$dta2_file already catted.";
}

# ...then that the prefix and the z are the same for both files...

if (($dta1_filespecs[0] != $dta2_filespecs[0]) ||
	($dta1_filespecs[3] != $dta2_filespecs[3])) {
		return "$dta1_file and $dta2_file cannot be merged--different prefix or z.";
}

# ...then we check that the second file doesn't have the same firstscan and lastscan...

if ($dta2_filespecs[1] != $dta2_filespecs[2]) {
	return "$dta2_file cannot be merged; it has a different firstscan and lastscan.";
}

# ... then we create a file name for the output file.
# The spec for this is the same, but a little trickier:
#	prefix.[min of the two firstscans].[max of the two lastscans].z.dta
#
# This will of course cause some difficulties if the scans of one file are entirely included in another.
#
# For example, if one tries to cat shadowfax.100.200.3.dta with shadowfax.150.150.3.dta, then
# the result file will be shadowfax.100.200.3.dta--which is the same as the first file, causing an error.
#
# At the moment, I'm only merging files that have the same firstscan and lastscan, but if this changes,
# then we'll have to worry about it.

my $outputfile = $dta1_filespecs[0] . "." . &min($dta1_filespecs[1], $dta2_filespecs[1])
	. "." . &max($dta1_filespecs[2], $dta2_filespecs[2]) . "." . $dta1_filespecs[3] . ".dta";

# Open the files.

open DTA1, $fqdirectory . $dta1_file or return "Could not open $dta1_file.";
open DTA2, $fqdirectory . $dta2_file or return "Could not open $dta2_file.";
# Read in the first lines of both of the files.
# This line contains the MH+ and the z, seperated by a space.

@dta1_line = split(/ /, <DTA1>);
@dta2_line = split(/ /, <DTA2>);

if (abs($dta1_line[0] - $dta2_line[0]) > $mhtolerance) {
	return "$dta1_file and $dta2_file cannot be merged--different MH+.";
}

if ($dryrun) {
	close DTA1;
	close DTA2;
	return "";
}

open OUTPUT, ">" . $fqdirectory . $outputfile or return "Could not open $outputfile for writing.";

# Now we write OUTPUT's first line.  This averages the MH+ and just places in the z (which is the same).

print OUTPUT &merge($dta1_line[0], $dta2_line[0], 1);
print OUTPUT " " . $dta1_line[1] . "\n";

# Read in the second lines, to prepare for the loop below.

@dta1_line = split(/ /, <DTA1>);
@dta2_line = split(/ /, <DTA2>);

# Until we get to the EOF of DTA1 and DTA2...

while (!((eof DTA1) || (eof DTA2))) {

# ... cat them!
# If they have the 'same' m/z (from the left column), then 'merge' the intensity (from the right column).
#		(Merging is either summing or averaging, and is done by the &merge function.)
# If they don't, then take whichever m/z is lower and put it in the file.
# Then read in the next line from whichever file.

	if ($dta1_line[0] = $dta2_line[0]) {
		print OUTPUT $dta1_line[0] . " " . &merge($dta1_line[1], $dta2_line[1]) . "\n";
		@dta1_line = split(/ /, <DTA1>);
		@dta2_line = split(/ /, <DTA2>);
	} elsif ($dta1_line[0] < $dta2_line[0]) {
		print OUTPUT $dta1_line[0] . " " . &merge($dta1_line[1], 0) . "\n";
		@dta1_line = split(/ /, <DTA1>);
	} else {
		print OUTPUT $dta2_line[0] . " " . &merge(0, $dta2_line[1]) . "\n";
		@dta2_line = split(/ /, <DTA2>);
	}

}

# If we're at the EOF of DTA1, we probably have some more of DTA2.  Thus, dump it in the file.
# Else, dump the stuff from DTA1 in the file.

if (eof DTA1) {
	while (<DTA2>) {
		@dta2_line = split(/ /);
		print OUTPUT $dta2_line[0] . " " . &merge(0, $dta2_line[1]) . "\n";
	}
} else {
	while (<DTA1>) {
		@dta1_line = split(/ /);
		print OUTPUT $dta1_line[0] . " " . &merge($dta1_line[1], 0) . "\n";
	}
}

# Close everything out.

close DTA1;
close DTA2;
close OUTPUT;

if ($deleteoriginals) {
	unlink("$fqdirectory$dta1_file");
	unlink("$fqdirectory$dta2_file");
	my $out1_file = $dta1_file;
	my $out2_file = $dta2_file;
	$out1_file =~ s/dta$/out/;
	$out2_file =~ s/dta$/out/;
	unlink("$fqdirectory$out1_file");
	unlink("$fqdirectory$out2_file");
} else {
	# If we've merged more than two files, then we have to deal with the merge of the first two.
	# And when I say "deal with it", I mean delete it.
#	First, check to see if it has an out file.  If it does, don't delete it.
#	if (($cattedfilecount > 2) && !(-e "$fqdirectory$out1_file")) {
	if ($cattedfilecount > 2) {
		my $out1_file = $dta1_file;
		$out1_file =~ s/dta$/out/;
		unlink("$fqdirectory$dta1_file");
		unlink("$fqdirectory$out1_file");
	}
}

return;

}

##PERLDOC##
# Function : getfirstscan
# Argument : a dta file name
# Globals  : none
# Returns  : 10000000 if no file name is given; else, returns the first scan
# Descript : returns the first scan of a dta file name
##ENDPERLDOC##

sub getfirstscan {
	# If we are given a blank file name, make sure we return an out of range firstscan.
	if (!($_[0])) { return 10000000; }
	@filespecs = split(/\./, $_[0]);
	return $filespecs[1];
}

##PERLDOC##
# Function : getlastscan
# Argument : a dta file name
# Globals  : none
# Returns  : the last scan
# Descript : returns the last scan of a dta file name
##ENDPERLDOC##

sub getlastscan {
	@filespecs = split(/\./, $_[0]);
	return $filespecs[2];
}


#######################################
##PERLDOC##
# Function : output_form
# Argument : none
# Globals  : uses a bunch
# Returns  : none
# Descript : outputs the form for user input
##ENDPERLDOC##

sub output_form {

$checked{$DEFS_DTACAT{"Operation"}} = " CHECKED";
$checked{"DeleteOriginalDTAs"} = ($DEFS_DTACAT{"DeleteOriginalDTAs"} eq "yes") ? " CHECKED" : "";

  print <<EOFORM;
<FORM ACTION="$ourname" METHOD=GET>

<TABLE CELLPADDING=0 BORDER=0 CELLSPACING=5>

<TR>

<TH style="text-align:right;"><SPAN CLASS="smallheading">Directory:&nbsp;</SPAN></TH>

<TD><SPAN CLASS=dropbox><SELECT NAME="Directory">

EOFORM

  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

  print <<EOFORM;
</SELECT></SPAN></TD>
</TR>

<TR>
<TH style="text-align:right;"><span class="smallheading">MH+ Tolerance:&nbsp;</SPAN></TH>
<TD><INPUT NAME="MHTolerance" VALUE="$DEFS_DTACAT{"MHTolerance"}" SIZE=4></TD>
</TR>

<TR>
<TH style="text-align:right;"><span class="smallheading">No. of Scans Tolerance:&nbsp;</SPAN></TH>
<TD><INPUT NAME="ScanTolerance" VALUE="$DEFS_DTACAT{"ScanTolerance"}" SIZE=4></TD>
</TR>

<TR>
<TH style="text-align:right;"><SPAN CLASS="smallheading">Operation:&nbsp;</SPAN></TH>
<TD><span class="smalltext"><INPUT TYPE=RADIO NAME="Operation" value="Average"$checked{'Average'}>Average
<INPUT TYPE=RADIO NAME="Operation" value="Sum"$checked{'Sum'}>Sum</span></TD>
</TR>

<TR>
<TH style="text-align:right;"><SPAN CLASS="smallheading">Delete original DTAs?&nbsp;</SPAN></TH>
<TD><span class="smalltext"><INPUT TYPE=CHECKBOX NAME="DeleteOriginalDTAs"$checked{'DeleteOriginalDTAs'}></SPAN></TD>
</TR>

<TR>
<TD><BR>&nbsp;</TD>
<TD style="vertical-align:middle;"><INPUT TYPE=SUBMIT CLASS=button VALUE="Cat 'em!">
&nbsp;&nbsp;&nbsp;&nbsp;
<span class="smallheading"><A HREF="/Help/help_dtacat.pl.html">Help</A></SPAN></TD>
</TR>

</TABLE>
</FORM>
EOFORM

	exit;
}


#######################################
##PERLDOC##
# Function : error
# Argument : the error
# Returns  : none
# Descript : your happy-go-lucky error routine
##ENDPERLDOC##
sub error {

	print <<EOF;
<B>Error:</B> @_<BR>
EOF

}

##PERLDOC##
# Function : merge
# Argument : the two values to 'merge'
# Globals  : uses $dividend
# Returns  : the 'merged' value
# Descript : return the 'merge' of two intensities--either add them or average them, depending on $dividend
# Notes    : $dividend is a global variable that's 1 if we're summing and 2 if we're averaging.
#			 The 0.5 is to get the int to round it properly.  (I could have used sprintf, but it looks so ugly...)
#			 Added the ".0" to conform to the other DTA files and not crash DTA VCR and such.
##ENDPERLDOC##

sub merge {
	my $dividend;
	if ($_[3]) {
		# We're doing the first line, so we average no matter what.
		$dividend = $cattedfilecount;
	} else {
		$dividend = ($average ? $cattedfilecount : 1);
	}
	return int((
		($_[0] * ($dividend - 1)) + $_[1]
			/ $dividend
	)
	+ 0.5) . ".0";
}