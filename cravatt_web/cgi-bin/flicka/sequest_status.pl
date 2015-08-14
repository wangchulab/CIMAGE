#!/usr/local/bin/perl

#-------------------------------------
#	Sequest Status,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


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
	require "status_include.pl";
	require "html_include.pl";
}
################################################
require "seqcomm_include.pl" if ($multiple_sequest_hosts);

&cgi_receive;

if ($FORM{"control"}) {
	&seqproc_control;
} elsif ($FORM{"perlprocAction"}) {
	&perlproc_control;
}else{
	&output_form;
}

exit 0;




# called by sequest_status in order to suspend/resume/kill/switch processes.
sub seqproc_control
{
	require "seqstatus_include.pl";

	delete $FORM{"control"};
	$operator = $FORM{"operator"};
	delete $FORM{"operator"};
	delete $FORM{"ID"};

	while (($procID,$instruction) = each %FORM)
	{
		if ($instruction eq "immunize") {
			my @procIDs = split ':::', $procID;
			foreach  $hostID(@procIDs) {
				($servername,$seqID) = split /:/, $hostID;
				&Q_immunize($servername,$seqID);			
			}

		} elsif ($instruction eq "deimmunize") {
			my @procIDs = split ':::', $procID;
			foreach  $hostID(@procIDs) {
				($servername,$seqID) = split /:/, $hostID;
				&Q_deimmunize($servername,$seqID);			
			}
		} elsif ($instruction eq "kill") {
			my @procIDs = split ':::', $procID;
			foreach  $hostID(@procIDs) {
				($servername,$seqID) = split /:/, $hostID;
				$error_msg = &change_status($servername,$seqID,$instruction,$operator);
				&error($error_msg) if ($error_msg);
			}
		} else {
			($servername,$seqID,$dir,$db) = split /:/, $procID;
			if (($servername =~ s/^switch=//) && $instruction) {
				$error_msg = &switch($servername,$seqID,$instruction,$dir,$db);
				&error($error_msg) if ($error_msg);
			}
			else {
				$error_msg = &change_status($servername,$seqID,$instruction,$operator);
				&error($error_msg) if ($error_msg);
			}
		}
	}

	&redirect("$ourname?");	# note: CGI input at the end of URL is necessary to avoid a Netscape bug (it won't let a script &redirect to itself)
}

# perlproc_control
# Used for changing status of a perl file
sub perlproc_control{

	my($file) = $FORM{"perlprocFile"};
	my($action) = $FORM{"perlprocAction"};

	# new status, indexed  by action
	my(%new_status) = ("kill" => "kill", "pause" => "paused", "continue" => "running");

	&set_status($file,$new_status{"$action"});

	&redirect("$ourname?");	# note: CGI input at the end of URL is necessary to avoid a Netscape bug (it won't let a script &redirect to itself)
}

sub output_form
{
	require "seqstatus_include.pl";

	$refresh = &refresh_page($SEQSTATUS_REFRESH);

	my $statusPagesLinksStr;

	$statusPagesLinksStr .= "Sequest Distributor:sequest_distributor.pl&" if ($multiple_sequest_hosts);

	$statusPagesLinksStr .= "Sequest Status Log:$webseqlog";

	%images = ("kill" => "/images/circle-red.png", "run"  => "/images/circle-green.png", "distribute" => "/images/circle-blue.png",
				"pause" => "/images/circle-yellow.png", "invert" => "/images/circle-black.png");

	&MS_pages_header("Sequest Status", "#871F78", "tabvalues=none&$statusPagesLinksStr", $nocache, $refresh);
	print "<center>";
	&get_alldirs;
	&print_javascript;
	&list_sequests;
	&list_sniffer;
	&list_processes;
	&list_others;
}

## Sniffer Status Stuff will go here
sub list_sniffer {
	opendir (SNIFFPROCDIR, $sniffprocdir);
	@sniffprocfiles = grep(/^[^\.]/, readdir(SNIFFPROCDIR));
	closedir SNIFFPROCDIR;
	if ($#sniffprocfiles >= 0) {
		my $sniffheading = &create_table_heading(title=>"Sniffer Processes");
		print <<HEADER;
<TABLE cellspacing=0 cellpadding=0 border=0 width=850>
<tr><td>$sniffheading</td></tr>
<tr><td>

<table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
  <tr height=20 bgcolor=#f2f2f2>
	<th class=smallheading align=center width=220>Directory</th>
	<th class=smallheading align=center width=280>Process</th>
	<th class=smallheading align=center width=280>Time Started</th>
	<th class=smallheading align=center width=90>&nbsp;</th>
  </tr>
HEADER
		foreach $file (@sniffprocfiles) {
			open (PROC_FILE, "$sniffprocdir/$file");
			@first_line = split /&/, <PROC_FILE>;
			$first_line[1] =~ tr/\n//d;    # remove trailing newline from second field
	
			$start_time = <PROC_FILE>;
			$fancy = &get_fancyname($first_line[1]);
			$this_proc = $first_line[0];

			print <<STAT;
<tr height=20>
	<td align=center class=smalltext>$fancy</td>
  <td align=center class=smalltext>$this_proc</td>
  <td align=center class=smalltext>$start_time</td>
  <td align=center class=smalltext>&nbsp;</td>
</tr>
STAT
		}
		print "</table></td></tr></table><br>";
	}
}

# Process Nanny Stuff Here
sub list_processes {
	@status_files = &get_all_status_files;
	my $processheading = &create_table_heading(title=>"Processes");
	if(@status_files){
		my($i);
		print <<EOM;
<FORM name="perlprocs" method="get" action="$ourname">
<input type="hidden" name="perlprocFile">
<input type="hidden" name="perlprocAction">

<TABLE cellspacing=0 cellpadding=0 border=0 width=850>
<tr><td>$processheading</td></tr>
<tr><td>

<table cellspacing=0 cellpadding=0 width=100% style="border: solid #000099; border-width:1px">
<tr height=20 bgcolor=#f2f2f2><th class=smallheading align=center width=220>Directory</th> 
			<th class=smallheading align=center width=120>Program</th>
			<th class=smallheading align=center width=160>&nbsp;</th>
			<th class=smallheading align=center width=100>Host</th>
			<th class=smallheading align=center width=100>Status</th>
			<th class=smallheading align=center width=70>Control</th>
EOM
		print qq(<th class=smallheading align=center width=80>&nbsp;</th>) if ($multiple_sequest_hosts); 
		print qq(</tr>\n);

	# this doesn't work so well now that the listed processes can run on any server
	# SDR - Changed so that processes running on local server can be deleted, but not remote
		 my(%pidsRunning) = &get_all_perl_process_pids();
		
		foreach(@status_files){

			$i++;
			%status = &get_status("$_");

		# Only do this if the process is running on the local webserver
		# In the future, may want to make this work for distributed servers as well.
			if ($status{"machinename"} eq $webserver) {
			# we better not proceed if this happens to be the status file of a dead app
				unless( $pidsRunning{$status{'parent_pid'}} ){
					unlink "$_";
					next;
				}
			}

			my $perlstatus = uc($status{'status'});
			my $dirpath = $status{"directory"};
			my($pausecontinue) = ($status{'status'} eq "running") ? "pause" : "continue"; 

			$perlstatus = "IN QUEUE" if ($status{'application'} eq "sigcalcq.pl") && ($perlstatus eq "RUNNING");
			my $statusimagefile = $perlstatus eq "RUNNING" ? "$images{'run'}" : "$images{'pause'}";

			my $dirname= $fancyname{$status{"directory"}};
			my $dirlink = &create_link(link=>"$createsummary?directory=$dirpath&sort=consensus", text=>"$dirname", class=>"smalltext") if ($dirname ne "");
			my $imagefile = ($pausecontinue eq "continue") ? "$images{'run'}" : "$images{'pause'}";

			print <<EOF;
<tr height=20>
	<td class=smalltext>&nbsp;&nbsp;$dirlink</td>
    <td class=smalltext align=center>$status{'application'}</td>
	<td class=smallheading align=center>&nbsp;</td>
	<td class=smalltext align=center>$status{"machinename"}</td>
	<td class=smalltext align=center><img src=$statusimagefile>&nbsp;$perlstatus</td>
	<td align=center><a href="$ourname?perlprocAction=$pausecontinue&perlprocFile=$_"><img src="$imagefile" title="$pausecontinue" border=0 onmouseover="invert(this)" onmouseout="uninvert(this)"></a>
		<a href="$ourname?perlprocAction=kill&perlprocFile=$_"><img src="$images{'kill'}" title=" kill " border=0 onmouseover="invert(this)" onmouseout="uninvert(this)"></a>&nbsp;&nbsp;
	</td>
EOF
			print qq(<td class=smallheading align=center>&nbsp;</td>)  if ($multiple_sequest_hosts); 
			print qq(</tr>\n);
		}
		print qq(</table></td></tr></table></form>);	
	}
}


# get_all_perl_process_pids
# returns a hash whose keys are pids of all perl processes currently running
sub get_all_perl_process_pids{

	my(%mem,%id,%pr,%progname);

	open(PSTAT,"$cgidir/pstat|") or die "Can't open '$cgidir/pstat|'";
	while (<PSTAT>) {
		if (/^pid: *([0-9a-f]{1,4}) pri: ?([0-9]{1,2}).*?(\d+K)\s+(\S*($searchstring)\S*).*/i) {
			$id = hex ($1);
			$pr{$id} = $2;
			$mem{$id} = $3;
			$progname{$id} = $4;
		}
	}
	close PSTAT;

	my %rv;

	foreach $id (keys %progname) {
		next unless($progname{$id} =~ /[Pp]erl.exe/);
		$rv{$id} = "yes";
	}

	return(%rv);
}

# List all other information for status page, including legend, directory survey, and inspector
sub list_others {
	my $legendheading = &create_table_heading(title=>"Legend");
	$dirheading = &create_table_heading(title=>"Dir Survey");
	$inspectorheading = &create_table_heading(title=>"Inspector");

	print <<EOFORM;
<table cellspacing=0 cellpadding=0 border=0 width=850>
<tr><td>$legendheading</td></tr>
<table cellspacing=0 cellpadding=0 width=850 style="border: solid #000099; border-width:1px" border=0>
<tr><td style="font-size:2">&nbsp;</td></tr>
<tr height=25><td class=smalltext nowrap>&nbsp;&nbsp;Next refresh: <B><span id=MicrosoftClock></span><ILAYER id="outerClock" visibility=HIDDEN><LAYER id="NetscapeClock" visibility=SHOW></LAYER><span id="spacing">00:30</span></ILAYER></B>&nbsp;&nbsp;</td>
EOFORM

	print qq(<td class=smalltext align=center nowrap><span style="color:#FF0000">*</span>&nbsp;&nbsp;Changing the HOST will cause a run to switch to the selected host</td>)  if ($multiple_sequest_hosts && @undistributed);
	print qq(<td align=right class=smalltext nowrap><img src=$images{'run'}>&nbsp;Run&nbsp;&nbsp;&nbsp;<img src=$images{'pause'}>&nbsp;Pause
		&nbsp;&nbsp;<img src=$images{'kill'}>&nbsp;Kill&nbsp;&nbsp;&nbsp;);
	print qq(<img src=$images{'distribute'}>&nbsp;Distribute&nbsp;&nbsp;&nbsp;) if ($multiple_sequest_hosts);
	print <<EOFORM;
</td></tr>
</table>
</td></tr></table>
<br style="font-size:17">
<TABLE cellspacing=0 cellpadding=0 border=0 width=850>
<tr><td valign=top>
<FORM NAME="dirsurvey" ACTION="$dirsurvey" METHOD="get">
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td>$dirheading</td></tr>

<tr height=30><td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;Survey Sequest directories modified in the last 
	<INPUT NAME="recent" SIZE=2 MAXLENGTH=3" VALUE="$DEFS_DIRSURVEY{'how recent'}"> days.
	<INPUT TYPE=submit class="smalloutlinebutton button" style="width=60" VALUE="Survey">&nbsp;&nbsp;
</td></tr></table>
</FORM></td>

<td valign=top align=right>
<FORM NAME="inspector" ACTION="$inspector" METHOD=get>
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td>$inspectorheading</td></tr>

<tr height=30><td class=smalltext bgcolor=#f2f2f2 nowrap>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="directory" style="font-size:11">
EOFORM

	foreach $dir (@ordered_names) {
	      print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
	}

	print <<EOFORM2;
	</SELECT></span>&nbsp;
	<INPUT TYPE=submit class="smalloutlinebutton button" style="width=60" VALUE="Inspect">&nbsp;&nbsp;
</td></tr></table></form>
</td></tr></table>
</center></body></html>
EOFORM2
}

sub error
{
    &MS_pages_header ("Sequest Status", "#156ACE");

    print "<h2>Error</h2><div>$_[0]</div>\n";
    print "</BODY></HTML>";
    exit 1;
}

## output Javascript code for this page
sub print_javascript {
	print <<EOF;
<script language="Javascript">
<!--
	var iniAge = 0;

	now = new Date();
	var Start = now.getTime();

	function displayTime()
	{ 
		var absSec = 30 - Math.round(calculateTime());
		if (absSec < 0) absSec = 0;
		var relSec = absSec % 60;
		var absMin = Math.round((absSec-30)/60);
		var dispSec ="" + ((relSec > 9) ? relSec : "0" + relSec);
		var dispMin ="" + ((absMin > 9) ? ((absMin > 99) ? absMin : "" + absMin) : "&nbsp;" + absMin);
		// the following use of the <font> tag is a KLUDGE to work around a bug in Netscape:
		var dispString = '<font color=#FF0000><span class="normaltext">' + dispMin + ':' + dispSec + '</span></font>';
		if(document.all)
		{
			document.all.MicrosoftClock.innerHTML = dispString;
			document.all.spacing.innerHTML = "";
		}
		else if(document.layers)
		{
			document.outerClock.document.NetscapeClock.document.open();
			document.outerClock.document.NetscapeClock.document.write(dispString);
			document.outerClock.document.NetscapeClock.document.close();
		}
		window.setTimeout('displayTime()',1000); 
	}
 	
	onload = displayTime;    

	function calculateTime()
	{ 
		var nowagain = new Date(); 
		return(((nowagain.getTime() - Start)/1000) + iniAge);
	}

	var imagesrc;
	function invert(image) {
		imagesrc = image.src;
		image.src = "$images{'invert'}";
	}
	function uninvert(image) {
		image.src = imagesrc;
	}
	
	function submitform(procAction,ID) {
		document.killprocs.ID.value = procAction;
		document.killprocs.ID.name = ID;
		if (procAction == "kill") {
			var op = prompt("Operator:", "");
			if (op == null)
				return;
			if (op == "") {
				alert("You must enter your initials in the Operator field!");
				return;
			}
			document.killprocs.operator.value = op;
		}
		document.killprocs.submit();
	}

	function link_to_distributor(dir, commandoption) {

		if (commandoption != null) {
			document.location = "$seqdistributor?run_dir=" + dir + "&commandoption=" + commandoption;
		}
		else {
			document.location = "$seqdistributor?run_dir=" + dir;
		}
	}

//-->
</script>
EOF
}

#List all the sequest runs
sub list_sequests {
	my(@seqs) = &read_status;
	# extract error messages from this list of Sequest processes
	@procs = ();
	foreach $seq (@seqs) {
		if ($seq =~ s/^Error:\s*//) {
			push(@errors,$seq);
		} else {
			push(@procs,$seq);
			# divide @procs into undistributed and distributed procs
			if ($seq =~ /^(.*)_DIST\d+$/) {
				$distributed{$1} = 1;
				push(@{$components{$1}},$seq);
			} else {
				push(@undistributed,$seq);
			}
		}
	}
	@distributed = keys %distributed;

	my $sequestheading = &create_table_heading(title=>"Sequests");
	print <<EOF;
<form name="killprocs" action="$ourname" method=post>
<input type=hidden name="control" value="ja">
<input type=hidden name="operator">

<TABLE cellspacing=0 cellpadding=0 border=0 width=850>
<tr><td>$sequestheading<td></tr>
<tr><td>
<table cellspacing=0 cellpadding=0 border=0 width=100% style="border: solid #000099; border-width:1px">
		<tr bgcolor=#f2f2f2 height=20> <th class=smallheading width=220 nowrap>Directory</th> 
		<th class=smallheading width=120 nowrap>Database</th>
		<th class=smallheading width=75 nowrap>Elapsed</th>
		<th class=smallheading width=85 nowrap>Progress</th>
EOF
	print qq(<th class=smallheading width=100 nowrap>Host);
	print qq(<span style="color:#FF0000">*</span>) if ($multiple_sequest_hosts && @undistributed);
	print qq(<th class=smallheading width=100 nowrap>Status</th>);
	print qq(<th class=smallheading width=70 nowrap>Control</th>);
	print qq(<th class=smallheading width=80 nowrap> Q Immunity </th>) if ($multiple_sequest_hosts);
	print qq(</tr>\n);
 
	if (!@procs)
	{
		if (@errors) {
			print "<tr height=30><td align=center colspan=8><span class=smalltext>No Sequests Currently Running on $ENV{'COMPUTERNAME'}.</span>\n";
			print "<span style=\"color:#FF0000\">" . join("<BR>", @errors) . "</span></td></tr>\n";
		} else {
			print "<tr height=30><td align=center colspan=8><span class=smalltext>No Sequests Currently Running</span></td></tr>\n";
		}

	} else {
		foreach $ID (@undistributed) {
			&print_seq_status($ID);
		}
		foreach $distrun (@distributed) {
			$firstproc = $components{$distrun}->[0];
			&print_seq_status($firstproc, 1);
		}	
		print qq(<tr><td style="font:5">&nbsp;</td></tr>);
	}
	print "</table></td></tr></table>\n";
	print "<input type=hidden name=\"ID\"></form>\n";
	print "<span style=\"color:#FF0000\">" . join("<BR>", @errors) . "</span><p>\n" if (@errors);
}		

# print each sequest run status, provides controls in order to kill, pause, resume and distribute each run.
sub print_seq_status{
	my ($ID, $distributedrun) = @_;
	my $dirpath = $dirpath{$ID};
	my $dr = $fancyname{$dirpath};
	my $titleTag;  # Used for the title popup on distributed runs

	if ($dr ne "") {
		my $hostandIds;
		if (defined $distributedrun) {
			my $newline = "";
			foreach $seqproc (@{$components{$distrun}}) {	
				$titleTag .= "$newline$host{$seqproc}";			
				$newline = "\n";
				$hostandIds .= "$host{$seqproc}:$seqproc\:::";
			}
		} else {
			$hostandIds = "$host{$ID}:$ID";
		}

		($dbase_short = $dbase{$ID}) =~ s/\.fasta//;
		if ($dbase_short =~ /\.bin/) {
			($dbase_short =~ s/\.bin/ (bin)/);
		} else {
			$dbase_short .= " (inx)" if (-e "$seqdir/$dirpath/use_seqindex.txt");
		}
		$PorC = ($status{$ID} eq "RUNNING") ? "pause" : "continue";

		# added by cmw 5/12/98
		# create progress report, "#OUTs done out of #DTAs"
		opendir(DIR,"$seqdir/$dirpath");
		my(@allfiles) = readdir(DIR);
		closedir(DIR);
		$num_outs{$ID} = grep(((/\.out$/) && (-s "$seqdir/$dirpath/$_")), @allfiles);	# exclude any 0-byte OUTfiles
		$num_dtas{$ID} = grep /\.dta$/, @allfiles;
		my $progress_report;
		if ($num_outs{$ID} < $num_dtas{$ID}) {
			$progress_report = "$num_outs{$ID} of $num_dtas{$ID}";
		} else {
			$progress_report = "-";
		}
		
		my $elapsedtime = &elapsed_time("$seqprocdir/$host{$ID}/$ID/.running");			
		my $dirlink = &create_link(link=>"$createsummary?directory=$dirpath&sort=consensus", text=>"$dr", class=>"smalltext");
		my $progresslink = &create_link(link=>"$inspector?directory=$dirpath", text=>"$progress_report", class=>"smalltext");
		print <<EOM;
<tr height=20><td class=smalltext nowrap>&nbsp;&nbsp;$dirlink</td>
      <td align=center class=smalltext nowrap>$dbase_short</td>
	  <td align=center class=smalltext nowrap>$elapsedtime</td>
	<td align=center class=smalltext nowrap>$progresslink</td>
	<td align=center class=smalltext nowrap>
EOM
		if (!defined $distributedrun) {
			if ($multiple_sequest_hosts) {
				print qq(<span class="dropbox"><select style="font-size:11" name="switch=$host{$ID}:$ID:$dirpath{$ID}:$dbase{$ID}" onChange="document.killprocs.submit()" style="height=8">);
				foreach $remserver ($ENV{'COMPUTERNAME'}, @seqservers) {
					print (($remserver eq $host{$ID}) ? "<option value=\"\" selected>$remserver" : "<option>$remserver");
				}
				print "</select></span>\n";
			} else {
				print "$host{$ID}";
			}
		} else {
			my $distributelink = $multiple_sequest_hosts ? qq(<span style="cursor:hand; color:#0000cc;" title="$titleTag" onclick="document.location='$seqdistributor?run_dir=$dirpath';"
							onmouseover="this.style.color='red';window.status='$seqdistributor?run_dir=$dirpath';return true;"
							onmouseout="this.style.color='#0000cc';window.status='';return true;">Distributed</span>) : "Distributed";
			print $distributelink;
		}
		my $statusimage = $status{$ID} eq "RUNNING" ? "$images{'run'}" : "$images{'pause'}";
		print <<EOM;
  </td>
  <td align=center class=smalltext nowrap><img src="$statusimage">&nbsp;$status{$ID}</td>
EOM
		if ($status{$ID} ne "POST-PROCESSING") {
			my $distributeimage = $multiple_sequest_hosts ? qq(<img src="$images{'distribute'}" title="distribute" onmouseover="invert(this)" onmouseout="uninvert(this)" onclick="link_to_distributor('$dirpath')">) : "";
			if (defined $distributedrun ) {
				print qq(<td align=center nowrap><img src="$images{'kill'}" title=" kill " onmouseover="invert(this)" onmouseout="uninvert(this)" onclick="submitform('kill','$hostandIds')">&nbsp;$distributeimage&nbsp;&nbsp;&nbsp;</td>);
			}
			else {
				my $image = $PorC eq "continue" ? "$images{'run'}" : "$images{'pause'}";
				print qq(<td align=center nowrap><img src="$image" title="$PorC" onmouseover="invert(this)" onmouseout="uninvert(this)" onclick="submitform('$PorC','$host{$ID}:$ID')">&nbsp;<img src="$images{'kill'}" title=" kill " onmouseover="invert(this)" onmouseout="uninvert(this)" onclick="submitform('kill','$hostandIds')">&nbsp;$distributeimage</td>)
			}
		} else {
			print <<EOM;
<td colspan=2 align=center  class=smallheading nowrap>(unavailable)</td>
EOM
		}
		if ($multiple_sequest_hosts) {
			unless (&is_Qimmune($host{$ID},$ID)) {
				print <<EOT;
<td align=center class=smalltext><input type=checkbox  onclick="javascript:submitform('immunize','$hostandIds')"></td>
EOT
			} else {
				print <<EOT;
<td align=center class=smalltext><input type=checkbox checked onclick="javascript:submitform('deimmunize','$hostandIds')"></td>
EOT
			}
		}
		print qq(</tr>\n);
	}
}

# returns the elapsed time in the format hh:mm:ss
sub elapsed_time {
	my $file = shift;
	my $fileage = (-M "$file") * 24;
	my $hour, $min, $sec;
	($hour, $min) = split '\.', $fileage;
	$min = "0." . $min;
	$min = $min * 60;
	($min, $sec) = split '\.', $min;			
	$sec = "0." . $sec;
	$sec = $sec * 60;
	($sec) = split '\.', $sec;
	$hour = "0" . $hour if ($hour < 10);
	$min = "0" . $min if ($min < 10);
	$sec = "0" . $sec if ($sec < 10);
	my $elapsedtime = "$hour:$min:$sec";
	return $elapsedtime;
}


