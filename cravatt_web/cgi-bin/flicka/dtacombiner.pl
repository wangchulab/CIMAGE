#!/usr/local/bin/perl

#-------------------------------------
#	CombIon
#	(C)1999-2002 Harvard University
#	
#	WS Lane/ Matthew Schweitzer, Lukas Bergstrom
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



################################################
# Created: 06/13/02 by Matthew Schweitzer
#
# Description: Finds and combines DTAs that are similar above a given threshold.
#
#
##CGI-RECEIVE## cgikey - A description of the cgi key-value pair goes here, all on one line.  Remove if not needed.

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
}
################################################
### Additional includes (if any) go here

use strict;
use vars qw(%FORM $ourname $seqdir $muquest $compare_dtas %Mono_mass $webmuquest $cgidir);

require "selectpeaks_include.pl";
require "html_include.pl";

#######################################
# Initial output
# this may or may not be appropriate; you might prefer to put a separate call to the header
# subroutine in each control branch of your program (e.g. in &output_form)
&MS_pages_header("CombIon","#000000");
print "<hr>";

&cgi_receive;

my $dir = $FORM{"directory"};
my $algorithm = lc($FORM{"algorithm"});
my $muq_threshold = $FORM{"muquest_threshold"};
my $ion_threshold = $FORM{"ionquest_threshold"};
my $precursor_tol = $FORM{"precursor_tolerance"};
my $do_combine = $FORM{"combine"};
my $preprocess = $FORM{"ionquest_preprocess"};
my $check_with_muquest = $FORM{"check_with_muquest"};
my $ion_retest = $FORM{"ionquest_retest"};
my $muq_retest_threshold = $FORM{"muquest_retest_threshold"};

my $muq_offset_tol = $precursor_tol;
$preprocess = 0 if ($algorithm eq "muquest");	# don't use preprocessing with muquest
$check_with_muquest = 0 if ($algorithm eq "muquest");	# don't use retest with muquest

&output_form unless ($dir && $precursor_tol ne "");
&output_form if (($algorithm eq "muquest" && !$muq_threshold) || ($algorithm eq "ionquest" && !$ion_threshold));
&output_form if ($check_with_muquest && (!$ion_retest || !$muq_retest_threshold));

&watch_over_me;			# includes control for this app on the sequest status page.

$| = 1;

print qq(<div class="smallheading">);

if ($check_with_muquest && ($ion_retest <= $ion_threshold)) {
	print "The IonQuest retest threshold ($ion_retest%) must be higher than the IonQuest threshold ($ion_threshold%)!";
	print "</div></body></html>";
	exit 0;
}

my $threshold = ($algorithm eq "muquest") ? $muq_threshold : $ion_threshold;

chdir "$seqdir/$dir" or die "Could not access $seqdir/$dir: $!";
opendir(SEQDIR, ".");
my @dtas = grep /\.dta$/, readdir SEQDIR;
closedir(SEQDIR);

if ($preprocess) {
	my @fullname_dtas = @dtas;
	map {$_ = qq($seqdir/$dir/$_)} @fullname_dtas;
	&preprocess_dta(@fullname_dtas);
}

