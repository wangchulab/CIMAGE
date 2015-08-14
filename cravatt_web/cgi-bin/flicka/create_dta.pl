#!/usr/local/bin/perl

#-------------------------------------
#	CreateDta,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# create_dta.pl
# a Perl rewrite of create_dta

# united by cmw (5/17/99) with the original run_lcq_dta.pl

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
	require "html_include.pl";
}
################################################

&cgi_receive();

$dir = $FORM{"directory"};
$LcqFile = $FORM{"LcqFile"};
$StartScan = (defined $FORM{"StartScan"}) ? $FORM{"StartScan"} : $DEFS_CREATE_DTAS{'Start scan'};
$EndScan = (defined $FORM{"EndScan"}) ? $FORM{"EndScan"} : $DEFS_CREATE_DTAS{'End scan'};
$BottomMW = (defined $FORM{"BottomMW"}) ? $FORM{"BottomMW"} : $DEFS_CREATE_DTAS{'Bottom MW'};
$TopMW = (defined $FORM{"TopMW"}) ? $FORM{"TopMW"} : $DEFS_CREATE_DTAS{'Top MW'};
$PepMass = (defined $FORM{"PepMass"}) ? $FORM{"PepMass"} : $DEFS_CREATE_DTAS{'Mass'};
$DiffScans = (defined $FORM{"DiffScans"}) ? $FORM{"DiffScans"} : $DEFS_CREATE_DTAS{'Intermediate Scans'};
$MinGrouped = (defined $FORM{"MinGrouped"}) ? $FORM{"MinGrouped"} : $DEFS_CREATE_DTAS{'Grouped Scans'};
$MinIons = (defined $FORM{"MinIons"}) ? $FORM{"MinIons"} : $DEFS_CREATE_DTAS{'Min. # Ions'};
$MinTIC = (defined $FORM{"MinTIC"}) ? $FORM{"MinTIC"} : $DEFS_CREATE_DTAS{'Minimum TIC'};
$operator = $FORM{"operator"};
$operator =~ tr/A-Z/a-z/;

$ChargeState = (defined $FORM{"ChargeState"}) ? $FORM{"ChargeState"} : $DEFS_CREATE_DTAS{"Precursor Charge State"};
$ChargeState = "automatic" if ($ChargeState eq "zoom scan");
$ChargeState =~ s/ /_/g;

# checkboxes
$run_ionquest = ($FORM{"defined_run_ionquest"} || (defined $FORM{"run_ionquest"})) ? $FORM{"run_ionquest"} : ($DEFS_CREATE_DTAS{"Filter with IonQuest"} eq "yes");
$clear_existing = ($FORM{"defined_clear_existing"} || (defined $FORM{"clear_existing"})) ? $FORM{"clear_existing"} : ($DEFS_CREATE_DTAS{"Clear existing DTA files"} eq "yes");
$run_mhplus = ($FORM{"run_mhplus"} || (defined $FORM{"run_mhplus"})) ? $FORM{"run_mhplus"} : ($DEFS_CREATE_DTAS{"Run with MH+"} eq "yes");
$run_combiner = (defined $FORM{"run_replicate_combiner"}) ? $FORM{"run_replicate_combiner"} : $DEFS_CREATE_DTAS{'Combine replicate DTAs'};
$run_zsa_aka_csd = (defined $FORM{"run_zsa_aka_csd"}) ? $FORM{"run_zsa_aka_csd"} : $DEFS_CREATE_DTAS{'Run ZSA (CSD)'};
$run_gbu = ($FORM{"run_gbu"} || (defined $FORM{"run_gbu"})) ? $FORM{"run_gbu"} : ($DEFS_CREATE_DTAS{"Run with GBU"} eq "yes");


if ($FORM{"create_datafiles"}) {
	&do_extract_msn;
} else {
	&output_form;
	exit;
}



