#!/usr/local/bin/perl

#-------------------------------------
#	Name of Program,
#	(C)1999 Harvard University
#	
#	W. S. Lane/P. Djeu
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 6/5/00 By Peter Djeu
#
# Description: Given a DTA directory, searches for all respective DTA files with the lowest charge (z) value.
# Using these DTA's, this program creates new DTA files for all other charges (whose files are not already in
# existence) by modifying the z value and the MH+ value.  The local lcq_profile.txt is also updated.
#
# 6/6/00 P. Djeu
# The undo feature creates a file in the local directory called all_charged_up.txt to restore the directory.
# The old lcq_profile.txt is moved to lcq_profile.txt.previous, and is restored with the undo feature.
#
# 6/26/00 P. Djeu
# Added the max and min limits for the MH+ weight.  Files with MH+'s outside of this range are not created.

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
}


#######################################
# Initial output
&MS_pages_header("All Charged Up","#871F78");


#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};
$undo = $FORM{"undo"};
$min_mhplus = $FORM{"min"};
$max_mhplus = $FORM{"max"};


#######################################
# Fetching default values
#
# This program, like DTA_Banisher, uses the Mono_mass value of hydrogen, which is loaded in
# create_new_files(args).


#######################################
# Flow control

if (!defined $dir || (defined $dir && defined $FORM{"viewonly"})) {
	&output_form;
} elsif ($undo == 1) {
	&undo_changes;
} else {
	&create_charges;
}
exit 1;

######################################
# Main action

sub create_charges {
	print "<P><HR><P>\n";
	
	&error("The min MH+ limit $min_mhplus is not a positive integer.") if !(&is_number(\$min_mhplus));
	&error("The max MH+ limit $max_mhplus is not a positive integer.") if !(&is_number(\$max_mhplus));
	&error("The min MH+ limit must be less than the max MH+ limit.") if ($min_mhplus > $max_mhplus);

	# i is generic counter, like in C
	my ($i, $line, $lcq_header);
	$cwd = "$seqdir/$dir";
	
	# Get all .dta files
	chdir $cwd or &error("Could not open the selected directory. $!\n");
	opendir CURR_DIR, '.' or &error("Could not open the selected directory. $!\n");
	@dta_files = sort grep /dta$/, readdir CURR_DIR;
	closedir CURR_DIR;
		
	# Making a backup list of .dta files.
	open UNDO_FILE, ">all_charged_up.txt" or &error("The undo file all_charged_up.txt, could not be created. $!\n");
	print UNDO_FILE "The following files should NOT be erased by the undo feature:\n";
	foreach $b_file (@dta_files) {
		print UNDO_FILE "$b_file\n";
	}
	close UNDO_FILE;
	
	# lcq_profile_arr contains the lcq_profile.txt file in array form, line by line, making an exception for the header
	# Also, make the backup file lcq_acu_backup.txt.
	@lcq_profile_arr;
	open LCQ_PROFILE, "<lcq_profile.txt" or &error("Unable to open lcq_profile.txt. $!\n");
	open LCQ_OLD, ">lcq_profile.txt.previous" or &error("Unable to backup lcq_profile.txt. $!\n");
	$i = 0;
	$lcq_header = <LCQ_PROFILE>;
	print LCQ_OLD $lcq_header;
	while ($line = <LCQ_PROFILE>) {
		print LCQ_OLD $line;
		$lcq_profile_arr[$i] = $line;
		$i++;
	}
	close LCQ_PROFILE;
	close LCQ_OLD;

	# Create a fixed array that stores which charges the user wants.  A 0 means that this charge is not needed, while
	# a 1 means that this charge is needed.  This template is reused for every iteration, and elements are set to 0 as
	# the prgram discovers that certain dta charge files are not needed.
	
	# Note array begins at index 1, not 0.
	if ($FORM{"charge1"} eq "yes") {$fixed[1] = 1;} else {$fixed[1] = 0;}
	if ($FORM{"charge2"} eq "yes") {$fixed[2] = 1;} else {$fixed[2] = 0;}
	if ($FORM{"charge3"} eq "yes") {$fixed[3] = 1;} else {$fixed[3] = 0;}
	if ($FORM{"charge4"} eq "yes") {$fixed[4] = 1;} else {$fixed[4] = 0;}
	if ($FORM{"charge5"} eq "yes") {$fixed[5] = 1;} else {$fixed[5] = 0;}
	
	$i = 0;
	$num_files = @dta_files;
	if ($num_files == 0) {
		&error("No dta files in that directory.\n");
	}
	
	# Go through all files in the directory, charging what's necessary
	$file_count = 0;
	while ($i < $num_files) {
		@temp_array = @fixed;

		# Get the base file for the next series of dta's.
		$file_name = $dta_files[$i];
		$temp_array[&get_charge($loc_file = $file_name)] = 0;
		
		$i++;
		# Loop through the next few files, 4 at most, to check for existing dta's which should not be overwritten.		
		$name1 = &get_shrt_name($loc_file = $file_name);
		$name2 = &get_shrt_name($loc_file = $dta_files[$i]);
		
		while ($name1 eq $name2) {
			$temp_array[&get_charge($loc_file = $dta_files[$i])] = 0;
			$i++;
			$name2 = &get_shrt_name($loc_file = $dta_files[$i]);
		}
	
		# Ready to create the new dta's.
		&create_new_files($loc_file = $file_name, @copies_needed = @temp_array);
	}
	
	# Write the new lcq_profile.txt
	open NEW_LCQ, ">lcq_profile.txt" or &error("Unable to write to lcq_profile.txt. $!\n");
	print NEW_LCQ "$lcq_header";
	foreach $line (sort @lcq_profile_arr) {
		print NEW_LCQ "$line";
	}
	
	print <<FEEDBACK;
<DIV><H3><image src="/images/circle_1.gif">&nbsp;<span style="color:#871F78">Charging complete</span></H3><ul>
<li><span class="smallheading">Number of new dta files generated:</span> $file_count</ul>
	<FORM NAME="Undo Option" METHOD=get>
	<INPUT NAME="undo" TYPE="hidden" VALUE="1">
	<INPUT NAME="directory" TYPE="hidden" VALUE=$dir></FORM><TABLE><TR><TD>
FEEDBACK
#<INPUT TYPE=submit CLASS=button VALUE="Oops! Undo Changes">

@text = ("Oops! Undo Changes","Run Sequest","Create DTA", "Sequest Summary","View DTA Chromatogram");
@links = ("$ourname?undo=1&directory=$dir","sequest_launcher.pl","create_dta.pl","runsummary.pl?directory=$dir","dta_chromatogram.pl");
&WhatDoYouWantToDoNow(\@text, \@links);

	print <<FEEDBACK;
	</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class="normaltext">
	<A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></p></TD></TR></TABLE>
</DIV>
</BODY></HTML>
FEEDBACK
}


