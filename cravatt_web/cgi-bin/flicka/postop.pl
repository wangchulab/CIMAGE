#!/usr/local/bin/perl

#-------------------------------------
#	postop.pl
#	(C)1999 Harvard University
#	
#	W.S. Lane/ A. Chang
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 12/13/01 by A. Chang
# Last Modified: 12/13/01 by A. Chang
#
# allows for simultaneous parsing of sequest directories with GBU, ScoreFinal, and/or SigCalc

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
}
use Win32;

require "status_include.pl"; # need this sig calc running process checks
#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
&MS_pages_header("Post-Op","");


#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.

&cgi_receive;

$dir = $FORM{"dir"};

$gbuCheck = $FORM{"gbu"};
$sfCheck = $FORM{"sf"};
$scCheck = $FORM{"sc"};

#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

print "<hr>";

if (!defined $dir) {
  &get_alldirs;
  &output_form;
  exit;
}

# send default parameters to each of the selected programs

$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir);
print "<br><div><span class=smallheading>Directory: </span><a href=\"$viewinfo?directory=$dir\">$dir</a></div>";

$linecount=0;
$| = 1;

# paths for output files - not currently in use, previous versions checked for presence, but combined dirs needed new
# computation so redo all processes by default

$gbuOutput = "$seqdir/$dir/goodbadugly.txt";
$sfOutput = "$seqdir/$dir/seq_score_combiner.txt";
$scOutput = "$seqdir/$dir/probability.txt";

# go thru conditions of which checkboxes have been selected, each process runs sequentially, re-run each on dir even if already done before

if ($gbuCheck) {
	$linecount++;

	print "<br><div><image src='/images/circle_$linecount.gif'> The Good, Bad, and Ugly is: </div>";

	$process = &run_silently_in_background("$goodbagugly_cmdline USE_QUERY_STRING_INTRACHEM");
	#print "<span class=smallheading> working </span>";
	until ($process->Wait(1000)) {
		print "<b>.</b>" or &abort($process);
	}

	print "<span class=smallheading> done </span><br>";
}


if ($sfCheck) {
	$linecount++;

	print "<br><div><image src='/images/circle_$linecount.gif'> Final Score is: </div>";

	$process = &run_silently_in_background("$score_final_cmdline USE_QUERY_STRING_INTRACHEM");
	#print "<span class=smallheading> working </span>";
	until ($process->Wait(1000)) {
		print "<b>.</b>" or &abort($process);
	}

	print "<span class=smallheading> done </span><br>";
}

# since sigcalc is cpu-intensive, check in future that only one sigcalc process is up at any given time

if ($scCheck) {
	$linecount++;

	print "<br><div><image src='/images/circle_$linecount.gif'> Significance Calculation is:  </div>"; 

	# must make sure to check that only ONE sigcalc process is running at a given moment
	$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir, "FROM_FRONTPAGE" => "true"); #use FROM_FRONTPAGE=true for nanny check??? is this working properly? 

	$process = &run_silently_in_background("$significance_calculation_cmdline USE_QUERY_STRING_INTRACHEM"); 
	#print "<span class=smallheading> working </span>";
	$char_count = 0;                   # word wrap counter, resets after 76 chars on a line (leave space for "done")
	until ($process->Wait(2000)) {
		print "<b>.</b>" or &abort($process);
		$char_count++;

		if ($char_count == 76) {
			print "<br>";
			$char_count = 0;
		}
	}

	print "<span class=smallheading> done </span><br>";
}
	

if ($linecount == 0) {
	print "<br><div> No actions performed. </div>";
}
else {
	print "<br><div> All processes completed. </div>";
}

@text = ("Run Sequest", "View Summary", "VuDTA");
@links = ("sequest_launcher.pl?directory=$dir", "runsummary.pl?directory=$dir", "dta_chromatogram.pl?def_dir=$dir");
&WhatDoYouWantToDoNow(\@text, \@links);

exit 0;

#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {
	print <<FORM;
<form method="post" action=$ourname>
<table>
<tr><td><SPAN CLASS=dropbox><SELECT NAME="dir">
FORM

	foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

	print <<FORM;
</SELECT></SPAN></TD>
</table>

<br>
<table>
<tr><td>&nbsp;</td>  
	<td><span class="smallheading">&nbsp;&nbsp; Procedure</span></td></tr>
<tr><td><center><input type=checkbox name="gbu" checked></center></td>
	<td><div>&nbsp;&nbsp;<a href="goodbadugly2.pl">The Good, Bad, and Ugly</a></div></td></tr>
<tr><td><center><input type=checkbox name="sf" checked></center></td>
	<td><div>&nbsp;&nbsp;<a href="scorefinal.pl">Final Score</a></div></td></tr>
<tr><td><center><input type=checkbox name="sc" checked></center></td>
	<td><div>&nbsp;&nbsp;<a href="sigcalc.pl">Significance Calculation</a></div></td></tr>
</table>
<br>
<input class=button type="submit" value="Execute">
</form>
FORM
}

#<tr><td><center><input type=checkbox name="sc" checked></center></td> # place checkbox back when sigcalc is running properly 1/14/02

#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {

	# if not used near the top of the program:
	&MS_pages_header("Post-Op","");

	exit 1;
}
