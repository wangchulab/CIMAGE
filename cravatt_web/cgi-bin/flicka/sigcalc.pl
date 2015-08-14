#!/usr/local/bin/perl

#-------------------------------------
#	Significance Calculation,
#	(C)2001 Harvard University
#	
#	W. S. Lane/E. Perez
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 7/20/01 by Edward Perez
# most recent update:
#
# Description:
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
	require "status_include.pl";
	require "sigcalc_include.pl";
}

#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.

# first, figure out if we're being run from the command-line or via CGI

require "seqcomm_include.pl";

&cgi_receive;
$dirs = $FORM{"directory"};
$append = $FORM{"append"};
$saw_warning = $FORM{"FROM_FRONTPAGE"};
$ignore_other_sigcalcs = $FORM{"ignore_others"};

if( $FORM{"FROM_FRONTPAGE"} ){
	# take checkbox values from the from
	$WATER_LOSSES = $FORM{"water_losses"};
	$TWO_PLUS_IONS_ON_TWO_PLUS_SPECTRA = $FORM{"TWO_PLUS_IONS_ON_TWO_PLUS_SPECTRA"};
	$THREE_PLUS_IONS_ON_THREE_PLUS_SPECTRA = $FORM{"THREE_PLUS_IONS_ON_THREE_PLUS_SPECTRA"};
	$LEFT_ISOTOPE = $FORM{"left_isotope"};
}else{
	# take checkbox values from defaults
	$WATER_LOSSES = $DEFS_SIGCALC{"Water Losses"} eq "yes" ? 1 : 0;
	$TWO_PLUS_IONS_ON_TWO_PLUS_SPECTRA = $DEFS_SIGCALC{"2+ Ions for 2+ spectra"} eq "yes" ? 1 : 0;
	$THREE_PLUS_IONS_ON_THREE_PLUS_SPECTRA = $DEFS_SIGCALC{"3+ Ions for 3+ spectra"} eq "yes" ? 1 : 0;
	$LEFT_ISOTOPE = $DEFS_SIGCALC{"Choose left isotope"} eq "yes" ? "checked" : "";
}

$MHPLUS_TOLERANCE = exists $FORM{"MHPLUS_TOLERANCE"} ? $FORM{"MHPLUS_TOLERANCE"} : $DEFS_SIGCALC{"MH+ Tolerance"};
$SIG_CALC_MAX_RANK = defined $FORM{"max_rank"} ? $FORM{"max_rank"} : $DEFS_SIGCALC{'Max Rank'};
$FRAGMENT_ION_TOLERANCE = defined  $FORM{"FRAGMENT_ION_TOLERANCE"} ? $FORM{"FRAGMENT_ION_TOLERANCE"} : $DEFS_SIGCALC{'Fragment Ion Tolerance'};

$WATER_LOSS_FLAG = $WATER_LOSSES ? "-w " : "";
$LEFT_ISOTOPE_FLAG = $LEFT_ISOTOPE ? "-l " : "";

#######################################
# Global Vars
$MaxIter = 4;

#######################################
# Initial output
&MS_pages_header("Significance Calculation","#871F78");

#######################################
# Flow control
# The flow control is the following: if you call sig calc from ther outside with a dirname in the URL then it executes if no other
# sig calcs are running but otherwise it takes you to the front page with the message that others are running.

$sig_calcs_running = &see_if_running;
if (!defined $dirs) {
	&choose_directory;
} else {
	if( $saw_warning or ($sig_calcs_running == 0 or $ignore_other_sigcalcs eq "yes") or $FORM{"NANNY_WATCHING"}){
		# ready to rip
		$| = 1;
		&watch_over_me(); 
		&javastuff;
		&main;
	} else {
		&choose_directory;
	}
}

exit 0;

######################################
# Main action

