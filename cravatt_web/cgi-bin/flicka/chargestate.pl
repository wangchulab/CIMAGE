#!/usr/local/bin/perl

#-------------------------------------
#	Charge State Determination
#	(C)1999 Harvard University
#	
#	 W. S. Lane/D. P. Jetchev/R. E. Perez
#	
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



#
#	This application determines the true chagre state of dta files (or multiple states if the result is ambiguous) and rewrites or deletes the dtas accordingly.
#	This file contains only the code for the i/o of the application. Tests for determining charge state are coded in
#	ChargeState_include.pl, and the various test results are combined by a C++ implementation of a neural net. 
#




################################################
# Created: 06/12/01 by Dimitar Jetchev
# Last Modified: 08/22/01 by Edward Perez

$showIntermediateScores = 1;
$CSD_delete_count = 0;
@TABLE_LINES = ();

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
	require "goodbadugly_include.pl";
	require "chargestate_include.pl";
	require "status_include.pl";
}

# default values for adjusting the algorithm
$default_num_ions = 200;
$default_top_above_ions = 5;
$default_tolerance = '3.0';	
$default_window = '1.0';
	
&cgi_receive();
&MS_pages_header( "ZSA&copy; Charge State Algorithm","#8800FF","tabvalues=<HR>" );
	
$dir = $FORM{"directory"};
$dtas = $FORM{"dtas"};
$num_ions = ( $FORM{"num_ions"} || $default_num_ions );
$top_above_ions = ( $FORM{"top_above_ions"} || $default_top_above_ions );						
$tolerance = ( $FORM{"tolerance"} || $default_tolerance );
$window = ( $FORM{"window"} || $default_window ); 
$operator = $FORM{"operator"};
$copyouts = $FORM{"CopyOuts"};
$number_of_ions = ( $FORM{"num_ions"} || $default_num_ions );
$cloneddir = $FORM{"ClonedDir"};
$dirtag = ( $FORM{"DirTag"} );				
$clonefirst = $FORM{"clonefirst"};
$Min_MHplus = $FORM{"Min_MHplus"} || $DEFS_DETERMINECHARGE{'Minimum MH+'};
$Max_MHplus = $FORM{"Max_MHplus"}  || $DEFS_DETERMINECHARGE{'Maximum MH+'};
$TrustOnePlus = $FORM{"TrustOnePlus"};


# output form; 	
if (! defined $dir) {
	&output_form;
}
# clone the directory;
elsif ( $clonefirst eq "yes") {
		if(&clone_dir){
			$cloneddir = $dir;
			&watch_over_me();
			&main;
		}
}

# run the test engine on the new directory 
else {
	$cloneddir = $dir;
	&watch_over_me();
	&main;
}



