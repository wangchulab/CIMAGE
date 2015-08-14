#!/usr/local/bin/perl

#-------------------------------------
#	The Good, the Bad and the Ugly
#	(C)2001 Harvard University
#	
#	W. S. Lane/E. Perez
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 2/20/01 by Edward Perez
# most recent update: 2/26/01
#
# Description: Bins DTA's into one of 3 categories: trash, beatiful, or ambiguous.
#


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
	require "microchem_form_defaults.pl";
	require "goodbadugly_include.pl";
	require "status_include.pl";
}


########################################
# Global Vars
%Ratings;			# ratings, indexed by dta filename



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};
$doCorrelation = $FORM{"DoCorrelation"} ? $FORM{"DoCorrelation"} : "";
$numTopIons = $FORM{"numTopIons"} ? $FORM{"numTopIons"} : $DEFS_GOODBADUGLY{"Number of Ions"};
$excludeRadius = $FORM{"excludeRadius"} ? $FORM{"excludeRadius"} : $DEFS_GOODBADUGLY{"Isotope Radius"};
$grassRadius = $FORM{"grassRadius"} ? $FORM{"grassRadius"} : $DEFS_GOODBADUGLY{"Window Width"};
$noiseCutoff2Plus = $FORM{"noiseCutoff2Plus"} ? $FORM{"noiseCutoff2Plus"} : $DEFS_GOODBADUGLY{"Noise Threshold for 2+"};
$noiseCutoff3Plus = $FORM{"noiseCutoff3Plus"} ? $FORM{"noiseCutoff3Plus"} : $DEFS_GOODBADUGLY{"Noise Threshold for z > 2+"};
$minTopIonSpacing = $FORM{"minTopIonSpacing"} ? $FORM{"minTopIonSpacing"} : $DEFS_GOODBADUGLY{"Min Ion Spacing"};
$noDoubleCounting = $FORM{"noDoubleCounting"} ? $FORM{"noDoubleCounting"} : $DEFS_GOODBADUGLY{"Avoid Double Counting"};
$significantGrassRatio = $FORM{"significantGrassRatio"} ? $FORM{"significantGrassRatio"} : $DEFS_GOODBADUGLY{"Min Grass Height Ratio"};
$numPardons = $FORM{"numPardons"} ? $FORM{"numPardons"} : $DEFS_GOODBADUGLY{"Blades of Grass to Ignore"};
$weakUpperHalfIonCountCutoff = $FORM{"weakUpperHalfIonCountCutoff"} ? $FORM{"weakUpperHalfIonCountCutoff"} : $DEFS_GOODBADUGLY{"Weak Upper Half Ion-Count"};
# 1+ specific form values
$precursorWindow = $FORM{"precursorWindow"} || $DEFS_GOODBADUGLY{"Precursor Window (1+)"};
$excludeWaterLosses = $FORM{"excludeWaterLosses"} || $DEFS_GOODBADUGLY{"Exclude Water Losses"};
$excludeAmmoniaLosses = $FORM{"excludeAmmoniaLosses"} || $DEFS_GOODBADUGLY{"Exclude Ammonia Losses"};
$waterAmmoniaTolerance = $FORM{"waterAmmoniaTolerance"} || $DEFS_GOODBADUGLY{"Water/Ammonia tolerance"};
$noiseCutoff1Plus = $FORM{"noiseCutoff1Plus"} || $DEFS_GOODBADUGLY{"Noise Threshold for 1+"};
$numTopIons1Plus = $FORM{"numTopIons1Plus"} || $DEFS_GOODBADUGLY{"Number of Ions (1+)"};
$significantGrassRatio1Plus = $FORM{"significantGrassRatio1Plus"} || $DEFS_GOODBADUGLY{"Min Grass Height Ratio (1+)"};
$goodCutoff1Plus = $FORM{"goodCutoff1Plus"} || $DEFS_GOODBADUGLY{"Good DTA threshold for 1+"};

