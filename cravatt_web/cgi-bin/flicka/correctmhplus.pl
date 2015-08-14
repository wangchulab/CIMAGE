#!/usr/local/bin/perl

#-------------------------------------
#	
#	(C)2002 Harvard University
#	
#	W. S. Lane/E. Perez
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------

##MICROCHEM_FILE##


################################################
# Created: 09/07/01
# most recent update: 
#
#	This is used to correct the value of MH+ on high quality 2+ spectra, and maybe some 1+ and 2+ spectra
#	It finds by ion pairs in the spectrum (without using sequest results) and uses them to estimate MH+

##################################################
#
# Globals
#
$PAIRS_TOLERANCE = 3.0;
$MODE_TOLERANCE = 0.32;
#$MHPLUS_TABLE_FILE 	# var moved to microchem_include 
$TOTAL_ERROR_BEFORE = 0;
$TOTAL_ERROR_AFTER = 0;
$TOTAL_ABSOLUTE_ERROR_BEFORE = 0;
$TOTAL_ABSOLUTE_ERROR_AFTER = 0;
$TOTAL_ADJUSTMENT = 0;
$FILES_PROCESSED = 0;
$FILES_CHANGED = 0;



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
	require "selectpeaks_include.pl";
	require "html_include.pl";
	require "status_include.pl";
}


#######################################
# Fetching data
#
# This includes, CGI-receive, database lookups, command line options, etc.  
# All data that the script exports dynamically from the outside.
&cgi_receive;
$dir = $FORM{"directory"};
$MakeChanges = $FORM{"MakeChanges"};
#$KeepPtas = $FORM{"Keep Ptas"};				This is only used in development/testing this is disabled for normal use of the code


#######################################
# Initial output
&MS_pages_header("CorrectIon","#871F78");


#######################################
# Flow control
if (!defined $dir) {
	&choose_directory;
} else {
	&watch_over_me;
	&main;
}

exit 1;

######################################
# Main action

sub main{

	print "<hr><p>";
	&javastuff;

	#get the list of all DTA files actually in the directory
	@all_files = &get_DTA_file_list;

	# set up the table
	open SLF, ">$seqdir/$dir/mhstuff.txt";
	open TABLE, ">$seqdir/$dir/$MHPLUS_TABLE_FILE" or &error("Could not write file $seqdir/$dir/$MHPLUS_TABLE_FILE");
	&print_header();

	#@two_plus_files = grep /\.2\.dta$/, @all_files;
	#@one_plus_files = grep /\.1\.dta$/, @all_files;
	#@two_plus_files = push @two_plus_files, @one_plus_files

	#@two_plus_files = 	@all_files;
	foreach(@all_files){
		push @two_plus_files, $_ unless($_ =~ /\.3\./);
	}

	map {$_ = "$seqdir/$dir/" . $_} @two_plus_files;

	print "<span class='smallheading'>Running CorrectIon on Directory $dir...</span><br><br>";
	# setup a progress bar
	my($progbar) = &create_progress_bar(incrementpercent => 2.5, description => "Progress");  
	print $progbar->{bar};
	my($progress, $next_percent, $max_progress);
	$progress = 0;
	$next_percent = 0.025;
	$max_progress = scalar(@two_plus_files);

	foreach $file (@two_plus_files) {
		$dummy = &process_one_dta($file);
		# progress bar stuff
		$progress++;
		while (($progress / $max_progress) >= $next_percent) {
			$next_percent += 0.025;
			print $progbar->{inc};
		}
	}

	print "<br>";
	print $progbar->{done};

	close SLF;
	print TABLE "</table>";

	&print_summary_stats() if($FILES_PROCESSED);
	close TABLE;

	#display the output
	open TABLE, "$seqdir/$dir/$MHPLUS_TABLE_FILE";
	my(@table) = <TABLE>;
	foreach(@table){
		print "$_";
	}

	# write to the logfile only if we actually made some irreversible change on the directory 06/25/2000
	&write_log($dir,"CorrectIon run " . localtime()) if($MakeChanges);

}


