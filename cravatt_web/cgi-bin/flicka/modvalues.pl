#!/usr/local/bin/perl

#-------------------------------------
#	Mod values selector,
#	(C)1999-2002 Harvard University
#	
#	W. S. Lane/R. H. Dezube
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------

##This is a development file until you change this tag.  Before doing so,
##see an administrator
##RELEASE_FILE##

# Displays list of modifications from modvalues.txt, lets user select one which is returned to program which opened selector

# Created: 10/18/02 by Rebecca Dezube

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
	require "status_include.pl";
	require "html_include.pl";
}

use strict;
use vars qw($etcdir $ourname $webimagedir %FORM); 

# Get data (only present if form was submitted)
&cgi_receive;
my $isediting = $FORM{"editing"};
my $savedata = $FORM{"save"};
my $data = $FORM{"data"};

# Initially set by parent window to no, so we can distinguish between opening up the page as a pop-up and opening it
# stand-alone.  In the latter case, it should only be editable
my $editonly = $FORM{"editonly"};

# Default values
$isediting = "No" unless (defined $isediting);
$savedata = "No" unless (defined $savedata);
$editonly = "yes" unless (defined $editonly);


######################################
# Main action

my %symbols;		# Associates modification name with symbol
my %diffmodints;	# Associates modification name with integer portion of modification
my %diffmoddecs;	# Associates modification name with decimal portion of modification
my %diffmodvalues;	# Associates modification name with modification
my $filename;		# Name of file with values
my $appendname;		# Name of file with append character in front
my $temp;			# Line of the file
my ($name, $symbol, $value);	# The values for a modificaiton
my ($integer, $decimal);		# Splitting values around a decimal for modification


# Check to see if directory exists, and if not, create it (make sure what exists is a directory and not a file)
$filename = "$etcdir/defaults";
if (!(-e $filename) || !(-d $filename)) {
	mkdir $filename;
}
# Check if filename exists and if not create it
$filename = "$etcdir/defaults/modvalues.txt";
$appendname = ">" . $filename;
if (!(-e $filename)) {
	open (FILE, $appendname) or &error("Could not create file $filename");
	close FILE;
}


# We may need to save the data if we just edited it
if ($savedata eq "Yes") {
	open (OUTPUT, $appendname) or &error("Could not open file $appendname");
	# convert the ^M^J line separators to Unix style ^J
	$data =~ s!\015\012!\012!g;
	print OUTPUT $data;
	close OUTPUT;
}


# Open the modvalues.txt file and read the contents into hashes
# Format should be NAME,SYMBOL,VALUE  (SYMBOL is optional, if no symbol should be NAME,,VALUE)
open (INPUT, $filename) or &error("Could not open file $filename");

# Store input into hash based on name of modification (b/c not all have symbols)
# Also store input into $data so we can display to text area if editing
$data = "";
while ($temp = <INPUT>) {
	if ($temp eq "\n") {
		next;
	}
	$data .= $temp;
	($name, $symbol, $value) = split(',', $temp);
	$symbols{$name} = $symbol;
	chomp $value;
	# split around decimal point
	if ($value =~ /\d+\.\d+/) {
		($integer, $decimal) = split(/\./, $value);
	}
	else {
		$integer = $value;
		$decimal = "00";
	}
	$diffmodints{$name} = $integer;
	$diffmoddecs{$name} = $decimal;
	$diffmodvalues{$name} = $value;
}
close INPUT;

# Display the form
# output_form is the main output form with either an edit interface or a selector interface
# finished_form displays if the page was opened as a stand-alone and the data has been entered, it tells
# the user the data was succesfully submitted

if ($editonly eq "yes" && $savedata eq "Yes") {
	&finished_form;
}
else {
	&output_form;
}

exit 0;



