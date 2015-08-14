#!/usr/local/bin/perl

#-------------------------------------
#	DTA Ca1,
#	(C)2001 Harvard University
#	
#	W. S. Lane/R.J. Yumol
#
#	v.90
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 02/21/02 by R.J. Yumol
# Last Modified: 02/22/02 by R.J. Yumol
#
# Description: Allows user to calibrate the MH+ or Precursor 
# values in all DTA files of the selected Sequest dir.  MH+ and Precursor
# depend only on the first two numbers in each DTA file (the MH+ and z), 
# the rest of the DTA file data should just pass through untouched.
#
# User may adjust MH+ or Precursor directly, or apply a linear shift to the MH+
# or Precursor across all DTA files in the directory.  The linear shift is initiated
# by checking the "shift linearly by SL" checkbox and filling in a lo MH+/Precursor
# value, lo shift, hi MH+/Prec. value, and hi shift.  These four numbers determine
# a line in the plane whose x-axis is the Prec. or MH+ value, and whose y-axis is
# the shift amount.  The program then reads in the MH+ or Prec. for each DTA, and
# uses the linear function to determine the amount of calibration.
#
# NOTE: the program leaves a backup copy ".bak" of each DTA file that it changes.
# This can easily be changed later if needed.


# rigorous variable checking at compile time
use strict;
use vars qw($webseqdir $seqdir);
use vars qw(%FORM %DEFS_DTACAL $ourname $ourshortname @ordered_names %Mono_mass %fancyname);

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
}

#######################################
# Initial output

&MS_pages_header("DTA Cal","FF00FF");

print "<hr><br>\n";


#######################################
# Fetch data

&cgi_receive;

#######################################
# Flow control

# If there's no directory, get some user input.
if (!defined $FORM{"directory"}) {
	&output_form;
} 

my $submit = defined($FORM{"submit"}) ? $FORM{"submit"} : &error("submit button value undefined: $!");
my $dir = defined($FORM{"directory"}) ? $FORM{"directory"} : &error("directory undefined: $!");
my $cal = defined($FORM{"calibration"}) ? $FORM{"calibration"} : $DEFS_DTACAL{"Calibration"};
my $val_to_adjust = defined($FORM{"changecalibration"}) ? $FORM{"changecalibration"} : $DEFS_DTACAL{"Change Calibration"};
my $linearshift = defined($FORM{"linearshift"}) ? $FORM{"linearshift"} : $DEFS_DTACAL{"Linear Shift"};
my $lo = defined($FORM{"lo_m_over_z"}) ? $FORM{"lo_m_over_z"} : $DEFS_DTACAL{"lo M/z"};
my $lo_s = defined($FORM{"lo_m_over_z_shift"}) ? $FORM{"lo_m_over_z_shift"} : $DEFS_DTACAL{"lo M/z shift"};
my $hi = defined($FORM{"hi_m_over_z"}) ? $FORM{"hi_m_over_z"} : $DEFS_DTACAL{"hi M/z"};
my $hi_s = defined($FORM{"hi_m_over_z_shift"}) ? $FORM{"hi_m_over_z_shift"} : $DEFS_DTACAL{"hi M/z shift"};
my @linedata = ($lo, $lo_s, $hi, $hi_s);

# NOTE: this value is currently unused
my $use_stored_SL = defined($FORM{"use_stored_SL"}) ? $FORM{"use_stored_SL"} : $DEFS_DTACAL{"Use Stored Shift Line"}; 

######################################
# Interpret the form data


if ($submit eq " Cal ") {							# use calibrate function 
  &calibrate($dir, $val_to_adjust, $linearshift, $cal, \@linedata, $use_stored_SL);
} elsif ($submit eq " see error pairs ") {			# just display MH+/Prec deltas in HTML table
  &show_error_pairs($dir, $val_to_adjust); 
} else { &error("unexpected submit button value $submit: $!"); }

my @text = ("Sequest Summary","Back to DTA Cal");
my @links = ("runsummary.pl?directory=$dir&sort=consensus","dtacal.pl");
&WhatDoYouWantToDoNow(\@text, \@links);
exit;


#######################################
# Output form