#######################################
# Initial output
&MS_pages_header("The Good, the Bad, and the Ugly","#871F78");

#######################################
# Flow control
if (!defined $dir) {
	&choose_directory;
} else {
	&watch_over_me;
	&main;
}

exit 1;

######################################
# Main action

sub main{

	print "<hr><p>";

	#a necessary initialization
	if($doCorrelation){
		&setup_aa_mass_hash;
	}

	#get the list of all DTA files actually in the directory
	@DTAfilenames = &get_DTA_file_list;

	#get the intensities
	%intensity = &get_name_intensity_pairs;

	$scorefilename = "goodbadugly.txt";

	if( &score_file_exists){
		print "Directory $dir already has a good-bad-ugly score file. Overwriting old file ...<br>";
	}

	open OUT, ">$seqdir/$dir/$scorefilename"  or die("Couldn't make the file<br>");
		

	# check each dta and write the verdict to a file
	foreach $dta (@DTAfilenames) {
		$score = &classify_dta($dta);
		print OUT "$dta $score\n";
		$Ratings{$dta} = $score;
	}

	close OUT;

	#wiite to the log file
	&write_log($dir,"GoodBadUgly run " . localtime());

	# now print the "What do you want to do now?"
	@text = ("View Results","run good-bad-ugly on another directory","run Signal to Noise","run weak spectrum detection");
	@links = ("runsummary.pl?directory=$dir&sort=consensus","goodbadugly2.pl","signal_to_noise.pl","anemic_dta.pl");
	&WhatDoYouWantToDoNow(\@text, \@links);

	$rate_func = sub { return($Ratings{$_[0]}); };

	# this is old code that used to make the summary stats table. Now that functionality is handled by view_gbu_summary.pl
	#&write_summary_stats(\@DTAfilenames,"gbu_summary.txt", [1, 0, -1], $rate_func, [1, 2, 3, 4, 5], \&get_charge_state);
}


# get_DTA_file_list
# Returns an array of strings which are the names of DTA files in the chosen directory
sub get_DTA_file_list{
	my(@list,@DTAlist,$name);
	opendir DIR , "$seqdir/$dir" or &error("Couldn't open directory");
	@list = readdir DIR;
	foreach $name (@list) {
		if ($name =~ /\.dta$/) {
			push @DTAlist, $name;
		}
	}
	return(@DTAlist);
}




#######################################
# Subroutines for output