#######################################
# subroutines (other than &output_form and &error, see below)

# given an array of yes's or no's (for the new charge .dta's) and the file name of the base file,
# creates all of the required .dta files.  Also, updates the local lcq_profile.txt along the way.

sub create_new_files($loc_file, @copies_needed) {
	$j = 0;
	my ($short_name, $first_line, $line_buf, $base_MH, $base_charge, $new_MH, $hydrogen);
	my ($lcq_index, @match, $ret_val);
	# Initialize
	$hydrogen = $Mono_mass{'Hydrogen'};
	$short_name = &get_shrt_name($loc_file);
	open(SOURCE_FILE, "<$loc_file") or &error("Can't open file $loc_file. $!\n");
	$first_line = <SOURCE_FILE>;
	($base_MH, $base_charge) = split ' ', $first_line;
	close(SOURCE_FILE);
	# Get index of first blank spot
	$lcq_index = @lcq_profile_arr;

	for ($j = 1; $j < 6; $j++) {
		if ($copies_needed[$j] == 1) {
			# Calculate new MH+ weight based on the formula:
			# new MH+ = (((old MH+ - H+) / old_charge) * new_charge) + H+
			# . . . and round to 2 decimal places.
			$new_MH = &precision(((( ($base_MH - $hydrogen) / $base_charge) * $j) + $hydrogen), 2);
			
			# The new mhplus must be within the user-defined limits
			if ($new_MH < $min_mhplus || $new_MH > $max_mhplus) {
				next;
			}

			open(DEST_FILE, ">$short_name.$j.dta") or &error("Can't create new file $short_name.$j.dta. $!\n");

			print DEST_FILE "$new_MH $j \n";

			# Unique first line done, now blindly copy rest of the file
			open(SOURCE_FILE, "<$loc_file") or &error("Can't open file $loc_file. $!\n");
			$line_buf = <SOURCE_FILE>;	# Get rid of first line

			while ($line_buf = <SOURCE_FILE>) {
				print DEST_FILE "$line_buf";
			}
			close(DEST_FILE);
			close(SOURCE_FILE);
			
			#########################################################################
			# Append the new entry to the end of the soon-to-be lcq_profile.txt array
			@match = grep /$loc_file/, @lcq_profile_arr;
			# Slightly hacky, but @match should only contain one element, so a hard coded index 0 is used
			$_ = $match[0];

			$ret_val = s/$base_charge.dta/$j.dta/;
			if ($ret_val != 1) {	# If one substitution is not made, then error will occur.
				#&error("Could not update lcq_profile.txt.\n");
				$short_name =~ /\.(\d\d\d\d)\./;
				my($badscan) = $1;
				print "<span class='smallheading'>Warning: lcq_profile entry for scan $badscan does not exist.</span><br>";  #error changed to a warning 9/18/01 by Edward at Bill's request.
			}
			$lcq_profile_arr[$lcq_index] = $_;

			$lcq_index++;
			$file_count++;
		} else { # $copies_needed[$j] == 0
			# Do nothing
		}
	}
}