sub main{

  foreach $dir (split /, /, $dirs) {
	#initializations 
	$j = 0;
	$next_percent = 0;
	my(%results) = ();

	$outfile = "$seqdir/$dir/probability.txt";
	
	print "<hr><p>";
	print qq(<span class="smalltext">Running Significance Calculation on $dir </span>);
	&kill_switch();
	print "<br>";
	
	#get the list of all DTA files actually in the directory
	@DTAfilenames = &get_DTA_file_list;

	# see if user wants to start from scratch
	unlink $outfile if ((not $append) and -e $outfile);

	chdir "$seqdir/$dir";

	# read the params file 
	&getAddMasses("$seqdir/$dir");
	&get_enzyme("$seqdir/$dir");

	# check each dta and write the verdict to a file	
	open SCORES, "$outfile";
	while(<SCORES>){
		($key,$value) = split / /;
		$done{$key} = $value;
	}
	close SCORES;


	$start = time;

	print qq(<span class="smallheading">Progress:</span>\n);
	print qq(<pre><b>0%                                   100%\n);

	$max_j = scalar(@DTAfilenames);

	foreach $dta (@DTAfilenames) {

		$j++;
		if (($j / $max_j) >= $next_percent) {
			$next_percent += 0.05;
			print ". ";
		}

		if( not exists $done{$dta}){
			%results = &dtaSigcalc("$seqdir/$dir/$dta");
		}

		# add results to the output file	
		open SCORES, ">>$outfile";
		my($out) = $dta;
		$out =~ s/\.dta$/\.out/;
		my($seqs)  = &getAllSequences($out);
		foreach (split / /, $seqs) {
			print SCORES "$dta $_ $results{$_}\n";
		}
		close SCORES;
	}

	# end the progress bar
	print "</b></pre>\n\n";

	$end = time;
	$duration = $end - $start;

	print qq(<span class="smallheading">Total time: $duration seconds.<br><br></span>);

	#wiite to the log file
	&write_log($dir,"Significance Calculation run " . localtime());

	$lastdir = $dir
 
  }
  # now print the "What do you want to do now?"
  @text = ("View Results in Sequest Summary","run Significance Calculation on another directory","run GBU on this directory");
  @links = ("runsummary.pl?directory=$lastdir&sort=consensus","sigcalc.pl","goodbadugly2.pl?directory=$dir");
  &WhatDoYouWantToDoNow(\@text, \@links);
}



# get_DTA_file_list
# Returns an array of strings which are the names of only those DTA files in the chosen directory that have outfiles
sub get_DTA_file_list{
	opendir DIR , "$seqdir/$dir" or &error("Couldn't open directory $seqdir/$dir");
	my (@outfiles) = grep { (! -z ) && s!\.out$!!i } readdir(DIR);
	my (@DTAlist) = map {$_ . ".dta" } @outfiles;
	closedir DIR;
	return(@DTAlist);
}



#######################################
# Main form subroutines