sub print_header{
	print TABLE "<table cellpadding=2 cellspacing=5 >";
	print TABLE "<tr>";
	print TABLE "<td align='center'><span class='smallheading'>dta:</td>";
	print TABLE "<td><span class='smallheading'>Original MH+</td>";
	print TABLE "<td><span class='smallheading'>New MH+</td>";
	if($OUTFILES_EXIST){
		print TABLE "<td><span class='smallheading'>Seqest MH+</td>";
		print TABLE "<td><span class='smallheading'>new delM</td>";
		print TABLE "<td><span class='smallheading'>Improvement</td>";
	}
	if($KeepPtas){
		print TABLE "<td><span class='smallheading'>pta</td>";
	}
	print TABLE "<td><span class='smallheading'>ions</td>";
	print TABLE "</tr>";
}

sub print_summary_stats{
	
	$AVG_ERROR_BEFORE = $TOTAL_ERROR_BEFORE / $FILES_PROCESSED;
	$AVG_ERROR_AFTER = $TOTAL_ERROR_AFTER / $FILES_PROCESSED;
	$AVG_ABSOLUTE_ERROR_BEFORE = $TOTAL_ABSOLUTE_ERROR_BEFORE / $FILES_PROCESSED;
	$AVG_ABSOLUTE_ERROR_AFTER = $TOTAL_ABSOLUTE_ERROR_AFTER / $FILES_PROCESSED;
	$AVG_ADJUSTMENT = &precision( $TOTAL_ADJUSTMENT / $FILES_PROCESSED , 2);

	print TABLE "<br><div>";
	if($OUTFILES_EXIST){
		print TABLE "<span class='smallheading'>avg error before: </span><span class='smalltext'>$AVG_ERROR_BEFORE</span> <Br>";
		print TABLE "<span class='smallheading'>avg error after: </span><span class='smalltext'>$AVG_ERROR_AFTER </span><Br>";
		print TABLE "<span class='smallheading'>avg absolute error before: </span><span class='smalltext'>$AVG_ABSOLUTE_ERROR_BEFORE </span><br>";
		print TABLE "<span class='smallheading'>avg absolute error after: </span><span class='smalltext'>$AVG_ABSOLUTE_ERROR_AFTER </span><br>";
	}
	print TABLE "<span class='smallheading'>avg adjustment: </span><span class='smalltext'>$AVG_ADJUSTMENT </span><br>";
	
}

# get_DTA_file_list
# Returns an array of strings which are the names of DTA files in the chosen directory
sub get_DTA_file_list{
	my(@list,@DTAlist,$name);
	opendir DIR , "$seqdir/$dir" or &error("Couldn't open directory");
	@list = readdir DIR;
	foreach $name (@list) {
		#$OUTFILES_EXIST = 1 if($name =~ /\.out$/);			This feature was used in development. It is now inactive, but I don't want to erase the code
													#		in case we want to do more quality control in the future
		if ($name =~ /\.dta$/) {
			push @DTAlist, $name;
		}
	}
	return(@DTAlist);
}