sub main{
	require "javascript_include.pl";
	require "html_include.pl";
	
	$cwd = "$seqdir/$cloneddir";
	chdir $cwd or &error("Couldn't open the required directory \n");
	opendir(CURRDIR, ".") or &error("Couldn't open the required directory \n");
	@all_files = readdir CURRDIR;
	closedir(CURRDIR);
	
	@dtas = grep /dta$/, @all_files;
	@outs = grep /out$/, @all_files;
	$dtas_before = scalar @dtas;

	# hashes for prefix of filename, charge state, and root 
	%prefix = ();
	%charge = ();	
	%root = ();
	%representatives = ();
	foreach $dta (@dtas) {
		open (DTAFILE, "< $seqdir/$cloneddir/$dta");
		($mhplus, $z) = split / /, <DTAFILE>;
		close (DTAFILE);
		$dta =~ m/^(.*)\..\.dta$/;
		$prefix{$dta} = $1;
		$charge{$dta} = $z;
		($root{$dta}) = ($dta =~ /(.*)\.\d\.dta/); 
		$precursor{$root{$dta}} = (($mhplus - $Mono_mass{'Hydrogen'}) / $z) + $Mono_mass{'Hydrogen'};
		if( not exists $representatives{$root{$dta}}){
			$representatives{$root{$dta}} = $dta;
			$second_dta{$root{$dta}} = 0;
		}else{
			$second_dta{$root{$dta}} = $dta;
		}
	
	}	

	print ("<TABLE width=100%><TR><TD><span class='smallheading'>Running tests...</span><TD align=right>");
	scriptClock("clocklabel", "Execution Time: ");
	print ("</TD></TR></TABLE><BR>");
	loadJavaScriptClock("MicrosoftClock", "NetscapeClock", 0, 1);

	&make_input_table(@dtas);

	#classify the dtas
	print "<span class='smallheading'>Determining charge from test results...<br><br>";
	`$classify`;

	#pull the results out of the file
	open RES, "$ChargeStateResults";
	while (<RES>) {
		($dta, $s1, $s2, $s3) = split / /;
		$score1{$dta} = &precision($s1,2);
		$score2{$dta} = &precision($s2,2);
		$score3{$dta} = &precision($s3,2);
	}
	close RES;

	my($root);
	foreach $root (keys %representatives) {

		$dta = $representatives{$root};

		@newZ = &determine_charge_state($dta);

		&set_charge($representatives{$root},$second_dta{$root},@newZ);

		# keep track of delete count
		$CSD_delete_count++ if($newZ[0]==0 and $newZ[1]==0);

		# print results to screen and to file
		&save_table_entry($root,@newZ);
		
	}

	&print_table("$seqdir/$cloneddir/$csd_html_output");

	# delete files that are no longer needed
	unlink "$ChargeStateResults";
	unlink "$ChargeStateDataFile";

	chdir $cwd or &error("Couldn't open the required directory \n");
	opendir(CURRDIR, ".") or &error("Couldn't open the required directory \n");
	@all_files = readdir CURRDIR;
	closedir(CURRDIR);
	
	@dtas = grep /dta$/, @all_files;
	$dtas_after = scalar @dtas;

	&write_csd_info_to_log();

}


sub write_csd_info_to_log{
	my($entry) = "ZSA " . localtime();
	$entry .= " by " . $operator if($operator);
	$entry .= " $CSD_delete_count DTA-sets deleted. $dtas_before dtas corrected to $dtas_after";
	&write_log($cloneddir, $entry);
}


#############################################################################################
#
#
#		Code for finding charge state
#
#
#############################################################################################

# This is the subroutine that decides what charge state should be
# return value is the "true" charge state(s).
# This function always return two charge states, but in cases where only one is needed, the second return value is 0.
sub determine_charge_state{

	my($dta) = $_[0];

	# In some cases we just leave 1+ spectra alone
	$zta = $dta;
	$zta =~ s/.dta$/.zta/;
	if($TrustOnePlus and (not -e $zta) and $charge{$dta} == 1 and not $second_dta{$root{$dta}}){
		return((1, 0));
	}

	my($max,$winner,$runnerup);
	my(@rv) = ();
	my(@scores) = (0, $score1{$dta}, $score2{$dta}, $score3{$dta});
	my(@runnerup);

	#find the max of 3, fun, fun, fun
	if($score1{$dta} >= $score2{$dta} and $score1{$dta} >= $score3{$dta}){
		$max = $score1{$dta};
		$winner = 1;
	}elsif($score2{$dta} >= $score1{$dta} and $score2{$dta} >= $score3{$dta}){
		$max = $score2{$dta};
		$winner = 2;
	}elsif($score3{$dta} >= $score2{$dta} and $score3{$dta} >= $score1{$dta}){
		$max = $score3{$dta};
		$winner = 3;
	}else{
		&error("Couldn't interpret scores");
	}

	push @rv, $winner;

	# if the top score was weak, we assign a charge state pair. 
	# That means that this function returns best and 2nd best charge states
	if($max < 0.75){
		foreach $i ((1, 2, 3)){
			next if( $i == $winner);
			push @runnerup, $i;
		}

		push @rv, ($scores[$runnerup[0]] > $scores[$runnerup[1]]) ? $runnerup[0] : $runnerup[1] ;  
	}else{
		push @rv, 0;
	}

	# now we need to make sure that the mh+ for the new z is in range. If not don't bother with assigning the new charge state
	my($mh1,$mh2) =  (($precursor{$root{$dta}} - $Mono_mass{'Hydrogen'}) * $rv[0] + $Mono_mass{'Hydrogen'} , ($precursor{$root{$dta}} - $Mono_mass{'Hydrogen'}) * $rv[1] + $Mono_mass{'Hydrogen'} ); 
	if(  $mh1 < $Min_MHplus or $mh1 > $Max_MHplus){
		$rv[0] = 0;
	}
	if(  $mh2 < $Min_MHplus or $mh2 > $Max_MHplus){
		$rv[1] = 0;
	}
	if( $rv[0] == 0){
		$rv[0] = $rv[1];
		$rv[1] = 0;
	}


	return(@rv);
}
 

