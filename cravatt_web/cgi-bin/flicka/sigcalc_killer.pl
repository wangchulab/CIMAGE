#!/usr/local/bin/perl

#-------------------------------------
#	View GBU Stats
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
# Description: Calculates and displays stats on GBU summary
#



################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "microchem_form_defaults.pl";
	require "goodbadugly_include.pl";
}



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};


if($percentType eq "total"){
	$checked_total = "checked";
}elsif($percentType eq "row"){
	$checked_row = "checked";
}elsif($percentType eq "column"){
	$checked_column = "checked";
}elsif($percentType eq "cell"){
	$checked_cell = "checked";
}

if($content eq "TIC"){
	$checked_TIC = "checked";
}elsif($content eq "count"){
	$checked_count = "checked";
}


#######################################
# Initial output
print <<EOHEAD;
Content-type: text/html
<html>
<head>
<META HTTP-EQUIV="Expires" CONTENT="Tue, 01 Jan 1980 1:00:00 GMT">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<title>Kill Significance Calculation</title>
$stylesheet_html
$header_tags
</head>

<body onload="javascript:window.close()">
EOHEAD

##########################################
#
#		 Main Action
#

$sig_calc_lock_file = "sig_calc.lock";
unlink "$seqdir/$dir/$sig_calc_lock_file";

print "Hecho ya. Hemos asesinado la programa esta.<br>";

	



#######################################
# Main form subroutines

# note that we're going to take the defaults from GBU, since these two scripts are so closely tied in to one another
sub choose_directory {
	print "<P><HR>\n";

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


# End of view_gbu_stats