# the form subroutine
sub choose_directory {
	print "<HR>\n";

	&get_alldirs;

	print <<EOFORM;

<FORM NAME="Directory Select" ACTION="$ourname" METHOD=get>
<TABLE BORDER=0 CELLSPACING=6 CELLPADDING=0>
<TR>
	<TD align=right><span class="smallheading">Directory:&nbsp;</span></TD>
	<TD>
	<span class=dropbox><SELECT NAME="directory">
EOFORM

	foreach $dir (@ordered_names) {
	      print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
	}
print <<DONE;

<TR><TD><TD>
	<INPUT type="checkbox" name="DoCorrelation" value="yes">Use correlation
</TR>

<TR><TD>
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></TD>
</TR>

<TR>
<TD align=right><span class="smallheading">Advanced:&nbsp;</span></TD>
<TD>

<TABLE bgcolor="#e2e2e2">
<TR>
	<TD align=right><span class="smallheading">Number of Ions:&nbsp;</span></TD>
	<TD><input type="text" name="numTopIons" size=2 maxlength=2 value=$DEFS_GOODBADUGLY{"Number of Ions"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Number of Ions (1+):&nbsp;</span></TD>
	<TD><input type="text" name="numTopIons1Plus" size=2 maxlength=2 value=$DEFS_GOODBADUGLY{"Number of Ions (1+)"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Window Width:&nbsp;</span></TD>
	<TD><input type="text" name="grassRadius" size=2 maxlength=3 value=$DEFS_GOODBADUGLY{"Window Width"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Precursor Window (1+):&nbsp;</span></TD>
	<TD><input type="text" name="precursorWindow" size=2 maxlength=3 value=$DEFS_GOODBADUGLY{"Precursor Window (1+)"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Isotope Radius:&nbsp;</span></TD>
	<TD><input type="text" name="excludeRadius" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Isotope Radius"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Water/Ammonia Tolerance:&nbsp;</span></TD>
	<TD><input type="text" name="waterAmmoniaTolerance" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Water/Ammonia tolerance"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Avoid Double Counting:&nbsp;</span></TD>
	<TD><input type="checkbox" name="noDoubleCounting" value="yes" checked=$DEFS_GOODBADUGLY{"Avoid Double Counting"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Exclude Water Losses (1+):&nbsp;</span></TD>
	<TD><input type="checkbox" name="excludeWaterLosses" value="yes" checked=$DEFS_GOODBADUGLY{"Exclude Water Losses"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Exclude Ammonia Losses (1+):&nbsp;</span></TD>
	<TD><input type="checkbox" name="excludeAmmoniaLosses" value="yes" checked=$DEFS_GOODBADUGLY{"Exclude Ammonia Losses"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Noise Threshold for 1+:&nbsp;</span></TD>
	<TD><input type="test" name="noiseCutoff1Plus" size=3 maxlength=5 value=$DEFS_GOODBADUGLY{"Noise Threshold for 1+"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Noise Threshold for 2+:&nbsp;</span></TD>
	<TD><input type="test" name="noiseCutoff2Plus" size=3 maxlength=5 value=$DEFS_GOODBADUGLY{"Noise Threshold for 2+"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Noise Threshold for z > 2+:&nbsp;</span></TD>
	<TD><input type="test" name="noiseCutoff3Plus" size=3 maxlength=5 value=$DEFS_GOODBADUGLY{"Noise Threshold for z > 2+"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Good DTA threshold for 1+:&nbsp;</span></TD>
	<TD><input type="test" name="goodCutoff1Plus" size=3 maxlength=5 value=$DEFS_GOODBADUGLY{"Good DTA threshold for 1+"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Min Ion Spacing:&nbsp;</span></TD>
	<TD><input type="test" name="minTopIonSpacing" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Min Ion Spacing"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Min Grass Height Ratio:&nbsp;</span></TD>
	<TD><input type="test" name="significantGrassRatio" size=4 maxlength=5 value=$DEFS_GOODBADUGLY{"Min Grass Height Ratio"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Min Grass Height Ratio (1+):&nbsp;</span></TD>
	<TD><input type="test" name="significantGrassRatio1Plus" size=4 maxlength=5 value=$DEFS_GOODBADUGLY{"Min Grass Height Ratio (1+)"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Blades of Grass to Ignore:&nbsp;</span></TD>
	<TD><input type="test" name="numPardons" size=2 maxlength=2 value=$DEFS_GOODBADUGLY{"Blades of Grass to Ignore"}></TD>
</TR>
<TR>
	<TD align=right><span class="smallheading">Weak Upper Half Ion-Count:&nbsp;</span></TD>
	<TD><input type="test" name="weakUpperHalfIonCountCutoff" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Weak Upper Half Ion-Count"}></TD>
</TR>
</TABLE>



</Table>
</Form></Body></HTML>

DONE
}



#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {

	if($WEB_MODE){
		print <<ERRMESG;
	<HR><p>
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG
	}

	exit 1;
}

sub score_file_exists{
	my($exists,$name,@list);
	$exists = 0;
	opendir DIR , "$seqdir/$dir";
	@list = readdir DIR;
	foreach $name (@list) {
		if ($name eq $scorefilename) {
			$exists = 1;
		}
	}
	return($exists);
}

# End of goodbadugly2.pl