###########################################################################################
#
#
#		HTML stuff
#
#
###########################################################################################


sub print_table_header{

	my($fname) = pop @_;

	# This seemingly needles repetition of code is actually necessary to make this function compliant with the nanny (the code in status_include.pl)

	if($fname){
		print FOUT  "<div><span class='smallheading'>Corrections for directory $cloneddir: </span> <br><br>";
		print FOUT "<table cellspacing=0 cellpadding=0>";
		print FOUT "<tr><td align=left><span class='smallheading'>Scan:</span></td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		print FOUT "<td align=left><span class='smallheading'>Old z:</td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		print FOUT "<td align=left><span class='smallheading'>New z:</td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		print FOUT "<td align=left><span class='smallheading'>1+</td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		print FOUT "<td align=left><span class='smallheading'>2+</td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		print FOUT "<td align=left><span class='smallheading'>3+</td>";
		print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
		if($showIntermediateScores){
			print FOUT "<td align=left><span class='smallheading'>Water</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>XCorr</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>B-Y</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'> > prec</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>%TIC > 2*prec</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>%TIC > prec</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>2*prec</td>";
			print FOUT "<td>&nbsp;&nbsp;&nbsp;</td>";
			print FOUT "<td align=left><span class='smallheading'>3+ ions</td>";
		}
		print FOUT "<tr>";
	}else{
		print "<div><span class='smallheading'>Corrections for directory $cloneddir: </span> <br><br>";
		print "<table cellspacing=0 cellpadding=0>";
		print "<tr><td align=left><span class='smallheading'>Scan:</span></td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		print "<td align=left><span class='smallheading'>Old z:</td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		print "<td align=left><span class='smallheading'>New z:</td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		print "<td align=left><span class='smallheading'>1+</td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		print "<td align=left><span class='smallheading'>2+</td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		print "<td align=left><span class='smallheading'>3+</td>";
		print "<td>&nbsp;&nbsp;&nbsp;</td>";
		if($showIntermediateScores){
			print "<td align=left><span class='smallheading'>Water</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>XCorr</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>B-Y</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'> > prec</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>%TIC > 2*prec</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>%TIC > prec</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>2*prec</td>";
			print "<td>&nbsp;&nbsp;&nbsp;</td>";
			print "<td align=left><span class='smallheading'>3+ ions</td>";
		}
		print "<tr>";
	}
}