# Find MH plus
# input is one dta.
sub process_one_dta {

	my($dta) = pop @_;

	# preprocess the dta
	my($pta) = &preprocess_dta($dta);

	# display stuff
	$shortdta = $dta;
	$shortdta =~ s/^.*\///;
	print TABLE qq(<tr><td><span class="smalltext"><a href="$fuzzyions?dtafile=$seqdir/$dir/$shortdta" target="_blank">$shortdta</a></dta></td>);

	# find the b-y fragment ion pairs
	my(@pairs) = &find_by_pairs($pta);

	# use the pairs to estimate mh+
	my($new_mhplus) = &find_mhplus($dta,@pairs);

	# only used in development. Erase this afterwards
	my($true_mhplus);
	if($OUTFILES_EXIST){
		$true_mhplus = &grab_mh_plus_from_outfile($dta);
		my($out) = $dta;
		$out =~ s/dta$/out/;
		print TABLE qq(<td align=center><span class='smalltext'><a href="$showout?OutFile=$out" target="_blank">$true_mhplus</a></td>);
		my($delM) = $new_mhplus ? $true_mhplus - $new_mhplus : $true_mhplus - $CURRENT_MHPLUS;
		$delM = &precision($delM,2);
		print TABLE qq(<td align=center><span class='smalltext'>$delM</td>);
	}

	# update summary stats
	$TOTAL_ERROR_BEFORE += ($CURRENT_MHPLUS - $true_mhplus);
	$TOTAL_ERROR_AFTER += $new_mhplus ? ($new_mhplus - $true_mhplus) : ($CURRENT_MHPLUS - $true_mhplus);
	$TOTAL_ABSOLUTE_ERROR_BEFORE += abs($CURRENT_MHPLUS - $true_mhplus);
	$TOTAL_ABSOLUTE_ERROR_AFTER += $new_mhplus ? abs($new_mhplus - $true_mhplus) : abs($CURRENT_MHPLUS - $true_mhplus);
	$TOTAL_ADJUSTMENT += $new_mhplus ? ($new_mhplus - $CURRENT_MHPLUS) : 0;
	$FILES_PROCESSED += 1;
	$FILES_CHANGED++ if($new_mhplus);

	&set_mh_plus($dta,$new_mhplus) if($MakeChanges and $new_mhplus);

	if($OUTFILES_EXIST){
		my($improvement) =  $new_mhplus ? abs($CURRENT_MHPLUS - $true_mhplus) - abs($new_mhplus - $true_mhplus) : 0;
		$improvement = &precision($improvement,2);
		print TABLE qq(<td align=center><span class='smalltext'>$improvement</span></td>);
	}

	# either delete the preprocessed dta file or print a link to it
	$pta =~ s/\//\\/g;
	if($KeepPtas){
		print TABLE qq(<td align=center><a href="$thumbnails?Dta=$dta&Dta=$pta" target="_blank">pta</a></td>);
	}else{
		unlink "$pta" || die "Can't delete $pta";
	}

	print TABLE qq!<td align=center><img src="/images/tree_closed.gif" id="frags_${FILES_PROCESSED}" onclick="javascript:toggleGroupDisplay(this)" style="cursor:hand"><span id="frags_${FILES_PROCESSED}_" style="display:none">$FRAGMENT_IONS</span></td>!;
	$FRAGMENT_IONS = ();

	print TABLE "</tr>";
}

##PERLDOC##
# Function : find_by_pairs
# Argument : full path name of a preprocessed dta file
# Globals  : 
# Returns  : a list strings, each of which contains three floating points separated by a single space. The numbers are m/z each ion of a b-y pair and total intensity of the pair
# Descript : picks b-y ion pairs out of a preprocessed dta file. Also prints the dta file's mhplus to the table file
# Notes    : 
##ENDPERLDOC##
sub find_by_pairs{

	my($dta) = pop @_;
	my($z) = ($dta =~ /\.(\d)\./);

	my($shortdta) = $dta;
	$shortdta =~ s/\.pta$/\.dta/ ;
	$shortdta =~ s/.*\/// ;

	#&error("mh plus correction not yet implemented for charge states other than 2") unless($z == 2);
	
	open DTA, $dta or &error("Could not open $dta");

	# collect the mh+ and m/z values from the dta file
	my(@ions);
	my $header = <DTA>;
	my($mhplus,$zz) = split /\s/, $header;
	print TABLE "<td align=center><span class='smalltext'><A href='$webseqdir/$dir/$shortdta' target=_blank>$mhplus</a></td>";
	$CURRENT_MHPLUS = $mhplus;			# this ever so ugly global variable is set for the sake of accounting for summary stats

	%intensity = ();
	while (<DTA>){
		my($mass,$intensity) = split / /;
		push @ions, $mass;
		$intensity{$mass} = $intensity;
	}

	# loop through the ions looking for pairs
	# THIS CAN BE WRITTEN MORE EFFICIENTLY, but hey, the preprocessed files are pretty darn small.
	my($b,$y,@pairs);
	foreach $b (@ions) {
		foreach $y (@ions) {
			next if($y < $b);
			if( abs( ($b + $y - $Mono_mass{"Hydrogen"}) - $mhplus) < $PAIRS_TOLERANCE ){
				my($totalintensity) = $intensity{$b} + $intensity{$y};
				push @pairs, "$b $y $totalintensity" ;
			}
		}
	}

	close DTA;

	return(@pairs);
}