sub output_form {

my %checked;
$checked{$DEFS_DTACAL{"Change Calibration"}} = " CHECKED";
$checked{$DEFS_DTACAL{"Linear Shift"}} = " CHECKED";
my $dropbox = &make_sequestdropbox("directory");


  print <<EOFORM;
<SCRIPT LANGUAGE="JavaScript">
	<!--
	function toggle_shift_and_cal() {
		var shifttable = document.getElementById('shifttable');
		shifttable.style.display = (shifttable.style.display == 'none')?'block':'none';
		var calibration = document.getElementById('calibration');
		calibration.disabled = (calibration.disabled)?0:1;
	}
	// -->
</SCRIPT>

<FORM ACTION="$ourname" METHOD=GET>
<TABLE>

<TR>
<TH style="text-align:right;"><SPAN CLASS="smallheading">Directory:&nbsp;</SPAN></TH>
<TD COLSPAN=2>$dropbox<INPUT TARGET="new" TYPE=SUBMIT NAME="submit" CLASS=button VALUE=" see error pairs "></TD>
</TR>

<TR>
<TH style="text-align:right;"><SPAN CLASS="smallheading">Change Calibration:&nbsp;</SPAN></TH>
<TD><span class="smalltext"><INPUT TYPE=RADIO NAME="changecalibration" value="precursor"$checked{'Precursor'}>Precursor
	<INPUT TYPE=RADIO NAME="changecalibration" value="mhplus"$checked{'MH+'}>MH+</span></TD>
</TR>
	
<TR>
<TH STYLE="text-align:right;"><span class="smallheading">Calibration:&nbsp;</span></TH>
<TD>
	<TABLE BORDER=0 CELLSPACING=0>
	<TR>
		<TD><INPUT STYLE="text-align:right;" NAME="calibration" VALUE="$DEFS_DTACAL{"Calibration"}" SIZE=5 ID="calibration"></TD>
		<TD><span class="smalltext">&nbsp;Da&nbsp;&nbsp;</span></TD>
		<TD WIDTH=300><span class="smalltext" style="color:FF0000;">*NOTE: Positive value increases the MH+/Prec of all DTAs in dir. Negative value decreases them.</span></TD>
	</TR>
	</TABLE>
</TD>
</TR>

<TR>
<TD>&nbsp;</TD>
<TD><!--   [x] shift by linearly according to SL:
				lo m/z [ 400]    shift [   ]
				hi m/z [2000]    shift [   ] -->

<TABLE BORDER=0 CELLSPACING=0>
<!-- <TR>
	<TD><INPUT TYPE=CHECKBOX NAME="use_stored_SL" VALUE="yes"$checked{"Use Stored Shift Line"}></TD>
	<TD COLSPAN=4><span class="smalltext">use least-squares error shift line (creates/overwrites shift line in dir if necessary)</span></TD>
</TR> -->
<TR>
	<TD><INPUT TYPE=CHECKBOX NAME="linearshift" VALUE="yes"$checked{"Linear Shift"} ONCLICK="toggle_shift_and_cal()"></TD>
	<TD COLSPAN=4><span class="smalltext">shift by linearly according to SL:</span></TD>
</TR>
<TR>
	<TD ROWSPAN=3>&nbsp;</TD>
	<TD>
		<TABLE BORDER=0 CELLSPACING=0 STYLE="display:none;" ID="shifttable">
		<TR>
			<TD>&nbsp;</TD>
			<TD ALIGN=center><span class="smalltext">M/z</span></TD>
			<TD ALIGN=center><span class="smalltext">Da</span></TD>
			<TD>&nbsp;</TD>
		</TR>
		<TR>
			<TD><span class="smalltext">lo&nbsp;</span></TD>
			<TD><INPUT STYLE="text-align:right;" NAME="lo_m_over_z" VALUE="$DEFS_DTACAL{"lo M/z"}" SIZE=5></TD>
			<TD><INPUT STYLE="text-align:right;" NAME="lo_m_over_z_shift" VALUE="$DEFS_DTACAL{"lo M/z shift"}" SIZE=5></TD>
			<TD>&nbsp;</TD>
		</TR>
		<TR>
			<TD><span class="smalltext">hi&nbsp;</span></TD>
			<TD><INPUT STYLE="text-align:right;" NAME="hi_m_over_z" VALUE="$DEFS_DTACAL{"hi M/z"}" SIZE=5></TD>
			<TD><INPUT STYLE="text-align:right;" NAME="hi_m_over_z_shift" VALUE="$DEFS_DTACAL{"hi M/z shift"}" SIZE=5></TD>
			<TD>&nbsp;</TD>
		</TR>
		</TABLE>
	</TD>
</TR>
</TABLE>
</TD>
</TR>
<TR>
<TD>&nbsp;</TD>
<TD><INPUT TYPE=SUBMIT NAME="submit" CLASS=button STYLE="background-color:#DD77EE;" VALUE=" Cal ">
&nbsp;&nbsp;&nbsp;&nbsp;
<span class="smallheading"><A HREF="/Help/help_$ourshortname.html" TARGET="new">Help</A></SPAN></TD>
</TR>

</TABLE>
</FORM>
EOFORM

	exit;
}


