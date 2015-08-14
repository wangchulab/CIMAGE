#!/usr/local/bin/perl

#-------------------------------------
#	lcq_profile.txt Repair,
#	(C)1999 Harvard University
#	
#	W. S. Lane/R. H. Dezube
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 03/03/02 by Rebecca Dezube
# Last Modified: 
#
# Description: This script adds any missing .dta file info to the lcq_profile.txt file associated
#              with each Sequest directory
#


#####################################
# Require'd and use'd files
# microchem_include.pl, and others if necessary (e.g. fastaidx_lib.pl, microchem_db.pl)

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
################################################
### Additional includes (if any) go here

use strict;

use vars qw(%FORM $seqdir %DEFS_LCQ_PROFILE_REPAIR $ourname @ordered_names %fancyname); 
#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
&MS_pages_header("Lcq_Profile Repair","#871F78");
print "<hr><br>\n";


#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;

# Insert default settings of form variables here.
my $dir = $FORM{"directory"};

# User has option of deleting old lcq_profile.txt and deleting profile entries which do not
# have corresponding dtas
my $createnew = $FORM{"CreateNew"};
my $deleteunused = $FORM{"DeleteUnused"};

my $nooldfile;


#######################################
# Flow control
#
# Here is where the program decides, on the basis of whatever input it's been given,
# what it should do

&get_alldirs;

if (!defined $dir) {
	&output_form;
} else  {
	&backup;
}
exit 1;


######################################
# Main action

 
sub repair () {
# Adds necessary .dta entries to array of entries, remove unnecessary ones if option is selected

my ($lcq_header, @lcq_profile_arr) = @_;

# Set directory
my $cwd = "$seqdir/$dir/";
chdir $cwd or &error("Could not open the selected directory. $!\n");

# Get all .dta files, sort them in order
opendir CURR_DIR, '.' or &error("Could not open the selected directory. $!\n");
	my @dta_files = sort grep /dta$/, readdir CURR_DIR;
	closedir CURR_DIR;

# Keep track of deleted dtas to tell user
my @dtas_deleted;

# If option is selected, delete unnecessary entries from profile array (which don't have
# a corresponding .dta file)
if ($deleteunused eq "yes") {
	for (my $i = 0; $i < @lcq_profile_arr + 0; $i++) {
		my $j = 0;
		until (($lcq_profile_arr[$i] =~/$dta_files[$j]\s/) or ($j == @dta_files + 0))  {
			$j++;
		}
		# no match
		if ($j == @dta_files + 0) {
			my @temp = split ' ', $lcq_profile_arr[$i];
			push @dtas_deleted, $temp[0];
			splice (@lcq_profile_arr, $i, 1) . "\n";
			$i--;
		}
	}
}

# Keep track of added dts to tell user
my @dtas_added;
# For each entry in dta array, look for corresponding entry in profile array, and
# if not present, add new entry
foreach my $dta (@dta_files) {
	my $i = 0;
	until (($lcq_profile_arr[$i] =~/$dta\s/) or ($i == @lcq_profile_arr + 0)) { 
		$i++;
	}
	#no match
	if ($i == @lcq_profile_arr + 0) {
		@lcq_profile_arr = &add_new_entry ($dta, @lcq_profile_arr);
		$dtas_added[@dtas_added + 0] = $dta;
	}
}


# output array to lcq_profile.txt
open NEW_LCQ, ">lcq_profile.txt" or &error("Unable to write to lcq_profile.txt. $!\n");
	print NEW_LCQ $lcq_header;
	foreach my $line (sort @lcq_profile_arr) {
		print NEW_LCQ $line;
	}
close NEW_LCQ;

# print the output information
&print_success(\@dtas_added, \@dtas_deleted);

exit 0;
}

#######################################