sub find_mhplus{
	
	my($dta) = shift;
	my(@pairs) = @_;
	my($num_pairs) = 0;
	my($totalEstimate) = 0;
	my(@estimates) = ();

	# don't make an attempt if there are not enough ion pairs
	if(scalar @pairs < 3){
		print TABLE "<td><span class='smallheading'>nd</td>";
		return;
	}

	$FRAGMENT_IONS = "<table><tr><td><span class='smallheading'>ion1</td><td><span class='smallheading'>ion2</td><td><span class='smallheading'>intensity</td><td><span class='smallheading'>estimate</td></tr>";

	foreach  (@pairs) {

		($b,$y,$intensity) = split / /;

		my($estimate) = $b + $y - $Mono_mass{"Hydrogen"};
		$totalEstimate += $estimate;
		push @estimates, $estimate;
		
		$intensity = &precision($intensity,0,8," ");							#this makes things line up nicely in columns
		$FRAGMENT_IONS .= "<tr><td><span class='smalltext'>$b</td><td><span class='smalltext'>$y</td><td><span class='smalltext'>$intensity</td><td><span class='smalltext'>$estimate</td></tr>";
		$num_pairs++;
		
	}
	$FRAGMENT_IONS .= "</table>";

	# if possible just returnt the mode as the estimate. If not use the mean
	my($mode) = &get_mode(@estimates);
	if($mode){
		$mode = &precision($mode,2);
		print TABLE "<td> <a href='$webcgi/displayions.exe?Dta=$dta'  target='_blank'><span class='smalltext'>$mode</a> </td>";
		return($mode);
	}


	# get the mean and standard deviation
	my($sampleVar);
	my($meanEstimate) = $num_pairs ? $totalEstimate / $num_pairs : "nd";
	foreach  (@estimates) {
		$sampleVar += sqrt( ($_ - $meanEstimate) * ($_ - $meanEstimate) );
	}
	$sampleVar = $num_pairs ? $sampleVar / $num_pairs : "0";
	

	my($betterTotal) = 0;
	my($betterCount) = 0;
	my(@rejected);
	foreach  (@estimates) {
		if( $sampleVar == 0  or abs($_ - $meanEstimate) < (2 * $sampleVar)){
			$betterCount++;
			$betterTotal += ($_);
		}else{
			push @rejected, ($_);
		}
	}

	my($betterEstimate) = $betterCount ?  $betterTotal / $betterCount : "nd";
	$betterEstimate = &precision($betterEstimate,2);
	print TABLE "<td> <a href='$webcgi/displayions.exe?Dta=$dta'  target='_blank'><span class='smalltext'>$betterEstimate</a> </td>";
	
	return($betterEstimate);
}

# &get_mode
# given a list of numbers, it looks for at least three numbers within MODE_TOLERANCE of each other. It returns their average. If no such
# numbers exist, it returns zero
sub get_mode{

	my(@nums) = @_;
	return(0) if(scalar @nums < 3);

	@nums = sort {$a <=> $b} @nums;
	
	#print "<br><br> nums: @nums <br>";

	my($j) = 2;
	my($n) = scalar @nums;
	my($i);
	my($ii,$mode) = (0,0);
	for($i=0; $i<($n - 2); $i++, $j++){
		if($nums[$j] - $nums[$i] < $MODE_TOLERANCE){

			while( ($j < ($n -1)) and ( ($nums[$j+1] - $nums[$i]) < $MODE_TOLERANCE)){		# greedily include as many as possible
				$j++;			
			}

			# return the average of everything in range

			#print "sum of ";
			for($ii = 0; $ii <= ($j - $i); $ii++){
				$mode += $nums[$ii + $i];
				#print " $nums[$ii + $i] ";
			}
			#print "is $mode <br>";
			#print "considering that there are $ii numbers, avg ";
			$mode = $mode / $ii;
			#print "is $mode <br><Br>";
			return($mode);
		}
	}

	# we never met the condition. no mode found
	#print " The mode of @nums is 0 <br>";
	return(0);
}

