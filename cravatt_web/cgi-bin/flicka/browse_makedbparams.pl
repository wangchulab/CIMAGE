#!/usr/local/bin/perl

#-------------------------------------
#	Browse MakeDB Params,
#	(C)1999 Harvard University
#	
#	W. S. Lane/P. Djeu
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 7/25/00 by Peter Djeu
#
# Description: This script is set up as a parallel to edit_seqparams.pl, but the params for makedb are
# stored in a different log file and their formats have not been finalized.  Thus, this is a browser
# rather than an editor.
#
# args:
# database - Name of .hdr database
# conserve_space - If true, header is suppressed.  The header is displayed otherwise.


################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}


if ($multiple_sequest_hosts) {
#	&error("<span style=\"color:#cc6add\">MakeDb Params Browser:</span> This feature currently requires multiple Sequest Hosts.");
	require "seqcomm_include.pl";
	$runOnServer = $DEFAULT_MAKEDB_AND_DOWNLOAD_SERVER;
	$ourdbdir = "//$runOnServer/database";
} else {
	$ourdbdir = $dbdir;		# Use local default specified in microchem_include.pl
}

#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;

# Insert default settings of form variables here.  For example:
$database = $FORM{"database"};
$conserve_space = $FORM{"conserve_space"};

#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

# "something" should be any CGI parameter that would signify that the program should
# perform an action instead of printing a form
&output_form unless (defined $database);
&lookup_hdr;

######################################
# Main action
#
# This is where the program does what it's really been conceived to do.
# If you want, you can put this in a subroutine to make flow control simpler

sub lookup_hdr {
	if ($conserve_space) {
		print <<EOF;
Content-type: text/html

<html>
<head>
<title>MakeDb Params Browser</title>
$stylesheet_html
<base target=_top>
</head>
<body bgcolor=#FFFFFF>
EOF
	} else {
		&MS_pages_header("MakeDb Params Browser","#cc6add");
		print "<P><HR><P>\n";
	}

	$logfile = $database . ".log";
	open (LOGFILE, "$ourdbdir/$logfile") or &error("<span style=\"color:#cc6add\">MakeDb Params Browser:</span> $logfile not available on $runOnServer.  You must choose a database with a hdr extension.");
	# Dump contents of header

	while (!(($line = <LOGFILE>) =~ /----- Begin makedb.params file -----/)) {
		# Do nothing
	}

	print "<pre>";
	while (!(($line = <LOGFILE>) =~ /----- End makedb.params file -----/)) {
		print "$line";
	}
	close LOGFILE;

	print <<EOF;
</pre></body></html>
EOF

	exit 0;
}



#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {

	&MS_pages_header("MakeDb Params Browser","#cc6add");
	print "<P><HR><P>\n";

	print <<EOF;
<table cellspacing=2 cellpadding=0 border=0>
<form action="$ourname" method="GET">

<tr><td><span class="smallheading">Database Indexed for Speed:</span>
<td><span class="dropbox"><SELECT NAME="database">
EOF

	# Adapted from microchem_include.pl
	opendir (DBDIR, "$ourdbdir") or &error("can't open $ourdbdir");
	@hdr_db_names = grep { /.fasta.hdr$/ || /FASTA.hdr$/ } readdir (DBDIR);
	closedir DBDIR;

	@hdr_db_names = sort @hdr_db_names;

	foreach $database (@hdr_db_names) {
		print "<OPTION VALUE=\"$database\">$database\n";
	}

	print <<EOF;
</SELECT></span>
</tr>
<tr><td>&nbsp;</tr>
<tr><td><td><input type="submit" class="button" value="Browse"></tr>
</form></table></body></html>
EOF
	exit 0;
}



#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error
{
	print ("<h2>Error:</h2>\n");
	print "<p>$ICONS{'error'}";
	print "$_[0]";
	print "</body></html>\n";
	exit 1;
}