sub save_table_entry{

	my($root,$newZ1,$newZ2,$fname) = @_;
	my($newName,$ChangedOrNot,$oldZ1,$oldZ2,$dta,$zstring,$oldzstring,$dta2);

	$dta = $representatives{$root};

	# get scan number
	$dta =~ /$dtaScanRE/;
	$scan = $1;

	# sort out the new charge state(s) and appropriate link(s) 
	$newName1 = "$root{$dta}.$newZ1.dta";
	$link1 = "$displayions?dtafile=$seqdir/$cloneddir/$newName1";
	$zstring = "<a href=$link1 target='_blank'>$newZ1\+</a>";
	if($newZ2){
		$newName2 = "$root{$dta}.$newZ2.dta";
		$link2 = "$displayions?dtafile=$seqdir/$cloneddir/$newName2";
		$zstring = $zstring . "/<a href=$link2 target='_blank'>$newZ2\+</a>";
	}else{
		$newZ2 = 0;
	}
	# but watch out for the case where we just plain delete it
	if( (not $newZ1) and (not $newZ2)){
		$zstring = "---";
	}

	# do the same for the old
	# sort out the new charge state(s) and appropriate link(s) 
	$oldName1 = "$dta";
	$oldZ1 = &dta_to_z($dta);
	if($clonefirst){
		$oldlink1 = "$displayions?dtafile=$seqdir/$originaldir/$oldName1";
		$oldzstring = "<a href=$oldlink1 target='_blank'>$oldZ1\+</a>";
	}else{
		$oldzstring = "$oldZ1\+";
	}
	$dta2 = $second_dta{$root};
	my($oldName2) = $dta2;
	if($dta2){
		$oldZ2 = &dta_to_z($dta2);
		$newName2 = "$root{$dta}.$newZ2.dta";
		if($clonefirst){
			$oldlink2 = "$displayions?dtafile=$seqdir/$originaldir/$oldName2";
			$oldzstring = $oldzstring . "/<a href=$oldlink2 target='_blank'>$oldZ2\+</a>";
		}else{
			$oldzstring = $oldzstring . "/$oldZ2\+";
		}
	}else{
		$oldZ2 = 0;
	}

	# see if any change was made
	my(@oldlst,@newlst);
	my(@oldlst) = sort ($oldZ1, $oldZ2);
	my(@newlst) = sort ($newZ1, $newZ2);
	$zstring = "" if($oldlst[0] == $newlst[0] and $oldlst[1] == $newlst[1]);

	my ($dtaAgain, $ionsAbove, $WaterLoss1, $WaterLoss2, $WaterLoss3, $corrScore, $BYtest, $TwicePrec, $TICabove, 
		$two_times_prec_in_range, $evidence) = &get_line_from_input_table($dta);

	$WaterLoss3 = &precision($WaterLoss3, 3);
	$corrScore = &precision($corrScore, 2);
	
	$THIS_LINE = "";

	$THIS_LINE .= "<tr><td align=left><span class='smalltext'>$scan</span></td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	$THIS_LINE .= "<td align=center><span class='smalltext'>$oldzstring</td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	$THIS_LINE .= "<td align=center><span class='smalltext'>$zstring</td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	$THIS_LINE .= "<td align=center><span class='smalltext'>$score1{$dta}</td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	$THIS_LINE .= "<td align=center><span class='smalltext'>$score2{$dta}</td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	$THIS_LINE .= "<td align=center><span class='smalltext'>$score3{$dta}</td>";
	$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
	if($showIntermediateScores){
		$THIS_LINE .= "<td align=center><span class='smalltext'>$WaterLoss3</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$corrScore</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$BYtest</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$ionsAbove</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$TwicePrec</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$TICabove</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$two_times_prec_in_range</td>";
		$THIS_LINE .= "<td>&nbsp;&nbsp;&nbsp;</td>";
		$THIS_LINE .= "<td align=center><span class='smalltext'>$evidence</td>";
	}
	$THIS_LINE .= "<tr>";

	push @TABLE_LINES, $THIS_LINE;
	$Scan_Numbers{"$THIS_LINE"} = $scan;
	
}

sub print_table{
	
	my($fname) = pop @_;

	open FOUT, ">$fname";

	&print_table_header();
	&print_table_header("$fname");
	
	#sorted order by scan number
	foreach (sort {$Scan_Numbers{"$a"} <=> $Scan_Numbers{"$b"}} @TABLE_LINES){

		#print to screen
		print "$_";

		#print to file
		print FOUT "$_";

	}

	print "</table></body></html>";
	print FOUT "</table></body></html>";

	close FOUT;

}