# reads in all_charged_up.txt (generated in create_charges) and deletes all dta files that are NOT
# in this file.  Also, the old lcq_profile.txt (stored as lcq_profile.txt.previous) is restored.
sub undo_changes {
	# This hash maps all files found in all_charged_up.txt to "found".
	my %preserved_files;
	my ($p_file, $line, @all_files);
	my $fancyname;
	$fancyname = &get_fancyname($dir);

	print "<P><HR><P>\n";
	$cwd = "$seqdir/$dir";
	chdir $cwd;

	open UNDO_FILE, "<all_charged_up.txt" or &error("File all_charged_up.txt not found. $!\n");
	$line = <UNDO_FILE>;	# Get rid of first line because it is only a header
	while ($line = <UNDO_FILE>) {
		chomp $line;
		$preserved_files{$line} = "found";
	}
	close(UNDO_FILE);

	# Go through directory and delete all files not in the preserved_files hash
	opendir CURR_DIR, '.' or &error("Can't open the current directory. $!\n");
	@all_files = sort grep /dta$/, readdir CURR_DIR;
	closedir(CURR_DIR);

	foreach $p_file (@all_files) {
		if ($preserved_files{$p_file} ne "found") {
			unlink $p_file;
		}
	}

	# Restore lcq_profile.txt
	open REST_LCQ, ">lcq_profile.txt" or &error("Unable to restore lcq_profile.txt. $!\n");
	open BACKUP_LCQ, "<lcq_profile.txt.previous" or &error("Unable to find backup file lcq_profile.txt.previous. $!\n");
	while ($line = <BACKUP_LCQ>) {
		print REST_LCQ $line;
	}
	close REST_LCQ;
	close BACKUP_LCQ;

	print <<EOCHANGE
<H3>The Directory <span style="color:#00B800">$fancyname</span> has been Restored</H3>

</BODY></HTML>
EOCHANGE
}

# Takes the reference to a number and checks to make sure the given argument is composed of only digits.
# Also, the arg is trimmed of unnecessary wnitespace before the function returns

sub is_number {
	my ($ref, $test_num);

	$ref = $_[0];
	$test_num = $$ref;

	# Trim whitespace
	$test_num =~ s/\s//g;
	if ($test_num =~ /^\d+$/) {
		return 1;
	} else {
		return 0;
	}
}

# given a file name, returns the first 3 segments (delimited by dots) of its name, which is used to check for duplicates
sub get_shrt_name($loc_file) {
	my @frags = split /\./, $loc_file;
	return("$frags[0]\.$frags[1]\.$frags[2]");
}

# given a file name, extracts the charge associated with that file name
sub get_charge($loc_file) {
	my @frags = split /\./, $loc_file;
	return("$frags[3]");
}

#######################################
# Main form subroutine

