#!/usr/local/bin/perl

#-------------------------------------
#	Install IELaunch,
#	(C)1999 Harvard University
#	
#	W. S. Lane/Scott Ruffing
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


#This program should be run only by an administrator of the system.  It updates the files
#neccessary for the IELaunch program to properly run.  These updated files are then ran on each users
#local computer using a link that goes to a batch file.  

################################################
# Created: 03/04/03 by Scott Ruffing
# Last Modified: mm/dd/yy by Name of Modifier
#
# Description: 
#

use strict;
use vars qw(%FORM $server $cgidir $webetc $etcdir $webserver %DEFS_IELAUNCH);

#####################################
# Require'd and use'd files
# microchem_include.pl, and others if necessary (e.g. fastaidx_lib.pl, microchem_db.pl)



################################################
# find and read in standard include file
BEGIN {
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "javascript_include.pl";
}

my $dir_launch_loc = $DEFS_IELAUNCH{"Launch Dir Location"};
my $server_launch_loc = $dir_launch_loc;
$server_launch_loc =~ s/\w:(.*)/\\\\$webserver$1/;

my $regfile = "$dir_launch_loc/perldoc_stored.reg";
my $regfile_formed = "$dir_launch_loc/perldoc.reg";

my $batfile = "$dir_launch_loc/perldocsetup_stored.bat";
my $batfile_formed = "$dir_launch_loc/perldocsetup.bat";

my $TITLE = "Internet Explorer Launcher";

#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;

output_form();

exit;

update_setup_files();

# Need a couple of things here

# Update the registry files and the batch file to use current webserver locations

sub output_form {
	MS_pages_header($TITLE);
	print "<HR><BR><DIV>";

	update_setup_files();
}

sub update_setup_files {
	update_registry_file();
	update_batch_file();

	my ($text, $link) = create_install_link();

	print "<BR>$text<BR>$link<BR>";

	my ($testtext, $testlink) = test_link();
	print "$testtext<BR>$testlink<BR>";
	print "<BR>If notepad.exe opened up in your browser with a .bat file opened in it after selecting the link " .
		  "above, then you have properly installed the IELaunch program.<BR>";

	print "<BR><HR><BR>The IELauncher program was created by http://www.whirlywiryweb.com/<BR>"; 
}


sub replace_placeholder {
	my ($file, $newfile, $placeholder, $newword) = @_;

	# Open the registry file
	if (! -e $file) {
		Message->error(Message::IOERROR_FILEMISSING, "$file");	
	} else {
		open (REGISTRYFILE, "<$file") || Message->error(Message::IOERROR_OPEN, $file);
	}

	# Now try to open where we will write to
	open (STOREDFILE, ">$newfile") || Message->error(Message::IOERROR_WRITE, $newfile);

	# Read in the whole file as one string
	local $/;
	my $text = <REGISTRYFILE>;

	# Replace the placeholder with the name of the webserver
	$text =~ s/$placeholder/$newword/g;
	
	# Now write the new file
	print "Creating $newfile on $webserver<BR>";
    print STOREDFILE "$text";
}	

sub update_registry_file {
	replace_placeholder($regfile, $regfile_formed, "__WEBSERVER__", $server);
}


sub update_batch_file {
	replace_placeholder($batfile, $batfile_formed, "__LAUNCHLOCATION__", "$server_launch_loc");
}
	

sub create_install_link {
	my $associatedText = "This link will install a DLL and a registry file onto your local computer. " .
		"After this link is clicked, a Windows File Download box will appear and ask you to Open, " .
		"Save, Cancel, or More Info.  Selecting Open will cause a batch file to run. This batch file will " .
		"first install the dll and wait for you to press Ok.  Then it will ask if you want to install a registry " .
		"file.  Select Yes and then a box will open saying if it was successful or not, select Ok at this point. " .
		"When finished, the Test IELaunch link should " .
		"open the batch file using Notepad.exe on your local computer.";
	
	my $link = qq!<A HREF="$server_launch_loc\\perldocsetup.bat">Install DLL and Registry Key</A><BR>!;
	return ($associatedText, $link);
}

sub test_link {
	my $associatedText = "In order for this link to work, IELaunch must first be installed onto your local " .
					  "computer.  This requires you to run a batch file on your webserver to properly " .
					  "install a DLL file and a registry key.";
	
	&loadJavascriptClientLauncher();

	# Make the testfile have additional \'s so they are escaped properly
	my $testfile = $server_launch_loc . "\\perldocsetup.bat";
	$testfile =~ s/\\/\\\\/g;

	my $link = qq!<A HREF="javascript:launchApp('notepad.exe $testfile')">Test launchApp</A>!;		
	return ($associatedText, $link);
}



# Give a link or auto-redirect user to the batch script that will install the registry and copy the dta




