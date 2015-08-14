#!/usr/local/bin/perl

#-------------------------------------
#	RAW Copier aka Painful Mimic,
#	(C)2000 Harvard University
#	
#	W. S. Lane/Paul McDonald
#
#	v3.1a
#	
#-------------------------------------



################################################
# Created: 06/09/00 by Paul
# Last Modified: 06/16/99 by Paul
#
# Description: Allows copying of .RAW files from
#              from instrument data directories
#			   to the web servers data dir.
################################################

# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}

if ($multiple_sequest_hosts){
   require "raw_include.pl";           #contains list of LCQ hosts, and copy function
} else {
	die "ERROR: Need multiple sequest hosts to run this program."
}
require "stringlist_include.pl";    #string manipulation functions for multi-select form element data

#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
$accent_color = "#2e8b57";

&MS_pages_header ("Painful Mimic",$accent_color, "tabvalues=Painful Mimic&$LCQPagesLinksStr");

print "<p>\n";
print "<div class=\"HarvardMicrochem\">";

#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;

$lcqdir_label = $ENV{"COMPUTERNAME"};
$lcqdir_label =~ tr/A-Z/a-z/;
$lcqdir_label =  ucfirst ($lcqdir_label);
$lcqdir_label = $lcqdir_label . " (Server)";

$lookindir = $FORM{"lookindir"};       # Directory to read from
$filetocopy = $FORM{"filetocopy"};     # File to copy to webserver data dir


if (defined $FORM{"remote_server"}) {
	$remote_server = $FORM{"remote_server"};      # Current computer we are looking at
} else {
	$remote_server = $sources[0];
}

if ($FORM{"submission_by_radio"} eq "true" || !defined $FORM{"lookindir"}) {
	$lookindir = $remote_server;
}

&addJS;

#######################################
# Fetching defaults values
#
# for parameters that are not supplied in CGI input (the %FORM hash),
# you should get the default values from microchem_form_defaults.pl via microchem_include.pl
# for example:




#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

# "something" should be any CGI parameter that would signify that the program should
# perform an action instead of printing a form
&output_form unless (defined $FORM{"docopy"} || defined $FORM{"del_from_server"});


######################################
# Main action
#
# This is where the program does what it's really been conceived to do.
# If you want, you can put this in a subroutine to make flow control simpler

# Here is where we actually do the copying or deleting (to/from Server)

@source_files = GetListFromString($filetocopy);

if (defined $FORM{"del_from_server"}) {
	foreach $dead_file (@source_files) {
		my $result = unlink ("$dead_file");      #Deletes the file from the Server
		if ($result) {
			print "$dead_file deleted successfully from Sequest's default RAW data directory <br>";
		} else {
			print "ERROR: could not delete $dead_file<br>";
		}
	}	
} else {  # Copy files
	foreach $src_file (@source_files) {
		my $result = copy_raw_to_server("$src_file");      #Copies the file to the proper destination
		if ($result) {
			print "$src_file copied successfully to Sequest Browser's default RAW data directory <br>";
		} else {
			print "ERROR: could not copy $src_file<br>";
		}
	}
}

@links = ("$ourname", "$setupdirs", "$lcq_prelude");
@text = ("Back to Painful Mimic", "Setup", "Prelude");

WhatDoYouWantToDoNow(\@text,\@links);

exit 0;

#######################################
# subroutines (other than &output_form and &error, see below)


# Based on the scalar $src, gets a list of directories (contained in $src) and subdirectories, putting them all
# in one list.  Only goes down one level (that's all we need for now).

sub get_directories {     
	my @dirlist;

	push (@dirlist, $remote_server);
	$! = "";
	opendir (CURRENT, "$remote_server");
	if ($! ne "") {
		return;
	}
	my @allfiles = readdir CURRENT;
	closedir CURRENT;
	foreach $file (@allfiles) {
		if (-d "$remote_server/$file" && ($file ne "." && $file ne "..")) {
			push (@dirlist, $remote_server . "/" . $file);
		}
	}
	return @dirlist
}

# Searches through the specified directory, making a list of all the *.RAW files in the directory.
# NOTE: This is case senstitive

sub get_raws {
	my @rawlist;

	opendir (CURRENT, "$lookindir");
	my @allfiles = readdir CURRENT;
	
	closedir CURRENT;
	foreach $file (@allfiles) {
		$this_ext = GetExtension($file);
		$this_ext =~ tr/a-z/A-Z/;
		if ($this_ext eq "RAW") {	
			push (@rawlist, $lookindir . "/" . $file);
		}
	}
	@rawlist = sort byage @rawlist;
	return @rawlist 
}	

#Sort function from protocols.pl

sub byage {
#print "sorting function: comparing $a and $b<br>\n";
	-M("$a") <=> -M("$b")
		or
	lc($a) cmp lc($b);
}

