#!/usr/local/bin/perl

#-------------------------------------
#	Minimizer,
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
# Description: Selectively deletes DTA files from a Sequest directory
# This program sorts DTA files in the chosen directory according to intensity, keeps only
# the number of files specified by the user, and deletes the rest. It uses the &delete_file 
# routine from michrochem_include.pl so it also deletes corresponding zta's and out's. 



#####################################################
#
#		Parameters of the program:
#
# directory
#	The name of the directory from which files will be deleted.
#
# numDTAs
#	The number of DTAs that will be keyp in the directory (the number not deleted).
#
# minIons
#	A cutoff value. All DTAs files with fewer than minIons are automatically deleted.
#
# operator
#	Initials of the operator. Filling this field is REQUIRED, and there is no default value for it.
#
# surpressOutput
#	If true, the program will not output anything aside from error messages (in the event that errors occur). If false or
#	undefined, the program will output summary statistics after running.



################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
	require "microchem_form_defaults.pl";
}

#########################################
# See if we're in web mode or command line mode
if($ARGV[0] eq "-c"){
	$WEB_MODE = 0;
}else{
	$WEB_MODE = 1;
}


#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
if($WEB_MODE){
	#get var values from CGI-recieve
	&cgi_receive;
} else{
	#get values from the command line
	shift(@ARGV);	
	foreach  (@ARGV) {
		($key,$value) = split /=/;
		$FORM{$key} = $value; 
	}
}
$dir = $FORM{"directory"};
$numDTAs = $FORM{"numDTAs"};
$minIons = $FORM{"minIons"};
$operator = $FORM{"operator"};
$output = (not $FORM{"surpressOutput"});

#######################################
# Global Vars
$DEBUG_MODE = 0;
$avgIntensity = 0;
$sumIntensity = 0;
$minIntensity = 0;
$medianIntensity = 0;
$maxIntensity = 0;
$deletecount = 0;
$keptcount = 0;
$cutoffIntensity = 0;
$totalFiles = 0;
$page = 0;
@deleteList;

#######################################
# Initial output
if($WEB_MODE and $output){
	&MS_pages_header("Minimizer","#871F78");
}

#######################################
# Flow control
if (!defined $dir && $WEB_MODE) {
	&choose_directory;
} elsif ( !defined $numDTAs && $WEB_MODE) {
	$page = 2;
	print qq(<hr><p>);
	&print_sample_name($dir);
	print qq(<table cellpadding = "20" cellspacing = "10"><td>);
	&output_form;
	print qq(<td>);
	&minimize;
	print qq(</table></body></html>);
} else {
	$page = 3;
	&minimize;
}

exit 1;

######################################
# Main action

sub minimize{

	#&reinitialize_summary_stats;

	if( $page == 3){
		&error_check_inputs;
	}

	my(@pairs,@DTAfilenames,%intensityHash,%namesHash,$name,$i,$numFiles);

	#get the list of names of DTAs and corresponding intensities
	%intensityHash = &get_name_intensity_pairs;

	#get the list of all DTA files actually in the directory
	@DTAfilenames = &get_DTA_file_list;
	$count = @DTAfilenames;
	
	#make a list of ordered pairs of DTA names and intensities (can't use a hash becasue in some cases intensities aren't unique)
	foreach $name (@DTAfilenames) {
		 push @pairs, [ $name, $intensityHash{$name}];
	}
		
	#sort according to intensity, and delete the ones that don't make the cut
	$i=0;
	foreach $pair (sort {$b->[1] <=> $a->[1];} @pairs) {
		
		my($name,$intensity);
		$name = $$pair[0];
		$intensity = $$pair[1];

		$sumIntensity += $intensity;
		$totalFiles++;

		# look for the median, max and min
		if( ($i <= ((@DTAfilenames / 2) + 1)) and ($i >= (@DTAfilenames)/2) ) {
			$medianIntensity = $intensity;
		}
		if( $i == 0){
			$maxIntensity = $intensity;
		}
		if( $i == (@pairs - 1)){
			$minIntensity = $intensity;
		}

		# keep it or delete it	
		if( $keptcount < $numDTAs and &has_enough_ions($name)){
			$keptcount++;
			$cutoffIntensity = $intensity;	# the last one kept will remain as the cutoffIntensity
		} else {
			if($page == 3){					# only delete files if we're not just donig preliminary stats
				push @deleteList, &delete_files( "$seqdir/$dir/$name" ) or &error("Could not delete file $seqdir/$dir/$name<br>");
				$deletecount++;
			}
		}
		$i++;
	}

	if($WEB_MODE and $output){
		&print_results;
	}
	
	# do some bookkeeping
	if($page == 3){ 
		&update_deletion_log;				# automatically updates the logfile, too
	}

	# 03/02/01	An executive decision was made that it's better not to call this funciton. See the "NOTE" in comments below.
	#&update_zta_list_and_lcq_profile;
}