#######################################
# Error subroutine
sub error {

	print <<EOF;

<H3>Error:</H3>
<div>
@_
</div>
</body></html>
EOF

	exit 1;

}

##PERLDOC##
# Function : show_error_pairs
# Argument : $dir = name of directory containing DTAs and OUTs to examine
# Argument : $val_to_adjust = "mhplus" | "precursor"	the value to examine 
# Globals  : $seqdir &precision() 
# Returns  : NONE
# Descript : prints HTML table of sequence, spectrum, and delta MH+/Precursor for all DTAs/OUTs in $dir
# Notes    : 
##ENDPERLDOC##
sub show_error_pairs {
	my ($dir, $val_to_adjust) = @_;
    my $fullpath = "$seqdir/$dir/";
	my $dtalist = "checkbox_state.txt";						# list of selected DTAs from summary page 
	opendir (DH, $fullpath)		or &error("can't open $dir");
	open(DTALIST, "<$fullpath$dtalist") or &error("can't open $dtalist: $!");
		my @dtafiles = <DTALIST>;							# grab the dtalist into local var
	close DTALIST;

	print <<EOM;											# start HTML table
<TABLE BORDER=1 CELLSPACING=0 CELLPADDING=0>
	<TR><TH ALIGN=left>directory:</TH><TH COLSPAN=2 ALIGN=left>$dir</TH></TR>
	<TR><TH ALIGN=left>value:</TH><TH COLSPAN=2 ALIGN=left>$val_to_adjust</TH></TR>
	<TR><TH align=right>Sequence</TH><TH align=right>Spectrum</TH><TH align=right>Delta</TH></TR>
EOM

	foreach my $file (@dtafiles) {							# loop through dta list
		my $dta = "$fullpath$file";							# create .dta file path+filename
		my $out = $dta;										# create .out file path+filename
		$out =~ s/\.dta$//;
		chomp($out);
		$out .= ".out";
		open(DTA, "<$dta")		or &error("can't open $dta");
			my ($obs_val, $z) = split(/ /, <DTA>);			# get spectrom mhplus from .dta file
		close DTA;
		my $theo_val = &get_mhplus_from_out($out);			# get sequence mhplus from .out file
		if ($val_to_adjust eq "precursor") {				# compute precursors if necessary
			$theo_val = &precision( (($theo_val - $Mono_mass{"Hydrogen"}) / $z) + $Mono_mass{"Hydrogen"}, 4);
			$obs_val = &precision( (($obs_val - $Mono_mass{"Hydrogen"}) / $z) + $Mono_mass{"Hydrogen"}, 2);
		}
		my $delta = &precision( $theo_val - $obs_val, 3);	# compute delta
		# output table row for this sequence, spectrum, delta
		print "<TR><TD align=right>$theo_val</TD><TD align=right>$obs_val</TD><TD align=right>$delta</TD></TR>";
	}
	print "</TABLE>";										# close table
	close DH;												# close directory
}

##PERLDOC##
# Function : get_mhplus_from_out
# Argument : $file = string containing full path and name of an .out file
# Globals  : NONE
# Returns  : $mhplus | (error if $mhplus <= 0)
# Descript : given an open Sequest directory and .out file name, grabs mhplus from the .out file
# Notes    : Sequest directory must already be open!  this program is just a wrapper for the ugly regexp.
##ENDPERLDOC##
sub get_mhplus_from_out {
	my $file = $_[0];
	$file =~ m/\.out$/ or &error("error: $file is not an .out file");
	my $mhplus;
	open(FILE, "<$file")	or &error("can't open file $file: $!");
	while(<FILE>) {
		# this match looks for line starting with
		# (spaces) 1. (not-slashes) / (spaces) (number) (spaces) (number) (spaces) (mhplus)
		# and grabs the mhplus into argument $2
		if(m/^\s*1\.[^\/]*\/\s*(\d+\s+){2}(\S+)\s/) {
			$mhplus = $2;
			last;
		}
	}
	close(FILE);
	# check for valid mhplus (need more strict checking here)
	$mhplus > 0 or &error("error: invalid mhplus $mhplus");
	return $mhplus;
}