sub output_form {
	$checked{$DEFS_DETERMINECHARGE{"Dta files to copy"}} = " CHECKED";
	$checked{"copyout"} = " CHECKED" if ($DEFS_DETERMINECHARGE{"Copy Out files?"} eq "yes");
	$checked{"cloneorig"} = " CHECKED" if ($DEFS_DETERMINECHARGE{"Clone Original Directory"} eq "yes");
	
	print "<FORM ACTION=\"$ourname\" METHOD=GET NAME=\"form\">";
	&get_alldirs();	
	

	print <<EOP;

	<TABLE cellspacing=8>
	<tr>
		<td>
			<span class="smallheading">Select a directory to test DTA files: </span>
		</td>
		<TR>
		<TD><span class=dropbox><select name="directory">
EOP
	
	foreach $dir (@ordered_names){ 
		print qq(<option value="$dir">$fancyname{$dir}\n);
	}
	print <<EOF;
	</tr>

	<tr>
		<td>
			<span class="smallheading">Operator:</span> <INPUT NAME="operator" SIZE=3 MAXLENGTH=3>&nbsp;&nbsp;&nbsp;&nbsp;</span>
			&nbsp;&nbsp;&nbsp;&nbsp;<input class=button type=submit value="Run Engine">
			&nbsp;&nbsp;<A HREF="$webhelpdir/help_$ourshortname.html"><span class="smallheading">Help</span></A>
		</td>
	</TR>	
	</TABLE>

	<table><tr><td>&nbsp;</td>
	<td>
	<table width="20%" border=0 cellspacing=0 cellpadding=0>
		<tr><td bgcolor="#c0c0c0">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
		<td bgcolor="#e2e2e2">&nbsp;</td>
		<td>
		<table border=0 cellspacing=0 cellpadding=0 bgcolor="#e2e2e2">
			<tr>
				<td colspan=2 bgcolor="#e2e2e2" valign=center align=left>
				<span class="smallheading">Advanced Options:</span>
				</td>		
			</tr>
			<tr>
				<td colspan=2><hr></td>
			</tr>

			<TR>
				<TD align=left><span class="smallheading">Number of ions :&nbsp;</span></TD>
				<TD width="100%"><input name="num_ions" size=4 value="$default_num_ions"></TD>
			</TR>
			<TR>
				<TD align=left><span class="smallheading">Tolerance:&nbsp;</span></TD>
				<TD><input name="tolerance" size=4 value="$tolerance"></TD>
			</TR>
			<TR>
				<TD NOWRAP align=left><span class="smallheading">Ions above prec:&nbsp;</span></TD>
				<TD><input name="top_above_ions" size=4 value="$default_top_above_ions"></TD>
			</TR>
			<TR>
				<TD align=left><span class="smallheading">Ion Window:&nbsp;</span></TD>
				<TD><input name="window" size=4 value="$window"></TD>
			</TR>
			<TR>
				<TD align=left><span class="smallheading">Min MH+:&nbsp;</span></TD>
				<TD><input name="Min_MHplus" size=4 value="$DEFS_DETERMINECHARGE{'Minimum MH+'}"></TD>
			</TR>
			<TR>
				<TD align=left><span class="smallheading">Max MH+:&nbsp;</span></TD>
				<TD><input name="Max_MHplus" size=4 value="$DEFS_DETERMINECHARGE{'Maximum MH+'}">&nbsp;</TD>
			</TR>

			<TR>
				<TD colspan=2>
				<TABLE border=0 cellspacing=0 cellpadding=0 bgcolor="#e2e2e2">
				<TR>
					<TD align=left height=24><span class="smallheading">Leave 1+ dtas if no zooms?&nbsp;</span></TD> 
					<TD><input type=checkbox name="TrustOnePlus" value="yes" checked></TD>
				</TR>
				<TR>
					<TD align=left height=24><span class="smallheading">Clone original directory?&nbsp;</span></TD>
					<TD><input type=checkbox name="clonefirst" value="yes"$checked{'cloneorig'}></TD>
				</TR>
				<TR>
					<TD align=left height=24><span class="smallheading">Copy outfiles?&nbsp;</span></TD> 
					<TD><INPUT TYPE=checkbox NAME="CopyOuts" VALUE="yes"$checked{'copyout'}><TD>
				</TR>
				</TABLE>
				</TD>
			</TR>
			<TR>
				<TD align=left><span class="smallheading">NewDirTag:&nbsp;</span>
							   <span class="normaltext"></span></TD>
				<TD><span style="font-size:4pt"> </span>_<input type=text size=8 name="DirTag" value="precsd">&nbsp;</TD>

			<TD>
			</TR>
		</table>	
		</td>
	</table>
	</td>
	</table>
	</FORM>
EOF
}


