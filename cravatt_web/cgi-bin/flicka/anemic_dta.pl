#!/usr/local/bin/perl

#-------------------------------------
#	Anemic DTA,
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
# Description: Recognizes DTAs in a directory that are not 1+ and have very little above the precursor
#



################################################
# find and read in standard include file
{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "microchem_form_defaults.pl";
}



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};
$weakUpperHalfIonCountCutoff = $FORM{"weakUpperHalfIonCountCutoff"};


#######################################
# Global Vars


#######################################
# Initial output
&MS_pages_header("Anemic DTA","#871F78");


#######################################
# Flow control
if (!defined $dir) {
	&choose_directory;
} else {
	&main;
}

exit 1;

######################################
# Main action

sub main{

	print "<hr><p>";

	$outputFileName = "anemic.txt";

	#get the list of all DTA files actually in the directory
	@DTAfilenames = &get_DTA_file_list;

	open OUT, ">$seqdir/$dir/$outputFileName" or error("Couldn't create output file<br>");

	# check each dta and write the verdict to a file
	foreach $dta (@DTAfilenames) {
		$diagnosis = 0;
		$diagnosis = &diagnose($dta);
		if ($diagnosis) {
			$rating = ($diagnosis==1 ? "semianemic" : "anemic");	
		} else {
			$rating = "fine";
		}
		print OUT "$dta $diagnosis $rating\n";
	}

	close OUT;

	# now print the "What do you want to do now?"
	@text = ("View Results","run Anemic DTA on another directory","run The Good, the Bad, and the Ugly");
	@links = ("runsummary_edwardanem.pl?directory=$dir","anemic_dta.pl","goodbadugly2.pl");
	&WhatDoYouWantToDoNow(\@text, \@links);
}


sub diagnose{
	
	my($dta) = $_[0];
	
	open DTA, "$seqdir/$dir/$dta" or die "Could not open $seqdir/$dir/$dta exiting.<br>";

	# eat the header
	$_=<DTA>;
	($MH,$z)= split / /;

	$precursor=($MH - $Mono_mass{"hydrogen"})/$z + $Mono_mass{"hydrogen"};

	if($z == 1){
		return(0);
	}
   
	# make a hash out of the DTA simultaneously pull out the second highest intensity
	my(%signal,$topmass,$topintensity,$secondmass,$secondintensity,$i,$ioncount,$significantcount);
	while ($line=<DTA>) {
	
		($mass, $intensity)= split /\s/, $line;
		
		if($mass > ($precursor + 5)){
			$signal{$mass} = $intensity;
		}

		if($i == 0){
			$topintensity = $thirdintensity = $secondintensity = $intensity;
		}
		if ($intensity > $topintensity ) {
			$thirdintensity = $secondintensity;
			$secondintensity = $topintensity;
			$topintensity = $intensity;
		} elsif ($intensity > $secondintensity){
			$thirdintensity = $secondintensity;
			$secondintensity = $intensity;
		} elsif ($intensity > $thirdintensity){
			$thirdintensity = $intensity;
		}
		$i++;
	}

	$ioncount = $significantcount = 0;
	foreach  (keys(%signal)) {
		$ioncount++;
		if( $signal{$_} > ($thirdintensity * 0.20) ){
			$significantcount++;
		}
	}
	
	if( $ioncount < 10){
		return(2);
	}elsif($significantcount==0){
		return(1);
	}else{
		return(0);
	}
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
# Main form subroutines

# note that we're going to take the defaults from GBU, since these two scripts are so closely tied in to one another
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

<TR><TD align=right><span class="smallheading">Cutoff for upper half:&nbsp;</span></TD>
	<TD>
	<input type="text" name="weakUpperHalfIonCountCutoff" size=3 maxlength=3 value=$DEFS_GOODBADUGLY{"Weak Upper Half Ion-Count"}>
	</TD>
<TR><TD>
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/goodbadugly2.pl.html">Help</A></span></TD>
</TR></Table>
</Form></Body></HTML>

DONE
}


#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {

	if($WEB_MODE){
		print <<ERRMESG;
	<p><HR><p>
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG
	}

	exit 1;
}


# End of anemic_dta.pl