##PERLDOC##
# Function : calibrate
# Argument : $dir = name of Sequest directory to calibrate
# Argument : $val_to_adjust = "mhplus" | "precursor"  determines value to calibrate
# Argument : $linearshift = "yes" | $DEFS_DTACAL{"Linear Shift"}	determines whether constant or linear shift is used
# Argument : $cal = value of constant shift
# Argument : $linedataR = ref. to array ($lo, $lo_s, $hi, $hi_s) = 4 nos. specifying linear shift function
# Argument : $use_stored_SL = ***CURRENTLY UNUSED***
# Globals  : $seqdir &precision() &get_alldirs %fancyname
# Returns  : NONE
# Descript : calibrates DTA files in a Sequest directory by constant or by linear shift
# Notes    : 
##ENDPERLDOC##
sub calibrate {
	my ($dir, $val_to_adjust, $linearshift, $cal, $linedataR, $use_stored_SL) = @_;
	
	my $fullpath = "$seqdir/$dir/";							# build full path
    opendir (DH, $fullpath)		or &error("can't open $dir");
		my @dtafiles = grep /\.dta$/, readdir DH;			# get DTA files from the directory
		foreach my $file (@dtafiles) {						# rename current .dta files to .dta.bak 
			my $curr = "$fullpath$file";
			my $bak = "$fullpath$file.bak";
			rename($curr, $bak)			or &error("can't rename $curr");	# OVERWRITES old .bak files!
		}
	closedir DH;
	
	# read from .dta.bak files, write to .dta files.  original .dta filenames are in @dtafiles
	foreach my $file (@dtafiles) {
		# calibrate this dta file
		&cal_dta ($fullpath, $file, $val_to_adjust, $linearshift, $cal, $linedataR, $use_stored_SL);
	}

	# we're done, output confirmation
	&get_alldirs;			# KLUGE:  need the fancyname for output, but this is not ideal
	print <<EOM;
	<p>
	<div class="normaltext">
	<image src="/images/circle_1.gif">&nbsp;Calibration was successful.<BR>
		 DTAs calibrated: <A HREF="$webseqdir/$dir">$fancyname{$dir}</A>
	</div>
EOM
}

#########################
# cal_dta
# -----------------------
# calibrates a single dta file
##PERLDOC##
# Function : cal_dta
# Argument : $fullpath = the full path to the dta file
# Argument : $file = dta file to calibrate
# Argument : $val_to_adjust = "mhplus" | "precursor"	determines value to calibrate
# Argument : $linearshift = "yes" | DEFS_DTACAL{"Linear Shift"}		determines whether constant or linear shift used
# Argument : $cal = value for constant shift
# Argument : $linedataR = ref. to array containing 4 nos. that determine linear shift
# Argument : $use_stored_SL = ***CURRENTLY UNUSED***
# Globals  : $seqdir &precision()
# Returns  : 
# Descript : calibrates a single dta file
# Notes    : 
##ENDPERLDOC##
sub cal_dta {
	my ($fullpath, $file, $val_to_adjust, $linearshift, $cal, $linedataR, $use_stored_SL) = @_;
	my $bak = "$fullpath$file.bak";							
	my $new = "$fullpath$file";								
	open(BAK, "<$bak")		or &error("can't open $bak");	# open the .dta.bak files for reading 
	open(NEW, ">$new")		or &error("can't open $new");	# and .dta files for writing

	my ($mhplus, $z) = split(/ /, <BAK>);					# get mhplus, z from bak file (1st line)
	chomp($z);

	# branch on the value to adjust
	if($val_to_adjust eq "mhplus") {
		if($linearshift eq "yes") {							# do linear shift on mh+  if needed
			$cal = &precision( &linear_shift($mhplus, $linedataR), 4); 
		}
		$mhplus = &precision( $mhplus + $cal, 2);			# calibrate mh+
	} elsif($val_to_adjust eq "precursor") {
		# if z is undefined or zero, bail
		if (!defined($z) || $z == 0) { &error("can't calculate precursor: z was zero or undefined");}
		# otherwise calculate precursor from mhplus and z
		my $prec = &precision( (($mhplus - $Mono_mass{"Hydrogen"}) / $z) + $Mono_mass{"Hydrogen"}, 4);
		if($linearshift eq "yes") {							# do linear shift on prec. if needed
			$cal = &precision( &linear_shift($prec, $linedataR), 4); 
		}
		$prec += $cal;										# calibrate prec
		# convert precursor back to mhplus
		$mhplus = &precision( ($z * ($prec - $Mono_mass{"Hydrogen"})) + $Mono_mass{"Hydrogen"}, 2);
	} 
	else {
		print "Can't determine value of URL key changecalibration.";	# bail gracefully
		close(BAK); close(NEW); closedir DH;
		exit 0;
	}
	
	(print NEW "$mhplus $z\n") or &error("can't write to $dir/$file");		# write mhplus, z to new file
	while (<BAK>) {											# just pass the rest of bak file to new file
		my @dta_line = split(/ /, $_); 
		chomp $dta_line[1];
		print NEW "$dta_line[0] $dta_line[1]\n";
	}
	
	close(BAK);
	close(NEW);
}