# update_deletion_log
# Writes changes to both the deletion log and the logfile of the sequest directory
# (yes, the write_deletionlog function does it all)
sub update_deletion_log{
	my($string);
	$string = "Minimizer minIons = $minIons operator: $operator date: " . localtime() . ", $deletecount DTA sets deleted";
	&write_deletionlog($dir,$string,\@deleteList);
}

##
##	NOTE
##	The subroutine immediately below is never called. 
#	The logic behind that is that it's fine if these files contain entries for nonexistant DTAs. No other application seems to worry
# about updating these files, and for consistency, minimizer won't either. The code wasn't erased so that, if we change this policy in 
# the future, we have the code ready.


# update_zta_list_and_lcq_profile
# removes any lines from the lcq_zta_list file and the lcq_profile file which contain names of deleted files. 
# Admittedly, this is a messy implementation. I don't know of any way to destructively modify a text file, so this function
# reads the files into arrays, deletes the files, manipulates the arrays, and writes the arrays back to the original file names.
sub update_zta_list_and_lcq_profile{
	open(LCQPROFILE , "$seqdir/$dir/lcq_profile.txt");
	open(ZTALIST , "$seqdir/$dir/lcq_zta_list.txt");
	
	my($name,$line,$ddir);

	# read in files
	while(<LCQPROFILE>){
		push  @lcqprofile, $_;
	}
	while(<ZTALIST>){
		push @ztalist, $_;
	}
	close ZTALIST;
	close LCQPROFILE;

	# delete the files
	unlink "$seqdir/$dir/lcq_profile.txt";
	unlink "$seqdir/$dir/lcq_zta_list.txt";

	#delete the right lines
	foreach $name (@deleteList) {
		if ($name =~ m!/!) {
             ($ddir,$name) = ($name =~ m!^(.*)/(.*?)$!);
		}
		for ($i=0; $i < @lcqprofile ; $i++) {
			$lcqprofile[$i] =~ s/^.*$name.*\n//;
		}
		for ($i=0; $i < @ztalist ; $i++) {
			$ztalist[$i] =~ s/^.*$name.*\n//;
		}
	}

	# rewrite the files
	open(LCQPROFILE , ">>$seqdir/$dir/lcq_profile.txt");
	open(ZTALIST , ">>$seqdir/$dir/lcq_zta_list.txt");
	print LCQPROFILE @lcqprofile;
	print ZTALIST @ztalist;
}