sub backup {

# Copy contents of lcq_profile.txt to lcq_profile.previous.txt, including creating both files
# if no lcq_file exists
# Also reads contents of file into array, one array entry for each line not including the header
# If user wishes to recreate file from scratch, no entries are put in array

my $cwd = "$seqdir/$dir/";
chdir $cwd or &error("Could not open the selected directory. $!\n");
my @lcq_profile_arr;
open LCQ_PROFILE, "<lcq_profile.txt" or &create_lcq;
if ($nooldfile ne "true") {
	open LCQ_OLD, ">lcq_profile.previous.txt" or &error("Unable to backup lcq_profile.txt. $!\n");
}
my $i = 0;
my $lcq_header = <LCQ_PROFILE>;
print LCQ_OLD $lcq_header;
while (my $line = <LCQ_PROFILE>) {
	if ($nooldfile ne "true") {
		print LCQ_OLD $line;
	}
	if ($createnew ne "yes") {
		# Don't store in array if recreating from scratch
		$lcq_profile_arr[$i] = $line;
	}
	$i++;
}
if ($nooldfile ne "true") {
	close LCQ_OLD;
}
close LCQ_PROFILE;
&repair ($lcq_header, @lcq_profile_arr);
}


sub create_lcq {
# creates an lcq_profile.txt if one did not exists, outputs header to it

open LCQ, ">lcq_profile.txt" or &error("Unable to create lcq_profile.txt. $!\n");	
print LCQ "Datafile FullScanSumBP FullScanMaxBP ZoomScanSumBP ZoomScanMaxBP SumTIC MaxTIC\n";
close LCQ;
open LCQ_PROFILE, "<lcq_profile.txt" or error("lcq_profile.txt not created correctly. $!\n");
$nooldfile = "true";
}


sub add_new_entry ($dta, @lcq_profile_arr) {
my ($dta, @lcq_profile_arr) = @_; 
# computes TIC value from .dta file, adds an entry for the .dta file into the array with
# 0's for the other values

my $cwd = "$seqdir/$dir/";
chdir $cwd or &error("Could not open the selected directory. $!\n");
open DTA, $dta or &error("Can't open .dta file");
my $TIC = 0;
#compute TIC

my $line = <DTA>;  #ignore first line
while ($line = <DTA>) {
	my @temp = split ' ', $line;
	$TIC += $temp[1]; 
}

$TIC = int $TIC;

# add new entry to array
push @lcq_profile_arr, $dta . " 0 0 0 0 " . $TIC . " " . $TIC . "\n";

return (@lcq_profile_arr);
}

sub print_success {

# Print the output information including names of files modified and deleted,
# and dta entries added

# Get information out of passed list
my ($ref1, $ref2) = @_;
my @dtas_updated = @$ref1;
my @dtas_deleted = @$ref2;
my $last_dta1 = pop @dtas_updated;
my $last_dta2 = pop @dtas_deleted;

# Begin printing
print <<EOM;
	<p>
	<div class="normaltext">

	<image src="/images/circle_1.gif">&nbsp;Profile repair of <a href=\"/sequest/$dir/lcq_profile.txt\" target = \"profilewin\">lcq_profile.txt</a> was successful in $fancyname{$dir}.
	<br>
	<br>
EOM

if ($nooldfile eq "true") {
	print ("<span class=\"smallheading\">File </span>lcq_profile.txt <span class=\"smallheading\"> did not previously exist, was created</span><br><br>");
}
else {
	print ("<span class=\"smallheading\">Back-up file </span><a href=\"/sequest/$dir/lcq_profile.previous.txt\" target = \"previouswin\">lcq_profile.previous.txt</a><span class=\"smallheading\"> was created</span><br><br>");
}



if ($createnew eq "yes") {
		print ("<span class=\"smallheading\">File </span>lcq_profile.txt <span class=\"smallheading\">was recreated from scratch</span><br><br>");
}

if ($last_dta1) {
	print ("<span class=\"smallheading\">The follwing dta entries were added to lcq_profile.txt: <br></span>");
	foreach my $dta (@dtas_updated) {
		print $dta . ", ";
	}
		print $last_dta1;
}
else {
	print ("<span class=\"smallheading\">No dtas needed to be added.</span>");
}

if ($deleteunused eq "yes") {
	if ($last_dta2) {
		print ("<br><br><span class=\"smallheading\">The follwing dta entries were deleted from lcq_profile.txt in $dir:<br></span>");
		foreach my $dta (@dtas_deleted) {
			print $dta . ", ";
		}
			print $last_dta2;
    }
	else {
		print ("<br><br><span class=\"smallheading\">There were no dta entries to delete in lcq_profile.txt.</span>");
	}
}

my @text = ("Sequest Summary", "View Directory Info","Run Sequest","Create DTA","View DTA Chromatogram");
my @links = ("runsummary.pl?directory=$dir&show=consensus","view_info.pl?directory=$dir","sequest_launcher.pl","create_dta.pl","dta_chromatogram.pl");
&WhatDoYouWantToDoNow(\@text, \@links);


}