##PERLDOC##
# Function : linear_shift
# Argument : $val = the input to the linear shift function f(x)
# Argument : $linedataR = ref. to array ($x1, $y1, $x2, $y2), 4 numbers determining a line
# Globals  : NONE
# Returns  : f($val), the shift determined by linear shift function for input $val
# Descript : determines line f(x) = m(x - x1) + y1 going through the points (x1, y1) and (x2, y2), returns f($val)
# Notes    : 
##ENDPERLDOC##
sub linear_shift {
	my ($val, $linedataR) = @_;
	my ($x1, $y1, $x2, $y2) = @$linedataR;
	# trap for missing args 
	(defined($x1) && defined($y1) && defined($x2) && defined($y2)) 
	or &error("linear_shift: undefined argument received. Exiting...");

	my $delta_y = $y2 - $y1;				# get delta y
	my $delta_x = $x2 - $x1;				# get delta x

	$delta_x > 0 or &error("division by zero: make sure lo (MH+ or Prec) does not equal hi");

	my $m = $delta_y / $delta_x;			# calculate slope of the line
	my $retval = ($m * ($val - $x1)) + $y1;	# get f(x)
	return $retval;
}

##PERLDOC##
# Function : least_squares
# Argument : @number = list of points (x1, y1, x2, y2,.... xn, yn)
# Globals  : NONE
# Returns  : ($m, $b) = (slope, y-intercept) for a line f(x) = mx + b
# Descript : gets best-fit least-squares line, given a list of point coords (x1, y1, x2, y2,.... xn, yn)
# Notes    : ...theory and equations from http://www.efunda.com/math/leastsquares/lstsqr1dcurve.cfm
##ENDPERLDOC##
sub least_squares {
	my @number = @_;
	defined(@number) or &error("error: undefined arguments");
	my ($x, $y, $sum_x, $sum_x_sqrd, $sum_y, $sum_xy);

	$sum_x = $sum_y = $sum_xy = 0;

	# accumulate 
	#	n			the number of points
	#	sum(x)		sum of x-coords
	#	sum(x^2)	sum of squares of x-coords
	#	sum(y)		sum of y-coords
	#	sum(xy)		sum of all xy (where each coord is from the same point)
	my $n = 0;
	foreach  (@number) {
		if($n%2 == 0) {					# this is an x-coord
			$x = $_;					# store x for later multiplication
			$sum_x += $x;				# accumulate sum(x)
			$sum_x_sqrd += $x * $x		# accumulate sum(x^2)
		} else {						# this is a y-coord
			$y = $_;					# store y for multiplication
			$sum_y += $y;				# accumulate sum(y)
			$sum_xy += $x * $y;			# accumulate sum(xy)
		}
		$n++;							# accumulate n 
	}
	# check for even num. of args (each point should have a coord pair)
	$n%2 == 0 or &error("error: odd number of arguments received");
	
	$n /= 2;							# we actually accumulated 2n, so divide by 2

    # now we have the necessary numbers to calculate the
	# least squares line y = ax + b
    my $denom = $n * $sum_x_sqrd - $sum_x * $sum_x;
	$denom > 0 or &error("division by zero");
	my $m = ( $n * $sum_xy - $sum_x * $sum_y ) / $denom;				# slope
	my $b = ( $sum_y * $sum_x_sqrd - $sum_x * $sum_xy ) / $denom;		# y-intercept

	return ($m, $b);
}