# print_results
# outputs summary statistics as HTML
sub print_results{
	

	if($totalFiles){									# protect against division by zero errors
		$avgIntensity = $sumIntensity / $totalFiles;	
	} else{
		$avgIntensity = 0;
	}
	
	if( $page == 3){		# in this case we have done the minimization already
		print "<hr><p>";
		print "Minimization Successful<br><br>";
		print "<TABLE bgcolor=\"#e2e2e2\">";
		&print_output_row("DTAs kept", $keptcount, "Please don't convert this value to scientific notation.");
		&print_output_row("DTAs deleted", $deletecount, "Please don't convert this value to scientific notation.");
	} else {					# in this case, we're ouputting stats beforehand
		print "<TABLE bgcolor=\"#e2e2e2\">";
		&print_output_row("DTA files",$totalFiles,"NO scientific notation!");
	}
	if($deletecount){
		&print_output_row("Cutoff" . ( $page == 3 ? " Intensity" : " will be"), $cutoffIntensity);
	}
	print "</TABLE><p><TABLE bgcolor=\"#e2e2e2\">";

	# output relevant summary stats
	if($avgIntensity){
		&print_output_row("Average Intensity", $avgIntensity);
	}
	if($medianIntensity){	# yes, this funny conditional was put here on purpose
		&print_output_row("Minimum Intensity", $minIntensity);
	}
	if($medianIntensity){	# this one, too
		&print_output_row("Median Intensity", $medianIntensity);
	}
	if($medianIntensity){
		&print_output_row("Maximum Intensity", $maxIntensity);
	}
	print "</TABLE>";
	
	if( $page == 3){
		# now print the "What do you want to do now?"
		@text = ("Run Sequest","Create DTA", "Sequest Summary","View DTA Chromatogram");
		@links = ("sequest_launcher.pl","create_dta.pl","runsummary.pl?directory=$dir","dta_chromatogram.pl");
		&WhatDoYouWantToDoNow(\@text, \@links);
	}
}

#silly little helper function for the above subroutine
sub print_output_row {
	my($lbl, $val, $noSciNotationFlag);
	($lbl, $val, $noSciNotationFlag) = @_;
	$val = &sci_notation($val) unless ($noSciNotationFlag);
	print "<TR><TD width=\"120\"><span class=\"smallheading\">$lbl:\&nbsp\;</span></TD>";
	print "<TD>$val</TD>";
}
# has_enough_ions
# Counts the lines of a DTA to get an ion count. 
# Returns a boolean indicating whether the ion count is meets the minimum requirement
sub has_enough_ions{
	my($i);
	open(THISDTA, "$seqdir/$dir/$_[0]") or &error("Couldn't open $seqdir/$dir/$_[0]");

	$i=0;
	while (<THISDTA>) {
		$i++;
	}
	# don't count the header!
	$i--;

	close THISDTA;
	return( $i >= $minIons);
}

# get_DTA_file_list
# Returns an array of strings which are the names of DTA files in the chosen directory
sub get_DTA_file_list{
	my(@list,@DTAlist,$name);
	opendir DIR , "$seqdir/$dir";
	@list = readdir DIR;
	foreach $name (@list) {
		if ($name =~ /\.dta$/) {
			push @DTAlist, $name;
		}
	}
	return(@DTAlist);
}


# get_name_intensity_pairs
# Returns a list of pairs (which can be interpreted as a hash) of names of DTA files and corresponding intensities
# It gets this information by looking in the lcq_profile file of the specified directory
sub get_name_intensity_pairs {

	open(LCQPROFILE , "$seqdir/$dir/lcq_profile.txt") or &error("Could not open the lcq_profile in directory $dir");

	my( @line, $DTAname, $intensity, $MH);

	#recognize and eat the one-line header of the lcq_profile
	@line = split(" ", <LCQPROFILE>);
	unless ( $line[0] eq "Datafile" && $line[6] eq "MaxTIC") { &error("Encountered a problem with lcq_profile in $dir. Either profile is invalid or profile format conventions have changed since creation of Minimizer"); }

	#extract the name-intensity pairs
	foreach( <LCQPROFILE>){
		@line = split(" ",$_);
		$DTAname = $line[0];
		$intensity = $line[6];
		@pairslist = ( @pairslist, $DTAname, $intensity);
	}
	
	close(LCQPROFILE, "$seqdir/$dir/lcq_profile.txt");
	return(@pairslist);
}