sub do_extract_msn {

	select STDOUT; # to eliminate buffering artifacts
	$| = 1;
	&MS_pages_header ("Running Extract_msn...", "#402080");
	print "<P><HR><P>\n";
	# This variable added by MIke on 8/17/98 to receive
	# charge-finding option from create_dta.pl:
	# Changed again by Mike on 10/31/98 because extract_msn defaults changed

	&error ("You must enter your initials in the <B>Operator</B> field.") if (!defined $operator);

	&error ("No such user directory: $dir") if ((!defined $dir) || (! (-d "$seqdir/$dir")));
	
	if ($LcqFile eq "none") {
	  &error ("No data file selected.", qq(Please go back to the <a href="$create_dta">Create_DTA</a> page),
		  " and select an appropriate data file.");
	}
	&error ("No such LCQ file: $LcqFile") if (! (-f "$lcqdir/$LcqFile"));


print <<PARAMS;
<TABLE BORDER=0 WIDTH="100%">
<TR>
<TD WIDTH="50%">
<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0>
<TR>
	<TD><span class="smallheading">Sequest User Directory:</span>
	&nbsp;<a href="$webseqdir/$dir">$dir</a></TD>
</TR>
<TR>
	<TD><span class="smallheading">LCQ Input File:</span>&nbsp;$LcqFile</TD>
</TR>

<TR>
	<TD><span class="smallheading">First Scan (-F):</span>&nbsp;$StartScan</TD>
</TR>
<TR>
	<TD><span class="smallheading">Last Scan (-L):</span>&nbsp;$EndScan</TD>
</TR>
<TR>
	<TD><span class="smallheading">Precursor Mass Tolerance (-M):</span>&nbsp;$PepMass </TD>
</TR>
<TR>
	<TD><span class="smallheading">Charge State (-C):</span>&nbsp;$ChargeState</TD>
</TR>
</TABLE></TD>
<TD WIDTH="50%">
<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0>
<TR>
	<TD><span class="smallheading">Top MW (-T):</span>
	&nbsp;$TopMW</TD>
</TR>
<TR>
	<TD><span class="smallheading">Bottom MW (-B):</span>
	&nbsp;$BottomMW</TD>
</TR>
<TR>
	<TD><span class="smallheading">Differential Intermediate Scans (-S):</span>
	&nbsp;$DiffScans</TD>
</TR>

<TR>
	<TD><span class="smallheading">Minimum Related Grouped Scans (-G):</span>
	&nbsp;$MinGrouped</TD>
</TR>

<TR>
	<TD><span class="smallheading">Minimum Number of Ions (-I):</span>
	&nbsp;$MinIons</TD>
</TR>

<TR>
	<TD><span class="smallheading">Minimum TIC (-E):</span>
	&nbsp;$MinTIC</TD>
</TR>
</TABLE></TD>
</TR>
</TABLE>



PARAMS
	$vdurl = "$VuDTA?directory=$dir&labels=checked&show=show";

	print <<EOF;
<br>
<TABLE BORDER=0 bgcolor="#e2e2e2">
<TR><TD ALIGN=CENTER>
<b><span style="color:red">Be sure to wait until this page is fully loaded</span></b>
</TD>
</TR>
</TABLE>
EOF

#<br><a href = "$vdurl">Go to VuDTA</a><br>
#<a href="$seqlaunch">Run Sequest</a><br>
#<a href="$webionquest?directory=$dir">Go to IonQuest</a><br>
#<a href="$webionquest?directory=$dir&compare=1">Auto-Run IonQuest</a>

	# run extract_msn.exe itself

	$options = "";
	$options .= " -F$StartScan" if ($StartScan);
	$options .= " -L$EndScan" if ($EndScan);
	$options .= " -B$BottomMW" if ($BottomMW);
	$options .= " -T$TopMW" if ($TopMW);
	$options .= " -M$PepMass" if ($PepMass);
	$options .= " -S$DiffScans" if ($DiffScans);
	# This next line added by Mike to enable "0" value
	$options .= " -S$DiffScans" if ($DiffScans eq "0");
	$options .= " -G$MinGrouped" if ($MinGrouped);
	$options .= " -I$MinIons" if ($MinIons);
	$MinTIC += 0;		# remove exponential notation
	$options .= " -E$MinTIC" if (defined $MinTIC);
	# This option added by Mike on 8/17/98: it allows
	# use of the charge-finding routines in extract_msn.
	# Tells extract_msn to use all routines, override header,
	# and print summary file:
	# (Changed by Mike on 10/31/98 because extract_msn now
	# defaults to -ATFEHMAOSC unless -A option present)
	# old line: $options .= " -ATFEMHAOSC" unless ($ScanHeaderOnly);
	$options .= " -A" if ($ChargeState eq "scan_header");


	if (($ChargeState ne "automatic") && ($ChargeState ne "scan_header")) {
	  $options .= " -C$ChargeState";
	}
	if ($ListOnly eq "yes") {
	  $options .= " -D";
	}

	chdir "$seqdir/$dir" ||  &error("could not change directory to $seqdir/$dir. $!");
	if ($clear_existing) {
		opendir (DIR, ".") or &error("Cannot read directory $dir: $!\n");
		@allfiles = readdir(DIR);
		closedir DIR;
		@dtas = grep { /\.(dta)$/ } @allfiles;
		@ztas = grep { /\.(zta)$/ } @allfiles;
		@outs = grep { /\.(out)$/ } @allfiles;
		@orig = grep { /\.(orig)$/ } @allfiles;
		unlink (@dtas,@ztas,@outs,@orig);	# no need for &delete_files, we're just trashing everything here
		unlink "selected_dtas.txt";
		unlink "lcq_zta_list.txt";
		unlink "lcq_dta.txt";
		unlink "lcq_profile.txt";
		&write_log($dir, "Run_extract_msn  " . localtime() . " clearing all DTA-sets $operator");
	}

	# added cmw 5/10/99
	# back up old text files if they exist, so that we can append to them later
	foreach $filename ("lcq_zta_list.txt","lcq_dta.txt","lcq_profile.txt") {
		unlink "$filename.previous";
		rename "$filename", "$filename.previous" if (-e "$filename");
	}

	$cmdline = "$extract_msn -U$lcq_charge_template $options $lcqdir\\$LcqFile";
	$bullet =  "\n&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;•&nbsp;&nbsp;&nbsp;&nbsp;";
    $space =  "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
	
	print qq(<br><image src="/images/circle_1.gif">&nbsp;<span class="smallheading">Running Extract_msn...</span><br>\n);
	print qq(<div><span class="smallheading">$bullet Command line:</span><span class="smalltext">&nbsp;$cmdline</span><br>\n);
	print qq(<span class="smallheading">$bullet</span>);
	$old_num_dta_sets = &count_dta_sets($dir);
	# run extract_msn in background and wait for it to finish
	$procobj = &run_in_background($cmdline,"$seqdir/$dir");
	$dots = 0;
	until ($procobj->Wait(1000)) {
		print qq(<b>.</b>);
		$dots++;
		if($dots > 135){
			print "<br>$space";
			$dots = 0;
		}
	
	}
	$num_dta_sets = &count_dta_sets($dir);
	$num_new_dta_sets = $num_dta_sets - $old_num_dta_sets;
	print qq(&nbsp;<span class="smalltext">Done.  $num_new_dta_sets DTA-sets created.</span>\n</div>);
	# added cmw 5/10/99
	# append new text files to old ones
	foreach $filename ("lcq_zta_list.txt","lcq_dta.txt","lcq_profile.txt") {
		if (-e "$filename.previous") {
			open(NEWFILE,"<$filename");
			open(OLDFILE,">>$filename.previous");
			# remove header line of lcq_profile.txt, since the old file already has one
			<NEWFILE> if ($filename eq "lcq_profile.txt");
			while (<NEWFILE>) {
				print OLDFILE $_;
			}
			close OLDFILE;
			close NEWFILE;
			unlink "$filename";
			rename "$filename.previous", "$filename";
		}
	}
	# write to the directory log (added cmw,7-24-98)
	&write_log($dir,"Extract_msn  " . localtime() . "  $num_new_dta_sets DTA-sets created $operator : $cmdline");

	if ($FORM{'run_replicate_combiner'}) {
		$old_num_dta_sets = $num_dta_sets;
		print qq(<div><span class="smallheading">$bullet Running CombIon...</span><br>\n);
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string(directory => $dir,
															algorithm => "ionquest",
															ionquest_threshold => "42",
															precursor_tolerance => "4.0",
															combine => "combine_and_delete",
															check_with_muquest => "yes",
															ionquest_retest => "48",
															muquest_retest_threshold => "1.7");
		$procobj = &run_silently_in_background("$dta_combiner_cmdline USE_QUERY_STRING_INTRACHEM");
		$dots = 0;
		print $space;
		until ($procobj->Wait(1000)) {
			print qq(<b>.</b>);
			$dots++;
			if($dots > 135){
				print "<br>$space";
				$dots = 0;
			}
		}
		$num_dta_sets = &count_dta_sets($dir);
		$num_dta_sets_deleted = $old_num_dta_sets - $num_dta_sets;
		print qq(<span class="smalltext">Done.</span><BR>\n);
	}

	# if called for, run charge state determination in the background
	if($FORM{'run_zsa_aka_csd'}){
		print qq(<div><span class="smallheading">$bullet Running ZSA...</span><br>\n);
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir, "operator" => $operator, 
															"Min_MHplus" => $BottomMW, "Max_MHplus" => $TopMW);
		$procobj = &run_silently_in_background("$determine_charge_cmdline USE_QUERY_STRING_INTRACHEM");
		$dots = 0;
		print $space;
		until ($procobj->Wait(1000)) {
			print qq(<b>.</b>);
			$dots++;
			if($dots > 135){
				print "<br>$space";
				$dots = 0;
			}
		}
		print qq(<span class="smalltext">Done.</span><BR>\n);
	}

	if ($FORM{'run_mhplus'}) {
		print qq(<div><span class="smallheading">$bullet Running CorrectIon...</span><br>\n);
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir, "MakeChanges" => "yes");
		
		$procobj = &run_silently_in_background("$correctmhplus_cmdline USE_QUERY_STRING_INTRACHEM");
		$dots = 0;
		print $space;
		until ($procobj->Wait(1000)) {
			print qq(<b>.</b>);
			$dots++;
			if($dots > 135){
				print "<br>$space";
				$dots = 0;
			}
		}
		print qq(<span class="smalltext">Done.</span><BR>\n);
	}
	
	my $ionquest_header_printed=0;

	if ($run_ionquest)
	{
		%IONQUEST_ARGS = ();
		@IONQUEST_ARGS = grep /^IONQUEST:/, keys %FORM;
		foreach (@IONQUEST_ARGS) {
			(my $key = $_) =~ s/^IONQUEST://;
			$IONQUEST_ARGS{$key} = $FORM{$_};
		}
		print qq(<image src="/images/circle_2.gif">&nbsp;<span class="smallheading">Running IonQuest ...</span><br>\n);
		$ionquest_header_printed = 1;

		$image_num=2;
		foreach $refdir (@REFDIRS) {
			
			print qq(<div><span class="smallheading">$bullet with refdir:</span> <span class="smalltext">$refdir</span><br>\n);
			#print qq(<span class="smallheading">Running IonQuest with refdir:</span>$refdir...);
			$num_dta_sets = &count_dta_sets($dir);
			$old_num_dta_sets = $num_dta_sets;

			# run IonQuest in background and wait for it to finish
			$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string(%IONQUEST_ARGS, "directory" => $dir, "refdir" => $refdir, "compare" => 1, "delete_matches" => 1);
			$procobj = &run_silently_in_background("$ionquest USE_QUERY_STRING_INTRACHEM");
			$dots=0;
			print $space;
			until ($procobj->Wait(1000)) {
				print "<b>.</b>";
				$dots++;
				if($dots > 135){
					print "<br>$space";
					$dots = 0;
				}
			}
			$num_dta_sets = &count_dta_sets($dir);
			$num_dta_sets_deleted = $old_num_dta_sets - $num_dta_sets;
			print qq(&nbsp;<span class="smalltext">Done.  $num_dta_sets_deleted DTA-sets deleted.</span>\n</div>);
			$image_num++;
	
		}		print qq();
	}

	#print ("<p><b>Extract_msn RUN COMPLETED</b><p>");
	#print "View <A HREF=\"$webseqdir/$dir/lcq_dta.txt\">lcq_dta.txt</A><P>\n";


	if ($FORM{"run_gbu"}) {
		print qq(<image src="/images/circle_3.gif">&nbsp;<span class="smallheading">Running GBU ...</span><br>\n);
		$ENV{"QUERY_STRING_INTRACHEM"} = &make_query_string("directory" => $dir);
		$procobj = &run_silently_in_background("$goodbagugly_cmdline USE_QUERY_STRING_INTRACHEM");
		$dots=0;
		print $space;
		until ($procobj->Wait(1000)) {
			print "<b>.</b>";
			$dots++;
			if($dots > 135){
				print "<br>$space";
				$dots = 0;
			}
		}
		print qq(<span class="smalltext">Done.</span><BR>\n);
	}
	
	open(LOG,"<$seqdir/$dir/$dir.log");
	@loglines = <LOG>;
	close(LOG);

	#$delloglink = "<A HREF=\"$webseqdir/$dir/$dir" . "_deletions_log.html\"><img border=0  align=top src=\"$webimagedir/p_deletions_log.gif\"></a><p>" if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));
	#print "$delloglink\n";
    
	$delloglink = "$webseqdir/$dir/$dir" . "_deletions_log.html" if (-e ("$seqdir/$dir/$dir" . "_deletions_log.html"));
	
	@text = ("Run Sequest","IonQuest", "Auto-Run IonQuest","View lcq_dta.text","View DTA Chromatogram","Deletions Log");
	@links = ("sequest_launcher.pl","$webionquest?directory=$dir","$webionquest?directory=$dir&compare=1","$webseqdir/$dir/lcq_dta.txt","dta_chromatogram.pl","$delloglink");
	&WhatDoYouWantToDoNow(\@text, \@links);
	print "<P><HR><P>\n";

	print qq(<span class=\"smallheading\">Log File:</span>);


	print "<div class=smalltext>" . join("<br>",@loglines) . "</div>\n";

	if ($deletionmessage)
	{
		print "<b>$deletionmessage</b><br>";
		print "<A HREF=\"$webseqdir/$dir/$dir" . "_deletions_log.html\">View Deletions Log</A>\n";
	}


	exit 0;

}