#######################################
# Main form subroutine
# this may or may not actually printout a form, and in a few (very few) programs it may be unnecessary
# it should output the default page that a user will see when calling this program (without any particular CGI input)
sub output_form {

my %checked;
$checked{"deleteunused"} = " CHECKED" if ($DEFS_LCQ_PROFILE_REPAIR{"Delete entries without corresponding DTA files"} eq "yes");
$checked{"createnew"} = " CHECKED" if ($DEFS_LCQ_PROFILE_REPAIR{"Recreate lcq_profile.txt from scratch"} eq "yes");

# Javascript confirmation box --confirms that someone wants to recreate lcq_profile
print <<EOJAVA;
	<SCRIPT LANGUAGE="JavaScript">
	<!--
	function checkConfirm() {
		if (Main_Form.CreateNew.checked == false) {  // only confirm if (not backing up) 
			return(true)
		}
		else {
			response=confirm("You will lose data if you select this option. Are you sure?")
			if (response == false) {
				this.focus()   // shift focus back to the window rather than the check button
				return (false) // cancel the checking
			} else {
				return(true)   // returns a value of true to the checkbox and keeps the value checked
			}
		}
	}

//Javascript function to view lcq_profile.txt, when clicked
	function openFile() {
		filename = Main_Form.directory.options[Main_Form.directory.selectedIndex].value;
		filename= "/sequest/" + filename + "/lcq_profile.txt";
		window.open(filename, "newwin");
		return false;
	}	
	//-->
	</SCRIPT>
EOJAVA



print <<EOFORM;
<div>

<FORM NAME="Main_Form" ACTION="$ourname" METHOD=GET>
<TABLE>
<TR ALIGN=LEFT>
<TH><span class="smallheading">Directory with lcq_profile.txt to repair:</span></TH>
</TR>

<TR>
<TD><SPAN CLASS=dropbox><SELECT NAME="directory">

EOFORM

  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

print <<EOFORM;

</SELECT></SPAN>
&nbsp;


<span class="smallheading"><A HREF="" onClick= "return openFile()"> View</A></span>
</TD></TABLE>

<br>

<INPUT TYPE=checkbox NAME="DeleteUnused" VALUE="yes"$checked{'deleteunused'}>
<span class="smallheading">Delete entries without corresponding DTA files</span> 

<br>

<INPUT TYPE=checkbox NAME="CreateNew" VALUE="yes"$checked{'createnew'} ONCLICK="return checkConfirm()">
<span class="smallheading">Recreate lcq_profile.txt from scratch</span>


<br><br>
&nbsp;&nbsp;&nbsp;&nbsp;
<INPUT TYPE=SUBMIT CLASS=button VALUE="Repair!">
&nbsp;&nbsp;&nbsp;&nbsp;
<span class="smallheading"><A HREF="/Help/help_lcq_profile_repair.pl.html">Help</A></SPAN></TD>
</FORM>
</div>
EOFORM
}



#######################################
# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {

	print <<ERR;

<H3>Error:</H3>
<div>
@_
</div>
</body></html>
ERR

	exit 0;
}

# end of lcq_profile_repair.pl