# error_check_inputs
# Makes sure that all user chosen inputs are legal. Quits with an error message if something goes wrong
sub error_check_inputs {

	#If we're debugging, we're only allowed to use an Edward directory, so as not to accidentally delete something important
	if($DEBUG_MODE){
		unless( $dir =~ /edward/){ &error("For debugging purposes, please select a duplicate directory whose name contains 'edward'");}
	}

	unless (&is_number(\$numDTAs)) {
		&error("You must specify a valid integer for the number of DTAs to keep.");
	}

	unless (&is_number(\$minIons)) {
		&error("You must specify a valid integer for the minimum number of ions per DTA.");
	}

	unless ( $operator =~ /[a-zA-Z]{3}/) {
		&error("Please enter your initials \(three letters\) in the \'operator\' field.");
	}
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

sub output_directory_info {

	print "<hr><p>";

}


#######################################
# Main form subroutines

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
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></TD>
</TR></Table>
</Form></Body></HTML>

DONE
}

sub output_form { 

	#get the form defaults
	my($def_numDTAs);
	$def_numDTAs = $DEFS_MINIMIZER{"Number of DTA files to keep"};
	$def_minIons = $DEFS_MINIMIZER{"Minimum Ions per DTA file"};

	print <<EOFORM2;

<FORM NAME="Directory Select" ACTION="$ourname" METHOD=get>
<TABLE BORDER=0 CELLSPACING=6 CELLPADDING=0>

<TR><TD align=right><span class="smallheading">Max DTAs to keep:&nbsp;</span></TD>
	<TD>
	<input type="text" name="numDTAs" size=4 maxlength=4 value=$def_numDTAs>
	</TD>
<TR><TD align=right><span class="smallheading">Min Ions per DTA:&nbsp;</span></TD>
	<TD>
	<input type="text" name="minIons" size=4 maxlength=4 value=$def_minIons>
	</TD>
<TR><TD align=right><span class="smallheading">Operator:&nbsp;</span></TD>
	<TD>
	<input type="text" name="operator" size=3 maxlength=3>
	</TD>
<TR><TD>
	<TD><INPUT type="submit" class="button" value="Minimize">&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/minimizer.pl.html">Help</A></span></TD>
</TR></Table>

<INPUT type="hidden" name="directory" value=$dir>

</Form>


EOFORM2
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

sub reinitialize_summary_stats{

	$avgIntensity = 0;
	$sumIntensity = 0;
	$minIntensity = 0;
	$medianIntensity = 0;
	$maxIntensity = 0;
	$deletecount = 0;
	$keptcount = 0;
	$cutoffIntensity = 0;
	$totalFiles = 0;

}


sub print_sample_name {
  my ($directory, $padding) = @_;
  
  my (%dir_info) = &get_dir_attribs ($directory);
  $dir_info{"Fancyname"} = &get_fancyname($directory,%dir_info);

  print qq(<span class="smallheading">Sample:</span>\n);

  # join together the fancyname, sample ID, and operator name:
  $output = join (" ", map { $dir_info{$_} } ("Fancyname", "SampleID", "Operator") );
  ($dir_info{'Fancyname'}) =~ m/(.*) \((.*)\)/;
  $matched_name = $1;
  $matched_ID = "($2)" if ($2);

  $actualoutput = $output;


  print ("<tt>$actualoutput");

  if ($padding) {
    print ("&nbsp;" x ($padding - length ($output)));
  }
  print ("</tt>\n");
}

sub open_main_form {
  print <<EOM;
<FORM name="mainform" METHOD=post ACTION="$ourname">
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$directory">
<INPUT TYPE=HIDDEN NAME="notnew" VALUE="notnew">
<INPUT TYPE=HIDDEN NAME="prevsort" VALUE="$sort">
<INPUT TYPE=HIDDEN NAME="boxtype" VALUE="$boxtype">
<INPUT TYPE=HIDDEN NAME="load_dta_vcr" VALUE="$load_dta_vcr">
EOM
}

# End of minimizer.pl