sub error {
  print "<b><span style=\"color:red\">";
  print ("<h2>Error</h2>", join ("\n", @_), "\n");
  print "</span></b>";
  exit 1;
}



sub output_form {

	# set defaults for checkbox and radio buttons
	$selected{$LcqFile} = " selected";
	$checked{"do_ionquest"} = " CHECKED" if ($run_ionquest);
	$checked{"clear_existing"} = " CHECKED" if ($clear_existing);
	$checked{"charge: $ChargeState"} = " CHECKED";
	$checked{"run_zsa_aka_csd"} = " CHECKED" if ($run_zsa_aka_csd);
	$checked{"run_combiner"} = " CHECKED" if ($run_combiner);
	$checked{"run_mhplus"} = " CHECKED" if ($run_mhplus);
	$checked{"run_gbu"} = " CHECKED" if ($run_gbu);
	
	&MS_pages_header("Create DTA", "#871F78", "tabvalues=x&Setup Dir:\"/cgi-bin/setup_dirs.pl\"&Dir de Dozen:\"/cgi-bin/cloneadir.pl\"");

	my $dtaheading = &create_table_heading(title => "Limit DTA's Created To");
	my $groupingheading = &create_table_heading(title => "Grouping");
	my $chargestateheading = &create_table_heading(title => "Precursor Charge State", width =>'80%');
	print <<EOM;
<FORM METHOD="POST" ACTION="$ourname" NAME="form"> 
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=60></td>
<td>
<table cellspacing=0 cellpadding=0 border=0>
	<tr><td bgcolor=#e8e8fa style="font-size:3">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:3">&nbsp;</td></tr>
	<tr height=25>
		<td class=title nowrap>&nbsp;Sequest Directory:&nbsp;&nbsp;</td>
	    <td class=data>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="directory">
EOM
	  
	&get_alldirs();
	foreach $directory (@ordered_names) {
	  print ("<OPTION");
	  print (" SELECTED") if ((defined $dir) && ($directory eq $dir));
	  print qq( VALUE = "$directory">$fancyname{$directory}\n);
	}

	print <<EOM;
</SELECT></span></td></tr>
	<tr height=25>
		<td class=title nowrap>&nbsp;Raw Data File:&nbsp;&nbsp;</td>
		<td class=data>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="LcqFile">
EOM

	&get_lcqdat();

	print qq(<OPTION VALUE="none"> \n);
	foreach $lcq (@ordered_lcq_names) {
	  print qq(<OPTION VALUE = "$lcq"$selected{$lcq}>$lcq\n);
	}

	print <<EOM;
EOM

print "</SELECT></span>&nbsp;";


print <<EOM;
	</td></tr>
	<tr height=25><td class=title>&nbsp;&nbsp;Clear Existing DTA Files?&nbsp;&nbsp;</td>
		<td class=data>&nbsp;<INPUT TYPE=hidden NAME="deined_clear_existing" VALUE=1><INPUT TYPE=CHECKBOX NAME="clear_existing"$checked{'clear_existing'}>
		</td>
	</tr>

<script language="JavaScript">
<!--
function adjust_pcs_value(checkbox) {
	var checkedbox = document.getElementById(checkbox);
	var dta_combiner = document.getElementById("run_replicate_combiner");
	var chargestate1 = document.getElementById("chargestate1");
	var chargestate2 = document.getElementById("chargestate2");
	if (checkedbox.checked) {
		document.form.run_zsa_aka_csd.checked = 1;
		document.form.run_replicate_combiner.checked = 1;
		document.form.useZSA.checked = 1;
		document.form.ChargeState[1].checked = 1;
		chargestate1.style.color = "#999999";
		chargestate2.style.color = "#999999";
	} else {
		document.form.ChargeState[6].checked = 1;
		document.form.run_replicate_combiner.checked = 0;
		document.form.run_zsa_aka_csd.checked = 0;
		document.form.useZSA.checked = 0;
		chargestate1.style.color = "";
		chargestate2.style.color = "";
	}
}

function uncheck_ZSA() {
	var chargestate1 = document.getElementById("chargestate1");
	var chargestate2 = document.getElementById("chargestate2");
	document.form.run_replicate_combiner.checked = 0;
	document.form.run_zsa_aka_csd.checked = 0;
	document.form.useZSA.checked = 0;
	chargestate1.style.color = "";
	chargestate2.style.color = "";
}
	
-->
</script>
	<tr height=21><td colspan=2>&nbsp;</td></tr>
	<tr><td colspan=2>$dtaheading</td></tr>
	<tr><td colspan=2>
	<table cellspacing=0 cellpadding=0 width=100% class=outline>
	<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td colspan=5 bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
		<tr><td class=title>&nbsp;&nbsp;&nbsp;&nbsp;Scans:&nbsp;&nbsp;</td>
	        <td class=data align=right>Start&nbsp;&nbsp;</td>
			<td class=data><INPUT TYPE="text" NAME="StartScan" VALUE="$StartScan" SIZE=6 MAXLENGTH=4></td>
			<td class=data align=right>End&nbsp;&nbsp;</td>
			<td class=data><INPUT	TYPE="text" NAME="EndScan" VALUE="$EndScan" SIZE=6 MAXLENGTH=4></td>
			<td class=data width=50>&nbsp;</td>
		</tr>
		<tr><td class=title>&nbsp;&nbsp;&nbsp;&nbsp;MH+:&nbsp;&nbsp;</td>
			<td class=data align=right>Min&nbsp;&nbsp;</td>
			<td class=data><INPUT	TYPE="text" NAME="BottomMW" VALUE="$BottomMW" SIZE=6 MAXLENGTH=4></td>
			<td class=data align=right>Max&nbsp;&nbsp;</td>
			<td class=data><INPUT	TYPE="text" NAME="TopMW" VALUE="$TopMW" SIZE=6 MAXLENGTH=4></td>
			<td class=data width=50>&nbsp;</td>
		</tr>
		<tr><td class=title>Thresholds:&nbsp;&nbsp;</td>
			<td class=data align=right>#Ions&nbsp;&nbsp;</td>
			<td class=data><INPUT NAME="MinIons" VALUE="$MinIons" SIZE=6></td>
			<td class=data align=right>TIC&nbsp;&nbsp;</td>
			<td class=data><INPUT TYPE="text" NAME="MinTIC" VALUE="$MinTIC" SIZE=6></td>
			<td class=data width=50>&nbsp;</td>
		</tr>
	</table></td></tr>
	<tr height=21><td colspan=2>&nbsp;</td></tr>
	<tr><td colspan=2>$groupingheading</td></tr>
	<tr><td colspan=2>
	<table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
		<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
		<tr><td class=title nowrap>&nbsp;&nbsp;Mass Tolerance&nbsp;&nbsp;</td>
			<td class=data width=50% nowrap>&nbsp;&nbsp;<INPUT TYPE="text" NAME="PepMass" VALUE="$PepMass" SIZE=6 MAXLENGTH=3><span class=smalltext>&nbsp;&nbsp;Da</span></td></tr>
		<tr><td class=title nowrap>&nbsp;&nbsp;Minimum Allowed Intervening Scans (Group Scan)&nbsp;&nbsp;</td>
			<td class=data width=50% nowrap>&nbsp;&nbsp;<INPUT TYPE="text" NAME="DiffScans" VALUE="$DiffScans" SIZE=6 MAXLENGTH=3></td></tr>
		<tr><td class=title nowrap>&nbsp;&nbsp;Number of Adjacent Scans to Group (Group Count)&nbsp;&nbsp;</td>
			<td class=data width=50% nowrap>&nbsp;&nbsp;<INPUT TYPE="text" NAME="MinGrouped" VALUE="$MinGrouped" SIZE=6 MAXLENGTH=3></td></tr>
	</table></td>
</tr></table></td>

<td width=25>&nbsp;</td>
<td valign=bottom>
<table cellspacing=0 cellpadding=0 border=0>
<tr><td align=center>$chargestateheading</td></tr>
<tr><td align=center>
	<table cellspacing=0 cellpadding=0 width=80% style="border: solid #000099; border-width:1px" bgcolor=#f2f2f2>
	<tr><td width=13%>&nbsp;</td><td class=smalltext >
		<input type="checkbox" Name="useZSA" onclick="adjust_pcs_value('useZSA')" VALUE="1"$checked{'run_zsa_aka_csd'}>&nbsp;Use ZSA</td></tr>
	<tr><td width=13%>&nbsp;</td><td class=smalltext id=chargestate1 style="color:#999999">
		<INPUT	TYPE="radio" NAME="ChargeState" VALUE="1"$checked{'charge: 1'}> 1 
		<INPUT	TYPE="radio" NAME="ChargeState"	VALUE="2"$checked{'charge: 2'}> 2
		<INPUT	TYPE="radio" NAME="ChargeState" VALUE="3"$checked{'charge: 3'}> 3 
		<INPUT	TYPE="radio" NAME="ChargeState"	VALUE="4"$checked{'charge: 4'}> 4 
		<INPUT	TYPE="radio" NAME="ChargeState" VALUE="5"$checked{'charge: 5'}> 5</td></tr>
	<tr><td width=13%>&nbsp;</td><td class=smalltext id=chargestate2 style="color:#999999">
	<INPUT	TYPE="radio" NAME="ChargeState"	VALUE="scan_header"$checked{'charge: scan_header'} onclick="uncheck_ZSA()"> Scan Header 
	&nbsp;&nbsp;<INPUT	TYPE="radio" NAME="ChargeState" VALUE="automatic"$checked{'charge: automatic'} onclick="uncheck_ZSA()"> Zoom Scan </td></tr>
	<tr><td colspan=2 bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
	</table>
</td></tr>
<tr height=25><td>&nbsp;</td></tr>
<tr><td align=center>
	<nobr><span class=smallheading>Operator:</span>
	<INPUT NAME="operator" SIZE=3 MAXLENGTH=3 VALUE="$operator">&nbsp;
	<INPUT TYPE="submit" CLASS="outlinebutton button" NAME="create_datafiles" style="width:80" VALUE="Create Dtas">
		&nbsp;<span class=smallheading style="cursor:hand; color:#0000cc" id="help" onmouseover="this.style.color='red';window.status='$webhelpdir/help_$ourshortname.html';return true;" onmouseout="this.style.color='#0000cc';window.status='';return true;" onclick="window.open('$webhelpdir/help_$ourshortname.html', '_blank')">Help</span><nobr>
</td></tr>
<tr height=10><td>&nbsp;</td></tr>
<tr><td valign=bottom>
<table cellspacing=0 cellpadding=2 border=0>
	<tr><TD valign=bottom>
		<fieldset style="padding:5px; border: solid #000099 1px">
		   <legend class=smallheading>After Creating DTA's Then:</legend>
		 	<INPUT TYPE="checkbox" name="run_replicate_combiner" VALUE="1"$checked{'run_combiner'}>
				<span class=smalltext>Combine identical spectra (CombIon)<br>
		    <INPUT TYPE="checkbox" name="run_zsa_aka_csd" onclick="adjust_pcs_value('run_zsa_aka_csd')" VALUE="1"$checked{'run_zsa_aka_csd'}>
		       <span class=smalltext>Determine charge state from MS/MS (ZSA)</span><br>
			<INPUT TYPE="checkbox" name="run_mhplus" onclick="adjust_pcs_value()" VALUE="1"$checked{'run_mhplus'}>
			   <span class=smalltext>Correct MH+ assignment (CorrectIon)</span><br>
			<INPUT TYPE=checkbox NAME="run_ionquest" VALUE="1"$checked{'do_ionquest'}>
			   <span class=smalltext>Filter spectra matching reference libraries (IonQuest)&nbsp;</span><br>
				<INPUT TYPE=hidden NAME="defined_run_ionquest" VALUE=1>

EOM
print <<EOM;
	 <INPUT TYPE="checkbox" NAME="run_gbu" VALUE="1"$checked{'run_gbu'}>
	    <span class=smalltext>Mark spectral quality (GBU)</span><br>
</fieldset></td></TR></table>	
</table></td></tr>	
</table>
</form>
</body>
</html>
EOM

	# The preceeding line is necessary

	# why?

}