sub output_form {
	print "<P><HR>\n";

	my ($marked1, $marked2, $marked3, $marked4, $marked5);
	$marked1 = ($DEFS_ALL_CHARGED_UP{"1+"} eq "yes") ? " checked" : "";
	$marked2 = ($DEFS_ALL_CHARGED_UP{"2+"} eq "yes") ? " checked" : "";
	$marked3 = ($DEFS_ALL_CHARGED_UP{"3+"} eq "yes") ? " checked" : "";
	$marked4 = ($DEFS_ALL_CHARGED_UP{"4+"} eq "yes") ? " checked" : "";
	$marked5 = ($DEFS_ALL_CHARGED_UP{"5+"} eq "yes") ? " checked" : "";

	# Setup the Javascript confirmation box.  This is printed to the top of the HTML file.
	print <<EOJAVA;
<SCRIPT LANGUAGE="JavaScript">
<!--
function checkConfirm() {
	response=confirm("Warning: After leaving the Undo screen, you will be permanently adding dta's" +
	                 " to the directory.  Do you wish to continue?")
	if (response == false) {
		this.focus()   // shift focus back to the window rather than the submit button
		return (false) //this cancels the submit
	} else {
		return(true) //this returns a value of true to the form action line and continues form submission
	}
}
//-->
</SCRIPT>
EOJAVA

	&get_alldirs;
	print <<EOFORM;

<FORM NAME="Directory Select" ACTION="$ourname" METHOD=get ONSUBMIT="return checkConfirm()">
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
<TR>
	<TD><span class="smallheading">Directory:&nbsp;</span>
	<TD>
	<span class=dropbox><SELECT NAME="directory">
EOFORM

	foreach $dir (@ordered_names) {
	      print qq(<OPTION VALUE = "$dir");
		  print " SELECTED" if ($dir eq $FORM{directory});
		  print qq(>$fancyname{$dir}\n);
	}

	print <<EOFORM2;

	</SELECT></span></TD>
<TR><TD><span class="smalltext">&nbsp;</span></TD>
<TR><TD>
	<TD ALIGN="left"><span class="smallheading">Create dta files for these additional charge states:</span>
<TR><TD><TD>
	<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
		<TR>
		<TD ALIGN="right">
		<span class="smallheading" style="color:#871F78">1+:</span>
		</TD>
		<TD>
		<input type="checkbox" name="charge1" value="yes"$marked1>
		</TD>

		<TD ALIGN="right">
		<span class="smallheading" style="color:#871F78">&nbsp;&nbsp;2+:</span>
		</TD>
		<TD>
		<input type="checkbox" name="charge2" value="yes"$marked2>
		</TD>
		
		<TD ALIGN="right">
		<span class="smallheading" style="color:#871F78">&nbsp;&nbsp;3+:</span>
		</TD>
		<TD>
		<input type="checkbox" name="charge3" value="yes"$marked3>
		</TD>
		
		<TD ALIGN="right">
		<span class="smallheading" style="color:#871F78">&nbsp;&nbsp;4+:</span>
		</TD>
		<TD>
		<input type="checkbox" name="charge4" value="yes"$marked4>
		</TD>
		
		<TD ALIGN="right">
		<span class="smallheading" style="color:#871F78">&nbsp;&nbsp;5+:</span>
		</TD>
		<TD>
		<input type="checkbox" name="charge5" value="yes"$marked5>
		</TD>
		</TR>
	</TABLE>
<TR><TD><span class="smalltext">&nbsp;</span></TD>
<TR><TD>
	<TD><span class="smallheading">Use MH+ Limits of&nbsp;&nbsp;Min:&nbsp;</span><INPUT type="text" name="min" size=4 maxlength=4 value=$DEFS_ALL_CHARGED_UP{"Min"}><span class="smalltext">Da
	&nbsp;
	<span class="smallheading">to&nbsp;&nbsp;&nbsp;&nbsp;Max:&nbsp;</span></span><INPUT type="text" name="max" size=4 maxlength=4 value=$DEFS_ALL_CHARGED_UP{"Max"}><span class="smalltext">Da</span>
<TR><TD>&nbsp;
<TR><TD>
	<TD>
	<INPUT TYPE=submit CLASS=button VALUE="Charge Up">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></TD>
</TR></TABLE>
</FORM></BODY></HTML>

EOFORM2
}





#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {

	print <<ERRMESG;
<H3>Error:</H3>
<div>
@_
</div>
</body></html>
ERRMESG

	exit 1;
}

# End of all_charged_up.pl