############################################################################################
#
#
#	Code for resetting charge state of a dta file
#
#
############################################################################################

# set_charge
# this is a modification of the set_charge function in dta_control.pl. It allows us to set to a pair of charge states. 
sub set_charge {

	# DTA file(s) and new charge state(s)	
	my ($dta1, $dta2, $newZ1, $newZ2) = @_;
	my ($mhplus, $charge, $highion, $precursor, $z ,$newdta, $dtabase,$root,$dta,$dtabase,$newZ,$newmhplus,$zz,$origZ,$original,$line,@lines,$oldZ1,$oldZ2);
	$oldZ1 = &dta_to_z($dta1);
	$oldZ2 = &dta_to_z($dta2);

	# in the case where there was no change, just return
	my(@oldlst,@newlst);
	my(@oldlst) = sort ($oldZ1, $oldZ2);
	my(@newlst) = sort ($newZ1, $newZ2);
	return if($oldlst[0] == $newlst[0] and $oldlst[1] == $newlst[1]);

	# put in 3 categories, chg states that need to be created, those that need to be kept, and those that need to be deleted
	my(@tokeep,@todelete,@tocreate);
	foreach $zz (@oldlst) {
		next unless $zz; 
		if($zz != $newZ1 and $zz != $newZ2){
			push @todelete, $zz;
		}else{
			push @tokeep, $zz;
		}
	}
	foreach $zz (@newlst) {
		next unless $zz; 
		if($zz != $oldZ1 and $zz != $oldZ2){
			push @tocreate, $zz;
		}
	}

	#get the info pertaining to the dta
	($fileroot) = ($dta1 =~ /^(.+)\.[x\d]\.dta$/);
	$dtabase = $dta1; $dtabase=~s/\.\d\.dta$//;
	my(@lines)  = ();
	open (DTAFILE, "< $seqdir/$cloneddir/$dta1");
	($mhplus, $z) = split / /, <DTAFILE>;
	while(<DTAFILE>){
		push @lines, $_;
	}
	close DTAFILE;
	 $precursor = ( ($mhplus - $Mono_mass{'Hydrogen'}) / $z) + $Mono_mass{'Hydrogen'};


	# create new dtas
	foreach $newZ (@tocreate) {

		# get new mh+
		$newmhplus = ($precursor - $Mono_mass{'Hydrogen'}) * $newZ + $Mono_mass{'Hydrogen'};
		$newmhplus = &precision ($newmhplus, 2);

		# don't do it if mh+ is out of range
		#next if( $newmhplus < $Min_MHplus or $newmhplus > $Max_MHplus);

		#write it
		open(DTA, ">$seqdir/$cloneddir/$dtabase.$newZ.dta");
		print DTA "$newmhplus $newZ\n";
		foreach $line (@lines) {
			$line =~ s/^\s+// ;		# This line of code is neccesary though I know not why. This remains one of life's larger mysteries.
			print DTA "$line";
		}
		close DTA;
		
	}

	# now delete any old ones if necessary
	foreach $badZ (@todelete) {
		&delete_files("$seqdir/$cloneddir/$dtabase.$badZ.dta");
	}


	# take care of necessary changes in lcq profile
	my(@profdata,@relevantlines,@newlines);
	my($original,$ln,$found,$finished) = (0, 0, 0, 0);
	open(PROF, "$seqdir/$cloneddir/lcq_profile.txt");
    while ($ln=<PROF>) {
		if (grep(/^$dtabase.*/, $ln)) {
			$found = 1;
			push @relevantlines, $ln
		}else{
			if($found and not $finished){
				
				#first take care of created dtas
				$original = $relevantlines[0];
				foreach  (@tocreate) {
					substr($original, 0, length("$dtabase.$_.dta")) = "$dtabase.$_.dta";
					push @newlines, $original;
				}

				#now pick out the ones we have to keep
				foreach  (@tokeep) {
					substr($original, 0, length("$dtabase.$_.dta")) = "$dtabase.$_.dta";
					push @newlines, $original;
				}
			
				push @profdata, @newlines;
				$finished = 1;
			}
			push @profdata, $ln;
		}
    }
	# one more iteration to take care of the final scan number
	if($found and not $finished){
				
		#first take care of created dtas
		$original = $relevantlines[0];
		foreach  (@tocreate) {
			substr($original, 0, length("$dtabase.$_.dta")) = "$dtabase.$_.dta";
			push @newlines, $original;
		}

		#now pick out the ones we have to keep
		foreach  (@tokeep) {
			substr($original, 0, length("$dtabase.$_.dta")) = "$dtabase.$_.dta";
			push @newlines, $original;
		}
	
		push @profdata, @newlines;
		$finished = 1;
	}

	
    close PROF;

    open(PROF, "> $seqdir/$cloneddir/lcq_profile.txt");
    print PROF @profdata;
    close PROF;

	#fix gbu file if necessary
	my($chg,$line,$file,@gbulines);
	if (@todelete and -e "$seqdir/$cloneddir/goodbadugly.txt") {
		open(GBU, "$seqdir/$cloneddir/goodbadugly.txt");
		foreach $chg (@todelete) {
			$file = "$dtabase.$_.dta";
			while ($line = <GBU>) {
				unless (grep(/^$file/, $ln)) {
					push @gbulines, $line;
				}
			}#while
		} #foreach
		
		close GBU;
		open GBU, ">$seqdir/$cloneddir/goodbadugly.txt";
		print GBU @gbulines;
		close GBU;

	} #if

}