##PERLDOC##
# Function : output_form
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : This is the form everyone sees when the window is editable or in selector mode
# Notes    : Page can be opened as pop-up or stand-alone, and if pop-up in edit or selector mode
##ENDPERLDOC##
#######################################
# Main form subroutine
sub output_form {
	
	# Get data for form into strings
	my $header = &CreateHeader();
	my $javascript = &CreateJava();
	
	my $title = <<EOTITLE;
		<span id=\"symbol\" innerText=\"\"></span>
		<SCRIPT LANGUAGE=\"JavaScript\"><!--";
		if (opener && document.mainform.editing.value == \"No\") {
			\tdocument.all.symbol.innerText = \"Click description to assign \" + window.opener.whichSymbol;
		}
		else {
			document.all.symbol.innerText = \"Description, (AA), DiffMass:\";
		}
		//-->
		</SCRIPT>
EOTITLE
	my $tableheading = &create_table_heading(title=>$title);
	my $body1 = &CreateBody1($tableheading);


	# Print the form headers, only print MSPage Header if stand only
	if ($editonly eq "yes") {
		&MS_pages_header("Differential Modifications Editor","#8800FF");
		print "<hr>";
	}
	else {
		print "Content-type: text/html\n";
		print "\n<HTML><HEAD><TITLE>Modifications</TITLE>";
	}

	# Print the form
	print <<EOF;
	$header
	$javascript
	</HEAD>
	<BODY>
	<FORM NAME="mainform" METHOD="POST" ACTION="$ourname" style="margin-top:0; margin-bottom:0" onReset="resetAll()">
	<INPUT TYPE=hidden NAME="editing" VALUE=$isediting>
	<INPUT TYPE=hidden NAME="save" VALUE=$savedata>
	<INPUT TYPE=hidden NAME="editonly" VALUE=$editonly>
	<TABLE width=100%><TR>
	$body1
	</BODY></HTML>
EOF
}


##PERLDOC##
# Function : finished_form
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : Outputs the form when the stand-alone has saved data
# Notes    : 
##ENDPERLDOC##
sub finished_form {
	
	&MS_pages_header("Mod Values","#8800FF");

	print <<EOF;
	<HR>
	<BR>
	<div><b>Modifications Successfully Saved</b></div>

EOF
	my @text = ("Run Sequest", "Home");
	my @links = ("sequest_launcher.pl","intrachem.html");
	&WhatDoYouWantToDoNow(\@text, \@links);
}

##PERLDOC##
# Function : CreateHeader
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : Returns the headers for the output_form
# Notes    : 
##ENDPERLDOC##

sub CreateHeader() {
	my $header = <<EOF;
		<link rel="stylesheet" type="text/css" href="/incdir/intrachem_theme.css">
		<link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
		<link rel="stylesheet" type="text/css" href="/incdir/intrachem_ie.css">
		<style type="text/css">
		td.pagetitle {
			font-family:Arial;
			font-size:16pt;
			font-weight:bold;
		}
		td.data {
		padding:1px 0px;
		}
		</style>
EOF
	return $header;
}

##PERLDOC##
# Function : CreateJava
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : Returns the java for output_form
# Notes    : 
##ENDPERLDOC##

sub CreateJava {

	my $key;		# For iterating through hash
	my $javascript;
	$javascript = <<EOJAVA;
	<SCRIPT LANGUAGE="JavaScript"><!--
		function Selector(key) {
EOJAVA
	
	# Hard code in function.  For each possible modification prints an if clause to return the values for that modification to the opener.
	# Note that if there is no symbol/AA value for a modification, a space is returned for that mod.
	
	foreach $key (keys %diffmodvalues) {
		if (!defined $symbols{$key} || $symbols{$key} eq "") {
			$javascript .= "if (key == '$key') { opener.AA = \" \"; opener.DiffMods = '$diffmodvalues{$key}'; }\n";
		}
		else {
			$javascript .= "if (key == '$key') { opener.AA = '$symbols{$key}'; opener.DiffMods = '$diffmodvalues{$key}'; }\n";
		}
	}

	# Call opener function to assign variables to appropriate field, close window
	$javascript .= <<EOJAVA;
			opener.populatefields();
			self.close();
		}
		function  Edit() {
			document.mainform.editing.value = "Yes";
			document.mainform.save.value = "No";
			if (opener) {
				document.mainform.editonly.value = "no";
			}
			document.mainform.submit();
		}
		function  Save() {
			document.mainform.editing.value = "No";
			document.mainform.save.value = "Yes";
			if (opener) {
				document.mainform.editonly.value = "no";
			}
			document.mainform.submit();
		}
		function cancelEdit() {
			document.mainform.editing.value = "No";
			document.mainform.save.value = "No";
			if (opener) {
				document.mainform.editonly.value = "no";
			}
			document.mainform.submit();
		}
		function massCalculator() {
			window.open("/cgi-bin/massCalculator.pl","", "resizable");
		}
		
	//--></SCRIPT>
EOJAVA

	return $javascript;
}