print <<EOF;
<br>
<table cellspacing=5 cellpadding=0 border=0>
<tr>
	<td class="smallheading" align="right">Directory:&nbsp;</td>
	<td class="smallheading">$dir&nbsp;&nbsp;&nbsp;(@{[$#dtas+1]} DTA files)</td>
</tr><tr>
	<td class="smallheading" align="right">Algorithm:&nbsp;</td>
	<td class="smallheading">@{[uc($algorithm)]} @{[($preprocess) ? "(preprocess)" : ""]}</td>
</tr><tr>
	<td class="smallheading" align="right">Threshold:&nbsp;</td>
	<td class="smallheading">$threshold@{[($algorithm eq "ionquest") ? "%" : ""]}</td>
</tr><tr>
	<td class="smallheading" align="right">Precursor Tolerance:&nbsp;</td>
	<td class="smallheading">±$precursor_tol m/z</td>
</tr>
EOF
if ($check_with_muquest) {
	print <<EOF;
<tr>
	<td class="smallheading" align="right">Retest:&nbsp;</td>
	<td class="smallheading">Run IonQuest matches less than $ion_retest% on MuQuest, accepting only matches > $muq_retest_threshold</td>
</tr>
EOF
	}

print <<EOF;
</table><br><br>
EOF

my $progbar_inc = 5;
my $total_computations = @dtas * (@dtas - 1) * .5;
my $inc_threshold = int(($total_computations * $progbar_inc / 100)+.5);
my $current_comp = 0;

my $progbar = &create_progress_bar(incrementpercent => $progbar_inc, description => "Progress");
print $progbar->{bar};


my %precursor = ();		# a hash that maps dtas to their precursor values
my $dta;
foreach $dta (@dtas) {
	$precursor{$dta} = &get_precursor($dta);
}

my %group = ();		# this hash maps dtas to a group number, where dtas with the same group number are similar
my @results = ();	# an array of arrays: $results[$number] is a reference to an array of the dtas in group $number
my ($i, $j, $group_number, $prefix1, $prefix2);
for ($i = 0; $i <= $#dtas; $i++) {
	for ($j = $i+1; $j <= $#dtas; $j++) {
		if ($current_comp++ > $inc_threshold) {		# progress bar stuff
			$current_comp = 0;
			print $progbar->{inc};
		}
		next if (exists $group{$dtas[$j]});		# if it's already in a group, don't need to try matching
		($prefix1 = $dtas[$i]) =~ s/\.\d\.dta$//;
		($prefix2 = $dtas[$j]) =~ s/\.\d\.dta$//;
		next if ($prefix1 eq $prefix2);			# don't want to match on dtas with same prefix and scan numbers, even if they have different charge states
		unless (abs ($precursor{$dtas[$i]} - $precursor{$dtas[$j]}) > $precursor_tol) {		# don't do comparison if precursor difference is outside tolerance range
			if (&compute($dtas[$i], $dtas[$j])) {
				if (exists $group{$dtas[$i]}) {
					$group_number = $group{$dtas[$i]};
					$group{$dtas[$j]} = $group_number;
					push @{$results[$group_number]}, $dtas[$j];
				} else {
					$group_number = $#results+1;
					$group{$dtas[$i]} = $group_number;
					$group{$dtas[$j]} = $group_number;
					push @results, [$dtas[$i], $dtas[$j]];
				}
			}
		}
	}
}

print $progbar->{done};

if ($preprocess) {	# done with the ptas, can now delete them
	&remove_ptas_from_directory($dir);
}



if (scalar @results == 0) {
	print "No groups found for this algorithm and tolerance level.<br><br>";
	unless ($do_combine eq "view") {
		@results = ();
		my @result_filenames = ();
		my $now = localtime();
		&write_log($dir, qq(CombIon run $now: No groups found.));
		if (&write_dtacombiner_log(number_combined => 0, new_files => 0, delete_old => ($do_combine eq 'combine_and_delete'), results => \@results, filenames => \@result_filenames)) {
			print "CombIon log written successfully.";
		} else {
			print "Unable to write CombIon log file.";
		}
		
	}
	print "</div></body></html>";
	exit 0;
}

print $#results+1, " DTA Groups:<br><br>";

$i = 0;
my (@dta_group, @result_filenames, $newfilename, $number_combined, $new_files_created);
foreach (@results) {
	$i++;
	@dta_group = @{$_};

	## to do: check to make sure all dta prefixes in the group are the same ##

	# combine this dta group into a single dta:
	unless ($do_combine eq "view") {
		$newfilename = &combine_a_group(($do_combine eq "combine_and_delete"), \@dta_group);
		if ($newfilename) {
			$number_combined += $#dta_group+1;
			$new_files_created++;
			push @result_filenames, $newfilename;
		} else {
			push @result_filenames, "COMBINE UNSUCCESSFUL";
		}
	}
}

my $output_html = &generate_output_html(number_combined => $number_combined, delete_old => ($do_combine eq 'combine_and_delete'), results => \@results, filenames => \@result_filenames);

unless ($output_html) {
	print "Could not generate HTML output.";
} else {
	print $output_html;
}


print "<br><br><br>";


my $now = localtime();

my $old_dtas = scalar @dtas;
my $new_dtas = scalar @dtas - $number_combined + $new_files_created;

if ($do_combine eq "combine") {
	print "Combine successful.<br>";
	print $number_combined, " DTA files combined into ", $new_files_created, " new DTA files.";
	&write_log($dir, qq|CombIon run $now: $number_combined DTA files combined into $new_files_created new DTA files.|);
} elsif ($do_combine eq "combine_and_delete") {
	print "Combine and delete successful.<br>";
	print $number_combined, " DTA files combined into ", $new_files_created, " new DTA files (originals deleted).";
	&write_log($dir, qq|CombIon run $now: $number_combined DTA files combined into $new_files_created new DTA files (originals deleted).|);
}

unless ($do_combine eq "view") {
	my $log_results = &write_dtacombiner_log(number_combined => $number_combined, new_files => $new_files_created, delete_old => ($do_combine eq 'combine_and_delete'), results => \@results, filenames => \@result_filenames);
	print "<br><br>";
	if ($log_results) {
		print "Results written to $log_results.";
	} else {
		print "Unable to write CombIon log file.";
	}
}

print <<EOF;
<br><br><br>
</div>
</body>
</html>
EOF
exit 0;



#######################################
# subroutines

##PERLDOC##
# Function : compute
# Argument : $dta1, $dta2 - the dtas to compare
# Globals  : uses $algorithm, $muq_threshold, $ion_threshold, $preprocess and others
# Returns  : 1 if the results match within the thresholds, 0 otherwise
# Descript : Compares the two dtas using muquest or compare_dtas (depending on $algorithm) to determine if they match
# Notes    : 
##ENDPERLDOC##
sub compute {
	my $dta1 = shift;
	my $dta2 = shift;
	if ($preprocess) {
		$dta1 =~ s/\.dta$/.pta/;
		$dta2 =~ s/\.dta$/.pta/;
	}
	my ($command, $output, $result, $offset);
	my $massdiff = 300;		# this is a number muquest uses to limit the window of search, its value isn't particularly important here, but 300 is the default in muquest.pl
	if ($algorithm eq "muquest") {
		$command = "$muquest $dta1 $dta2 $massdiff";
		$output = `$command`;
		($result, $offset) = split / /, $output;
		return 1 if ($result >= $muq_threshold && abs($offset) < $muq_offset_tol);
	} elsif ($algorithm eq "ionquest") {
		$command = "$compare_dtas Dta=$dta1 Dta=$dta2";
		$output = `$command`;

		if ($output =~ /^(\d+)%/) { $result = $1 } else { die "Unknown IonQuest output" }
		unless ($check_with_muquest) {
			return 1 if ($result >= $ion_threshold);
		} else {
			return 0 if ($result < $ion_threshold);	# fail if it doesn't match well enough
			return 1 if ($result >= $ion_retest);	# if it's above the retest threshold, don't need to check against muquest
			# otherwise, retest using muquest:
			$command = "$muquest $dta1 $dta2 $massdiff";
			$output = `$command`;
			#print qq(retest: $command : $output<br>);		#delete
			($result, $offset) = split / /, $output;
			return 1 if ($result > $muq_retest_threshold && abs($offset) < $muq_offset_tol);
		}
	} else {
		die "unknown algorithm: $algorithm";
	}
	return 0;
}

##PERLDOC##
# Function : combine_a_group
# Argument : First - a value that evaluates true if combined DTA files are to be deleted, false if they are to be left in the directory
# Argument : Second - a reference to an array of two or more DTA filenames
# Globals  : none
# Returns  : False if the combine was unsuccessful, otherwise the new filename.
# Descript : Calculates the minimum first scan number, and maximum last scan number, of the dta group and combines the group into a single DTA with a filename based on the computed scan numbers
# Notes    : The charge state of the combined DTA is the same as the first file in the group.
##ENDPERLDOC##
sub combine_a_group {
	my $delete_old = shift;
	my @dta_group = @{shift()};
	my ($firstscan, $lastscan, $first, $last);

	# calculate minimum first scan number, maximum last scan number of the group:
	($firstscan, $lastscan) = &get_scan_numbers($dta_group[0]);
	foreach $dta (@dta_group) {
		($first, $last) = &get_scan_numbers($dta);
		$firstscan = $first if ($first < $firstscan);
		$lastscan = $last if ($last > $lastscan);
	}

	$dta_group[0] =~ /^([^\.]+)\.\d+\.\d+\.(\d)\.dta$/;		# get dta prefix and charge state -> $1 and $2
	$newfilename = qq($1.$firstscan.$lastscan.$2.dta);
	my $combine_result = &combine_dtas($newfilename, $delete_old, $dir, \@dta_group);
	if (!$combine_result) { return 0 }
	return $newfilename;
}

##PERLDOC##
# Function : generate_output_html
# Argument : delete - true if the original files have been deleted (so muquest can't be performed on them)
# Argument : results - an array of references to arrays of groups
# Argument : filenames - an array of filenames corresponding to the combined groups, in the same order as the results array
# Globals  : none
# Returns  : output html if successful, false otherwise
# Descript : If @filenames is an empty array, this will not print combined filenames.  If @filenames is not empty, it must have the same number of elements as @results
# Notes    : Creates a two or three column table in which each row represents a group.  The first column is the group number, the second is a listing of DTAs in the group and the combined filename if present, the third is a link to MuQuest (only exists if delete is false)
##ENDPERLDOC##
sub generate_output_html {
	my %arguments = @_;
	my $delete = $arguments{delete_old};
	my @results = @{$arguments{results}};
	my @filenames = @{$arguments{filenames}};
	
	if (@filenames == 0) { $filenames[$#results] = 0 }		# if @filenames is empty, fill it with false values
	if (@results != @filenames) { return 0 }				# the lists must have the same number of elements

	my ($i, $output, $joined_dtas, $muqurl, $ionurl);

	$output = qq(<table cellspacing=0 cellpadding=5 border=1>\n);
	for ($i = 0; $i < @results; $i++) {

		$output .= <<EOF;
<tr valign="top">
	<td width=15 class="smallheading">@{[$i+1]}</td>
	<td width=350 class="smallheading">
EOF
		foreach (@{$results[$i]}) {
			$output .= $_ . "<br>\n";
		}
		$joined_dtas = join "&dtafile=", @{$results[$i]};
		if ($filenames[$i]) {
			$output .= qq(<br>Combined into $filenames[$i]\n);
		}
		$output .= "</td>\n";

		$muqurl = qq($webmuquest?dtafile=$joined_dtas&directory=$dir&compareWith=selected&compareAll=1&algorithm=$cgidir/muquest.exe&showNonZero=true&greaterThan=16&xcorrCutoff=.8);
		$ionurl = qq($webmuquest?dtafile=$joined_dtas&directory=$dir&compareWith=selected&compareAll=1&algorithm=$cgidir/compare_dtas.exe&showNonZero=true&greaterThan=16&xcorrCutoff=.8);
		unless ($delete) {	# if the files are deleted we can't perform muquest on them, so don't show the link to muquest
			$output .= <<EOF;
	<td width=100 class="smallheading">
		<nobr>
		MuQuest: <a href="$muqurl" target="_blank">MuQuest</a>/<a href="$ionurl" target="_blank">IonQuest</a>
		</nobr>
	</td>
EOF
		}
		$output .= "</tr>\n";
	}
	$output .= "</table>\n";
	return $output;
}

##PERLDOC##
# Function : write_dtacombiner_log
# Argument : number_combined - the number of files that were combined
# Argument : new_files - the number of new files created
# Argument : delete_old - boolean: true if the old dtas were deleted, false if left in directory
# Argument : results - reference to an array of references to arrays of dta groups
# Argument : filenames - an array of filenames that correspond to groups with the same index in @results
# Globals  : none
# Returns  : false if unsuccessful, the log filename if successful
# Descript : If @filenames is an empty array, this will not print combined filenames.  If @filenames is not empty, it must have the same number of elements as @results
# Notes    : Writes the log to the current directory, a chdir to the correct sequest directory must have already taken place.
##ENDPERLDOC##
sub write_dtacombiner_log {
	my %arguments = @_;
	my $number_combined = $arguments{number_combined};
	my $new_files = $arguments{new_files};
	my $delete_old = $arguments{delete_old};
	my @results = @{$arguments{results}};
	my @filenames = @{$arguments{filenames}};

	$number_combined ||= 0;
	$new_files ||= 0;
	if (@results == 0) {
		return 0 unless @filenames == 0;
	} else {
		if (@filenames == 0) { $filenames[$#results] = 0 }		# if @filenames is empty, fill it with false values
		if (@results != @filenames) { return 0 }				# the lists must have the same number of elements
	}

	my $log_filename = "dtacombiner.txt";
	my ($i, $dta_group, $output, $group_index);
	my $groupnumber_field_length = 5;
	for ($i = 0; $i < @results; $i++) {
		$group_index = $i+1;
		$output .= $group_index . ' ' x ($groupnumber_field_length - length $group_index);
		foreach (@{$results[$i]}) {
			$output .= "$_\n";
			$output .= ' ' x $groupnumber_field_length;
		}
		if ($filenames[$i]) {
			$output .= "\n" . ' ' x $groupnumber_field_length;
			$output .= "Combined into: $filenames[$i]\n\n";
		} else {
			$output .= "\n\n";
		}
	}
	my $now = localtime();
	open(COMBINERLOG, ">>$log_filename") or return 0;
		print COMBINERLOG "CombIon run " . localtime() . "\n";
		print COMBINERLOG "Found ", scalar @results, " groups:\n";
		print COMBINERLOG $output;
		if ($delete_old) {
			print COMBINERLOG $number_combined, " DTA files combined and deleted.  ", $new_files, " new DTA files created.\n";
		} else {
			print COMBINERLOG $number_combined, " DTA files combined (but not deleted).  ", $new_files, " new DTA files created.\n";
		}
		print COMBINERLOG "\n\n";
	close(COMBINERLOG);

	return $log_filename;
}

##PERLDOC##
# Function : get_precursor
# Argument : $dta - the dta file whose precursor will be returned
# Globals  : none
# Returns  : the precursor of the dta file
# Descript : computes and returns the precursor of $dta
# Notes    : does not perform chdir to the directory of $dta - assumes this has already happened
##ENDPERLDOC##
sub get_precursor {
	my $dta = shift;
	my ($mhplus, $z, $prec);
	# open dta file and get mh+ value:
	open(DTA, "$dta") or die "Could not open $dta: $!";
	my $line = <DTA>;
	close(DTA);
	chomp $line;
	($mhplus, $z) = split / /, $line;		# the first token in the dta file is the mh+ value, the second is charge
	$prec = (($mhplus - $Mono_mass{"Hydrogen"}) / $z) + $Mono_mass{"Hydrogen"};	
	return $prec;
}


##PERLDOC##
# Function : combine_dtas
# Argument : First, the name of the combined dta file.
# Argument : Second, a boolean: true to delete old DTAs, false to leave them be
# Argument : Third, the name of the directory containing the DTAs
# Argument : Fourth, a reference to an array of dtas to be combined
# Globals  : none
# Returns  : true if successful
# Descript : combines two or more dta files
# Notes    : 
##ENDPERLDOC##
sub combine_dtas {
	my $resultfilename = shift;
	my $delete_dtas = shift;
	my $dir = shift;
	my @dtas = @{shift()};
	my $mhplus_total = 0;
	my $charge = -1;
	my ($line, $thismhplus, $thischarge, %totals, $mdivz, $intensity, $mhplus_final);
	my ($filename,$totFullScanSumBP,$totFullScanMaxBP,$totZoomScanSumBP,$totZoomScanMaxBP,$totSumTIC,$totMaxTIC) = (0,0,0,0,0,0,0);
	my ($FullScanSumBP,$FullScanMaxBP,$ZoomScanSumBP,$ZoomScanMaxBP,$SumTIC,$MaxTIC);
	my ($dtafile, $outfile);
	foreach $dtafile (@dtas) {
		open DTA, $dtafile or die "Couldn't open $dtafile\n";
		chop($line = <DTA>);
		($thismhplus, $thischarge) = split / /, $line;
		$mhplus_total += $thismhplus;
		if ($charge == -1) {
			$charge = $thischarge;
		}# elsif ($charge != $thischarge) {
		#	close DTA;
		#	die "DTA files have different charge states.\n";
		#}
		while ($line = <DTA>) {
			chop $line;
			($mdivz, $intensity) = split / /, $line;
			$totals{$mdivz} += $intensity;
		}
		close DTA;
		if ($delete_dtas) {
			# might not be a good idea to delete these files before the group DTAs are written, but its more efficient
			unlink $dtafile;
			($outfile = $dtafile) =~ s/\.dta$/.out/i;
			unlink $outfile;
		}
	}
	$mhplus_final = $mhplus_total / ($#dtas + 1);
	open RESULTDTA, ">$resultfilename" or die "Can't open output file $resultfilename\n";
	printf RESULTDTA "%.2f $charge\n", $mhplus_final;
	foreach $mdivz (sort { $a <=> $b} keys %totals) {
		printf RESULTDTA "$mdivz %.1f\n", $totals{$mdivz};
	}
	close RESULTDTA;

	# make lcq_profile.txt reflect these changes
	if (open LCQPROFILE, "<$seqdir/$dir/lcq_profile.txt") {
		$line = <LCQPROFILE>;  # eat column headers
		while ($line = <LCQPROFILE>) {
			chop $line;
			($filename,$FullScanSumBP,$FullScanMaxBP,$ZoomScanSumBP,$ZoomScanMaxBP,$SumTIC,$MaxTIC) = split / /, $line;
			if ($filename and grep { $_ eq $filename } @dtas) {
				$totFullScanSumBP += $FullScanSumBP;
				$totFullScanMaxBP += $FullScanMaxBP;
				$totZoomScanSumBP += $ZoomScanSumBP;
				$totZoomScanMaxBP += $ZoomScanMaxBP;
				$totSumTIC += $SumTIC;
				$totMaxTIC += $MaxTIC;
			}
		}
		close LCQPROFILE;
		if (open LCQPROFILE, ">>$seqdir/$dir/lcq_profile.txt") {
			print LCQPROFILE "$resultfilename $totFullScanSumBP $totFullScanMaxBP $totZoomScanSumBP $totZoomScanMaxBP $totSumTIC $totMaxTIC\n";
			close LCQPROFILE;
		} else {
			print "Warning: couldn't open lcq_profile.txt for writing";
		}
	} else {
		print "Warning: couldn't open lcq_profile.txt for reading";
	}
	return 1;
}

##PERLDOC##
# Function : get_scan_numbers
# Argument : $dta - the DTA file from which to return scan numbers
# Globals  : none
# Returns  : a two element list in which the first element is the DTA's first scan number and the second is the last scan number
# Descript : parses scan numbers out of a DTA file name
# Notes    : 
##ENDPERLDOC##
sub get_scan_numbers {
	my $dta = shift;
	$dta =~ /^[^\.]+\.(\d+)\.(\d+)\.\d\.dta$/;
	return ($1, $2);
}



##PERLDOC##
# Function : output_form
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : This is the output form everyone sees when calling this page with no cgi values defined.
# Notes    : It creates a page header and exits with 0.
##ENDPERLDOC##
#######################################
sub output_form {
	my $sequest_dropbox = make_sequestdropbox("directory");
	print <<EOF;
<form action="$ourname" method="POST">
<table cellspacing=0 cellpadding=0 border=0 width=400>
<tr height=20><td colspan=2></td></tr>
<tr valign="middle">
	<td width=70 class="smallheading">Directory:&nbsp;</td>
	<td>
$sequest_dropbox
	</td>
</tr>
<tr height=25><td colspan=2></td></tr>
<tr>
	<td></td>
	<td class="smallheading">
		Algorithm:
		<table cellspacing=0 cellpadding=0 border=0><tr><td width=85 class="smallheading">
		<input type="radio" name="algorithm" value="muquest">MuQuest
		</td><td class="smalltext">
		(threshold >= <input type="text" name="muquest_threshold" size=4 maxlength=4 value="1.9">)
		</td></tr><tr><td class="smallheading">
		<input type="radio" name="algorithm" value="ionquest" CHECKED>Ionquest
		</td><td class="smalltext">
		(threshold >= <input type="text" name="ionquest_threshold" size=2 maxlength=2 value="42">%)
		</td></tr><tr><td colspan=2 class="smalltext">
		&nbsp;&nbsp;&nbsp;&nbsp;<input type="checkbox" name="ionquest_preprocess">Preprocess
		</td></tr><tr><td colspan=2 class="smalltext">
		&nbsp;&nbsp;&nbsp;&nbsp;<input type="checkbox" name="check_with_muquest" CHECKED>Check with MuQuest:
		</td></tr><tr><td colspan=2>
			<table cellspacing=0 cellpadding=0 border=0><tr><td width=25></td><td class="smalltext">
				If IonQuest results are less than <input type="text" name="ionquest_retest" size=2 maxlength=2 value="48">%, then retest<br>
				using MuQuest, accepting values greater than <input type="text" name="muquest_retest_threshold" size=4 maxlength=4 value="1.7">
			</td></tr></table>
		</td></tr>

		</table><br><br>
		Precursor tolerance:&nbsp;&nbsp;&nbsp;±&nbsp;<input type="text" name="precursor_tolerance" size=3 maxlength=3 value="4.0"> m/z
		<br><br><br>
		<input type="radio" name="combine" value="view" CHECKED>Just view groups<br>
		<input type="radio" name="combine" value="combine">Combine DTAs<br>
		<input type="radio" name="combine" value="combine_and_delete">Combine DTAs and delete originals<br>
	</td>
</tr>
<tr height=25><td colspan=2></td></tr>
<tr>
	<td></td>
	<td><input type="submit" class="button" value="Combine DTAs"></td>
</tr>
</table>
</form>
<br><br><br>
</body>
</html>
EOF

	exit 0;
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
	print "<span>$output</span>";
	exit 1;
}