sub get_computer_name {
	my $pathname = shift @_;
	my @pathparts = split(/\/|\\/,$pathname);
	my $name_string = @pathparts[-3] . " (" . @pathparts[-2] . ") ";
	return $name_string;
}


###################################################

sub addJS {
	print <<EOF;
<script language="Javascript">
<!--

function new_remote(name)
{
	
	document.dirform.remote_server.value = name;
	document.dirform.submission_by_radio.value = true;
	document.dirform.submit();
}

//-->
</script>

EOF
}


#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {

    #first show directory list
	@mydirs = &get_directories();

# This segment prints out the form for selecting a directory to look in.  There are two seperate forms
# to make it easier for the user to choose between changing directories and selecting a file to copy.

	print <<EOF;
<form name="dirform" action="$ourname" method="get">
<input type=hidden name=submission_by_radio value=false>
<table cellspacing=8 border=0>

<tr>
  <td align=right>
    <span class="smallheading"> Remote instruments: </span>
  </td>
  <td align=left colspan=4>
  <b><span style=color:$accent_color>
EOF

foreach $server (@sources) {
	my $comp_name = &get_computer_name($server);
	if ($server eq $remote_server) {
		$selected = " CHECKED";
	}
	print "<input type=radio name=remote_server value=$server$selected onclick='Javascript:new_remote(this.value)'> $comp_name &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
	$selected = "";
}

# Added by SDR on 11/05/01 for QTOFMimic
foreach $server (@sequestSources) {
	my @pathparts = split(/\/|\\/,$server);
	my $comp_name = @pathparts[-3] . " (" . QTF . ") ";
	if ($server eq $remote_server) {
		$selected = " CHECKED";
	}
	print "<input type=radio name=remote_server onclick='location = \"$qtofmimic\"'> $comp_name &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
	$selected = "";
}

$selected = ($weblcqdir eq $remote_server) ? " CHECKED" : "";
print <<EOF;
  </span><input type=radio name=remote_server value=$weblcqdir$selected onclick='Javascript:new_remote(this.value)'><span style="color:888888"> $lcqdir_label </span>
  </b>
  </td>
</tr>
EOF

if ($! ne "") {
	$comp_name = get_computer_name($remote_server);
	print <<EOF;
<tr><td></td>
<td>
<span style=color:#ff0000>
Could not connect to remote instrument $comp_name.  Please select a new instrument. <br>
The following error(s) were returned: <br>
$! <br>
</td>
</tr>
</table>
EOF
	exit;
}

if ($remote_server ne $weblcqdir) {
print <<EOF;
<tr align=left valign=top>

<td align=right> 
  <b><span class=smalltext> Directory to copy from: </span></b>
</td>
<td colspan = 2>
<span class=dropbox>
<select name="lookindir" onchange=submit()>
EOF
	foreach $dir (@mydirs) {
		if ("$dir" eq "$lookindir") {
			print "<option value=\"$dir\" selected> $dir\n";
		} else {
			print "<option value=\"$dir\"> $dir\n";
		}
	}	
	print <<EOF;
</select>
</td>
EOF
}

if ($lookindir eq "") { 
	print " &nbsp;&nbsp;<a href=\"$webhelpdir/help_$ourshortname.html\">Help</a></span></form></td></tr>\n";
} else {
	print "</span></form></td></tr>\n";
}

# If a directory has already been selected, we print out the dropdown box showing the list
# of files in that directory.  If there are no files, an appropriate message is displayed instead.

	if ($lookindir ne "") {
		@myfiles = &get_raws();              # get a list of the files

		if ($#myfiles == -1) {               # in this case, there were no files found
			print <<NOFILES;
<tr> <td></td>
<td align=left>
<span style="color:#ff0000">
<p>This directory contains no .RAW files
<br>Please choose a new directory
</span>
</td>
<td align=left>
<a href="$webhelpdir/help_$ourshortname.html">Help</a>
</td>
</tr>

NOFILES
		} else {                             # Display the files in a dropdown list
		
			print <<FILES;

<tr align=left valign=top>
<form name="rawform">
<td align=right valign=top>
FILES
if ($remote_server ne $weblcqdir) {
print <<FILES;
  <span class=smallheading> Select RAWfile(s): </span>
  <p>
  <input type=submit class=button value=\"Copy to Server\">
  </p>
FILES
} else {
print <<ON_SERVER;
  <span class=smallheading> Select RAWfile(s): </span>
  <p>
  <input name=del_from_server type=submit class=button value=\"Delete\">
  </p>
  </td><td>
ON_SERVER
}
print <<FILES;
</td>
<td rowspan=2 colspan=2>

<input type=\"hidden\" name=\"docopy\" value=\"true\">
<span class=dropbox><select name=\"filetocopy\" size=12 multiple>
FILES


			foreach $file (@myfiles) {
				$filesize = int((-s $file) / 1000) + 1;
				$short_filename = &GetFilename($file);
				$display = $short_filename . "  &nbsp;&nbsp;$filesize K &nbsp;&nbsp; ";