##PERLDOC##
# Function : CreateBody1
# Argument : $tableheading: title for tabbed table
# Globals  : NONE
# Returns  : NONE
# Descript : Returns the upper part of the body for output_form
# Notes    : 
##ENDPERLDOC##
sub CreateBody1 {

	my $tableheading = shift(@_);	# Title of tabbed table
	my $key;						# For iterating through hash	
	my $body;						# Value to return

	# Body if we are stand-alone: edit-only = yes
	if ($editonly eq "yes") {
		$body .= <<EOBODY;
			<BR>
			<TABLE cellspacing=0 cellpadding=0 border=0 width=975>
			<TR><TD>$tableheading</TD></TR>
			<TR><TD><TABLE cellspacing=0 cellpadding=0 width=975 style="border: solid #000099; border-width:1px">
			<TR><TD><TEXTAREA ROWS=16 COLS=120 WRAP=VIRTUAL SCROLLBARS=YES NAME="data">$data</TEXTAREA></TD></TR>
			</TABLE></TD></TR></TABLE>
			<BR><TABLE width=975><TR><TD align="center">
			<INPUT TYPE=button class="outlinebutton" VALUE="  Save  " onClick="Save()"></TD></TR></TABLE>
EOBODY
	}

	# Body if we are in pop-up: 2 cases
	else {
		# If we are in selector mode: Cancel and Edit buttons, data in table
		if ($isediting eq "No") {
			$body .= <<EOBODY;
				<TD class="pagetitle" align="left">Mod Values</TD>
				<TD align="right"><TABLE><TR><TD><INPUT TYPE=button class="outlinebutton" VALUE="Cancel" onClick="javascript:self.close();"></TD>
				<TD><INPUT TYPE=button class="outlinebutton" VALUE="  Edit  " onClick="Edit()"></TD></TR></TABLE></TD></TR></TABLE>
				<BR>
				<TABLE cellspacing=0 cellpadding=0 border=0 width=100%>
				<TR><TD>$tableheading</TD></TR>
				<TR><TD><TABLE cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
				<TR><TD class=title>Description</TD><TD class=data align="center"><B>AA</B></TD><TD class=data align="center" colspan=3><B>DiffMass</B></TD></TR>
EOBODY
			foreach $key (sort (keys %diffmodvalues)) {
				if (!defined $symbols{$key} || $symbols{$key} eq "") {
					$body .= "\n<TR height=20><TD class=title><A HREF=\"javascript:Selector('$key')\">$key</A></TD><TD class=data width=20%></TD><TD class=data align=\"right\">$diffmodints{$key}</TD><TD class=data width=1>.</TD><TD class=data>$diffmoddecs{$key}</TD></TR>";
				}
				else {
					$body .= "\n<TR height=20><TD class=title><A HREF=\"javascript:Selector('$key')\">$key</A></TD><TD class=data align=\"center\">$symbols{$key}</TD><TD class=data align=\"right\">$diffmodints{$key}</TD><TD class=data width=1>.</TD><TD class=data>$diffmoddecs{$key}</TD></TR>";
				}
			}

			$body .= "</TABLE></TD></TR></TABLE>";
		}

		# If we are in edit mode: Cancel Edit and Save Buttons, text box
		else {
			$body .= <<EOBODY;
				<TD class="pagetitle" align="left">Mod Values</TD>
					<TD align="right"><TABLE><TR><TD><INPUT TYPE=button class="outlinebutton" VALUE="Cancel Editing" onClick="cancelEdit()"></TD>
				<TD><INPUT TYPE=button class="outlinebutton" VALUE="  Save  " onClick="Save()"></TD></TR></TABLE></TD></TR></TABLE>
				<BR>
				<TABLE cellspacing=0 cellpadding=0 border=0 width=100%>
				<TR><TD>$tableheading</TD></TR>
				<TR><TD><TABLE cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
				<TR><TD><TEXTAREA ROWS=16 COLS=43 WRAP=VIRTUAL SCROLLBARS=YES NAME=\"data\">$data</TEXTAREA></TD></TR>
				</TABLE></TD></TR></TABLE>
				<BR><INPUT TYPE=button class="outlinebutton" VALUE="Mass Calculator" onClick="massCalculator()">
EOBODY
		}
	}
	return $body;
}


##PERLDOC##
# Function : error
# Argument : $output - The string to display as the error statement.
# Globals  : NONE
# Returns  : NONE
# Descript : Prints out a properly formatted error message in case the user did something wrong; also useful for debugging
# Notes    : Modify this as neccessary for your program.
##ENDPERLDOC##
sub error {
	my ($output) = @_;

	print "<DIV>$output</DIV>";
	exit 1;
}
