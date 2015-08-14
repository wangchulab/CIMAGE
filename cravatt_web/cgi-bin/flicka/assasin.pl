#!/usr/local/bin/perl

#-------------------------------------
#	Assassin
#	(C)2002 Harvard University
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
# Description: Kills processes. Meant to be used most often in the kevorkian context of assisted suicide for perl proceses. This takes 
# one cgi-input input, a pid, and it kills that process. So kill switches on any perl page can link to
# assassin.pl Assasin should be linked in a new window. It closes its own window automatically.
#
# For assisted suicide use  <A target="_blank" href="assassin.pl?pid=$$">kill</a> 
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
}



#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$pid = $FORM{"pid"};




#######################################
# Initial output
print <<EOHEAD;
Content-type: text/html
<html>
<head>
<META HTTP-EQUIV="Expires" CONTENT="Tue, 01 Jan 1980 1:00:00 GMT">
<META HTTP-EQUIV="Pragma" CONTENT="no-cache">
<title>Kill PID $pid</title>
$stylesheet_html
$header_tags
</head>

<body onload="javascript:window.close()">
EOHEAD

##########################################
#
#		 Main Action
#

`$cgidir/pskill.exe $pid`; 

print "<h3>Process $pid killed</h3><br></body></html>";



# End of assassin