# note that we're going to take the defaults from GBU, since these two scripts are so closely tied in to one another
sub choose_directory {
	print "<HR>\n";

	&warn_running if( $sig_calcs_running);	
	&get_alldirs;

	#get defaults
	my($checked_water) = $DEFS_SIGCALC{"Water Losses"} eq "yes" ? "checked" : "";
	my($checked_2plus) = $DEFS_SIGCALC{"2+ Ions for 2+ spectra"} eq "yes" ? "checked" : "";
	my($checked_3plus) = $DEFS_SIGCALC{"3+ Ions for 3+ spectra"} eq "yes" ? "checked" : "";
	my($checked_left_isotope) = $DEFS_SIGCALC{"Choose left isotope"} eq "yes" ? "checked" : "";


	print <<EOFORM;

<FORM NAME="Directory Select" ACTION="$ourname" METHOD=get>

<span class="smallheading">Select at least one Directory:
<BR><BR>

	<span class=dropbox><SELECT MULTIPLE size=20 NAME="directory">
EOFORM

	foreach $dir (@ordered_names) {
	      print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
	}

print <<DONE;
</SELECT><BR><BR>

<INPUT type="checkbox" name="append"><span class="smallheading">&nbsp;Append results to existing file</span>

<BR><BR>

<INPUT type="hidden" name="FROM_FRONTPAGE" value="true">

<INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span>
		
<BR><BR><span class="smallheading">Advanced:</span><BR>
	<table bgcolor="#e2e2e2">
		<tr>
			<td align="right"><span class="smallheading">Water Losses:</span></td>
	        <td><input type="checkbox" name="water_losses" $checked_water ></td>
		</tr>
		<tr>
			<td align="right"><span class="smallheading">Choose Left Isotope:</span></td>
	        <td><input type="checkbox" name="left_isotope" $checked_left_isotope ></td>
		</tr>
		<tr>
			<td><span class="smallheading">2+ ion series on 2+ spectra:</span></td>
	        <td><input type="checkbox" name="TWO_PLUS_IONS_ON_TWO_PLUS_SPECTRA" $checked_2plus ></td>
		</tr>
		<tr>
			<td><span class="smallheading">3+ ion series on 3+ spectra:</span></td>
	        <td><input type="checkbox" name="THREE_PLUS_IONS_ON_THREE_PLUS_SPECTRA" $checked_3plus ></td>
		</tr>
		<tr>
			<td align="right"><span class="smallheading">Max rank in outfile:</span></td>
	        <td><input name="max_rank" value="$DEFS_SIGCALC{'Max Rank'}" size=3></td>
		</tr>	
		<tr>
			<td align="right"><span class="smallheading">MH+ Tolerance:</span></td>
	        <td><input name="MHPLUS_TOLERANCE" value="$DEFS_SIGCALC{'MH+ Tolerance'}" size=5></td>
		</tr>	
		<tr>
			<td align="right"><span class="smallheading">Fragment Ion Tolerance:</span></td>
	        <td><input name="FRAGMENT_ION_TOLERANCE" value="$DEFS_SIGCALC{'Fragment Ion Tolerance'}" size=3></td>
		</tr>	
	</table>
</Form></Body></HTML>

DONE
}

#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {

		print <<ERRMESG;
	<HR><p>
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG

	exit 1;
}

sub process_killed {

		print <<ERRMESG;
	<HR><p>
	<H3>Significance Calculation killed by user.</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG

	exit 1;
}



sub javastuff{
	  print <<EOF;
<SCRIPT LANGUAGE="Javascript">
<!--
function kill_sig_calc(dirname)
{
	theurl = "sigcalc_killer.pl?directory=" + dirname;
	killerWindow = window.open(theurl,"killerWindow","width=500,height=320,resizable");
	return(false);
}
//-->
</SCRIPT>
EOF
}

#sees if any other sig calcs are running
sub see_if_running{

	my($num_running) = 0;

	my(@stats) = &get_all_local_status_files();

	foreach  (@stats) {
		my(%info) = &get_status($_);
		$num_running++ if($info{"application"} eq $ourshortname);
	}
	
	return($num_running);
}


sub warn_running{
	my($is_are) = $sig_calcs_running == 1 ? "is" : "are";
	my($s) = $sig_calcs_running == 1 ? "" : "s";
	print "<br><span class='smallheading'>Warning: $sig_calcs_running Significance Calculation" . $s . " " . $is_are . " currently running</span><br>";
}


sub kill_switch{

	$num_kill_switches++;
	$this_kill = "kill_" . "$num_kill_switches";
	$this_killed  = "killed_" . "$num_kill_switches";
	print <<DONE;
	<span id="$this_kill">
	   &nbsp;&nbsp;<span class="smallheading" style="color:red;cursor:hand" onClick="window.open('$webcgi/assasin.pl?pid=$$','_blank'); document.all['$this_kill'].style.display='none'; document.all['$this_killed'].style.display='';">Stop</span>
	</span>
	<span id="$this_killed" style="display:none;">
		&nbsp;&nbsp;<span class="smallheading" style="color:red">Process Killed</span>
	</span>
DONE
}

# End of sigcalc.pl