#############################################################################################
#																							
#																						
#	Borrowed code for cloning directories 
#
#
############################################################################################


sub clone_dir {
	my($success) = 0;

	# this is a hack to outsmart clonedir. We want to append the tag without replacing an existing tag
	$dir =~ /.+_(.*)/;
	$oldtag = $1;
	$dirtag = $oldtag . "_" . $dirtag;

	require "clone_code.pl";	
	if (!defined $dirtag) {
		@arr = ();
		$msg = "You must specify a tag name !";
		push(@arr, $msg);
		my_clone_error(@arr);	
	}
	
	# clone the directory
	($originaldir, @retval) = &clonedir ($dir, $dirtag, $copyouts, $operator);
	
	if ((shift @retval) == 0) {  # success
		$success = 1;
		&my_clone_success (@retval);
	} else {
		&my_clone_error (@retval);
	}
	return($success);
}


sub my_clone_success {
	@msgs = @_;	
	print <<EOP;	
	<p>
	<div class="normaltext">

	<image src="/images/circle_1.gif">&nbsp;Directory clone was successful.
	<ul>
	<li><span class="smallheading">Old Directory: </span><a href="$viewinfo?directory=$directory">$dir</a><br>
	<li><span class="smallheading">New Directory: </span><a href="$viewinfo?directory=$originaldir">$originaldir</a><br>
	</ul>
	</div>
EOP
	
	if (@msgs) {
	   print ("<p>The following non-fatal errors were reported:<br>\n");
	   print join ("\n", @msgs);
	}
	
	print <<EOP;
	<p>
	<div class="normaltext">
	<image src="/images/circle_2.gif">&nbsp;Running the engine on directory: <span class="smallheading">$dir:</span><br><br>
	&nbsp;&nbsp;&nbsp;&nbsp;
EOP
}

sub my_clone_error {
	$h2msg = shift @_;
	print ("<h2>$h2msg</h2><div>\n");
	print (join ("\n", @_), "</div>\n");

	&get_alldirs;
	&output_form;
	exit; 
}
	

# Error subroutine
# prints out a properly formatted error message in case the user did something wrong; also useful for debugging
sub error {	
	print <<EOF;	
	<H3>Error:</H3>
	<div>
	@_
	</div>
	</body></html>
EOF
	exit(0);	
}

# dta_to_z
# Given a dta name it uses a regular expression to peel out z
sub dta_to_z{
	my($name) = pop @_;
	if($name){
		$name =~ /.*\.(\d).dta$/;
		return($1);
	}else{
		return(0);
	}
}