sub set_mh_plus{

	my($dta,$newMH) = @_;

	open(DTAFILE, "$dta");
	my($mhplus, $z) = split / /, <DTAFILE>;
	chomp $z;

	my(@lines);
	while(<DTAFILE>){
		push @lines, $_;
	}

	close DTAFILE;

	#okay, we read it, now rewrite it;
	open DTAFILE, ">$dta";
	print DTAFILE "$newMH $z\n";

	# do the rest of the rewrite ala funny code in chargestate.pl
	foreach $line (@lines) {
		$line =~ s/^\s+// ;		# This line of code is neccesary though I know not why. This remains one of life's larger mysteries.
		print DTAFILE "$line";
	}
	close DTAFILE;

}

# grab_mh_plus_from_outfile
# This function is only needed in development. The mhplus of the top ranked sequence in the outfile is our best indication of the "correct"
# MH+, so we need to compare that to our result as a means of qualification. 
# input is name (full path) of the dta file, output is mh+
sub grab_mh_plus_from_outfile{
	
	my($mhplus,$dta,$out);
	$dta = pop;
	$dta =~ s/dta$/out/;
	$out = $dta;

	open OTF, "$out" or &error("cannot open file: $out");
	my($one, $theOther);
	while (<OTF>) {
		if ($_ = /^\s*1\.\s+\d+\s*\/\s*\d+\s*(\S*)\s+(\S*)/){		# see comment/apology below
			my($temp1,$temp2) = ($1,$2);						# this line is necessary because scoping of $1 and $2 is very wierd
			$mhplus = ($temp1 =~ /\./) ? $temp1 : $temp2;		# this is a shameful hack. Some outfiles have an id number for each seq, some don't. MH plus has a decimal, id doesn't. Sorry.
			last;
		}
	}
	close OTF;

	return($mhplus);

	die;
}


#######################################
# Main form subroutines

# note that we're going to take the defaults from GBU, since these two scripts are so closely tied in to one another
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

<TR>
	<td><span class="smallheading">Make Changes?</span></td>
	<td><INPUT type="checkbox" name="MakeChanges" value="yes" checked></td>
</TR>
<TR><TD>
	<TD><INPUT type="submit" class="button" value="Select">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<span class="normaltext"><A HREF="$webhelpdir/help_$ourshortname.html">Help</A></span></TD>
</TR></Table>
</Form></Body></HTML>

DONE
}

sub javastuff{

	print <<EOF;
<SCRIPT LANGUAGE="Javascript">
<!--

function toggleGroupDisplay(toggleButton)
{
	var groupSpanId = toggleButton.id + "_";
	var groupSpan = document.getElementById(groupSpanId);

	if (groupSpan.style.display=="none") {
		toggleButton.src = "/images/tree_open.gif";
		groupSpan.style.display = "";
	} else {
		toggleButton.src = "/images/tree_closed.gif";
		groupSpan.style.display = "none";
	}
}


//-->
</SCRIPT>
EOF
}

#######################################
# Error subroutine
# Informs user of various errors, mainly I/O

sub error {


		print <<ERRMESG;
	<HR><p>
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
ERRMESG

	exit 1;
}

sub byintensity_dec {$intensity{$b} <=> $intensity{$a}};
sub byintensity_inc {$intensity{$a} <=> $intensity{$b}};				
sub bymass {$b <=> $a};


# End of mh_plus_correction.pl