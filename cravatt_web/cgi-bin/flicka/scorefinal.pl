#!/usr/local/bin/perl

#-------------------------------------
#	Final Score 
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
# Description: Combines the various sequest scores into one.
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
	require "scorefinal_include.pl";
}

# first, figure out if we're being run from the command-line or via CGI

my $via_cgi = 1;

for $i (0 .. $#ARGV) {
	if ($ARGV[$i] eq "noui") {
		$via_cgi = 0;
	} elsif ($ARGV[$i] eq "dir") {
		$dir = $ARGV[$i+1];
	} 
}

if ($via_cgi) {

	#######################################
	# Fetching data
	#
	# This includes, CGI-receive, database lookups, command line options, etc.  
	# All data that the script exports dynamically from the outside.


	&cgi_receive;
	$dir = $FORM{"directory"};


	#######################################
	# Initial output
	&MS_pages_header("Final Score","#871F78");

	#######################################
	# Flow control
	if (!defined $dir) {
		&choose_directory;
	} else {
		&main;
	}
} else {
	if (!$dir) {
		die "no directory specified";
	}
	&main;
}

exit 1;

######################################
# Main action

sub main{

	if ($via_cgi) {
		print "<hr><p>";
	}

	chdir "$seqdir/$dir" or print "Cannot change CWD to $seqdir/$dir!!!\n"; 
	opendir (DIR, ".") or print "Cannot open $dir!!!\n";
	@current_outs = grep { (! -z ) && s!\.out$!!i && ($current_mtime{$_}=(stat("$_.out"))[9])} readdir(DIR);
	closedir DIR;

	&process_outfiles();
	&make_input_table();

	$result = classify($dir);
	
	if ($via_cgi) {
		print "<span class='smallheading'>Completed scoring directory $dir.</span><br>";
	}

	#clean up temporary file
	unlink "$ScoreCombinerTableFile";

	#wiite to the log file of the directory
	&write_log($dir,"Final Score run " . localtime());

	if ($via_cgi) {
		# now print the "What do you want to do now?"
		@text = ("View Results in Sequest Summary","Go to good-bad-ugly","Run Seqest","View Info");
		@links = ("runsummary.pl?directory=$dir&sort=consensus","goodbadugly2.pl","sequest_launcher.pl","view_info.pl?directory=$dir");
		&WhatDoYouWantToDoNow(\@text, \@links);
	}
}



#######################################
# Subroutines for output
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

<TR><TD>
	<TD><INPUT type="submit" class="button" value="Score Directory">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></TD>
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


# End of scorefinal.pl