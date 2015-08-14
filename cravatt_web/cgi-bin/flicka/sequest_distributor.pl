#!/usr/local/bin/perl

#-------------------------------------
#	Sequest Distributor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


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
$MAX_NUM_SPLIT = 8;


&error("You cannot run this program.  Your intranet is not set up to run Sequest on multiple hosts.") unless ($multiple_sequest_hosts);

require "seqcomm_include.pl";
require "seqstatus_include.pl";

&cgi_receive;

$MAX_NUM_SPLIT = $FORM{"MAX_NUM_SPLIT"} if (defined $FORM{"MAX_NUM_SPLIT"});

$run_dir = $FORM{"run_dir"} if (defined $FORM{"run_dir"});
if ($FORM{"command"} eq "kill") {
	&distribute_html("kill");
} elsif ($FORM{"do"}) {
	&distribute_html;
} elsif ($FORM{"distribute_using_defaults"}) {
	&distribute_html;	
}

&MS_pages_header ("Sequest Distributor", "#AA66FF", $nocache);
print "<hr><br>";

&get_alldirs;

if (-e "$seqcommdir/sequest_status.txt") {
	$age = (-M _) * 24 * 60;	# age of sequest_status.txt in minutes
	$age = sprintf("%.1f",$age);
} else {
	$age = 0;
}

@seqs = &read_status;
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



if (!@undistributed && !@distributed)
{
	print "<CENTER>\n";
	if (@errors) {
		print "<H4>No Sequests Currently Running on $ENV{'COMPUTERNAME'}.</H4>\n";
		print "<span style=\"color:#FF0000\">" . join("<BR>", @errors) . "</span><p>\n";
	} else {
		print "<H4>No Sequests Currently Running.</H4>\n";
	}
	print "</CENTER>\n";

}
else 
{
	print <<EOF;
<script language="Javascript">
<!--

function defaultradio()
{
	var myradio = document.forms[0].distribute;

	if (!myradio.length) {
		myradio.checked = true;
		selectedVal = myradio.value;
	}
}

function submitform()
{
	var commandBut = document.forms[0].command[0];

	var selectedVal = "", selectedDir;
	var ind, ind2;

	var myradio = document.forms[0].distribute;

	if (myradio.length) {	// if there are multiple radio buttons
		for (i = 0; i < myradio.length; i++) {
			if (myradio[i].checked)
				selectedVal = myradio[i].value;
		}
	} else {			// if there is only one radio
		if (myradio.checked)
			selectedVal = myradio.value;
	}

	if (selectedVal == "") {
		alert("You haven't selected a run to distribute!");
		return;
	}

	if (commandBut.status == false) {
		kill();
		return -1;
	}

	ind = selectedVal.indexOf(":::") + 3;
	ind2 = selectedVal.indexOf(":::",ind);
	selectedDir = selectedVal.substring(ind,ind2);

	if (confirm("Are you sure you want to distribute " + selectedDir + "?")) {
		document.forms[0].submit();
	}
}

function kill() {
EOF
	print "document.forms[0].killtocomp.value = \"$DEFAULT_SEQSERVER\";";
	print <<EOF;
	document.forms[0].submit();
}

function unselectall () {
EOF
	for ($i=1;$i <= $MAX_NUM_SPLIT; $i++) {
		print "document.all.server$i.selectedIndex=0;";
	}
	print <<EOF;
}
//-->
</script>

<form action="$ourname" method="get">
<table cellspacing=0 cellpadding=0 border=0>
<tr>
	<td><b>Select</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Directory</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Database</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Status</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Progress</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Host</b>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<b>Q immunity?</b></td>
</tr>
EOF

	# if only one run make the radio button selected by default.
	# However if a run_dir parameter is present, select only if it matches the only active run
	my $default_selected = (($#undistributed + $#distributed + 2) == 1) && (!defined $run_dir);

	foreach $seqproc (@undistributed) {
		my $radio_selected = (($run_dir eq $dirpath{$seqproc}) || $default_selected) ? "CHECKED" : "";
		opendir(DIR,"$seqdir/$dirpath{$seqproc}");
		@allfiles = readdir(DIR);
		closedir(DIR);
		$num_outs = grep(((/\.out$/) && (-s "$seqdir/$dirpath{$seqproc}/$_")), @allfiles);	# exclude any 0-byte OUTfiles
		$num_dtas = grep /\.dta$/, @allfiles;
		$dirname = $fancyname{$dirpath{$seqproc}};
		$progress_report = ($num_outs < $num_dtas) ? "$num_outs of $num_dtas" : "done";
		$immunity = (&is_Qimmune($host{$seqproc},$seqproc)) ? "yes" : "no";
		$value = "$seqproc" . ":::$dirpath{$seqproc}:::$dbase{$seqproc}:::$host{$seqproc}:$seqproc";

		print <<EOF;
<tr>
	<td align=center><input type=radio name="distribute" value="$value" $radio_selected></td>
	<td>&nbsp;&nbsp;<tt>$dirname</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$dbase{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$status{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$progress_report</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$host{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td align=center>&nbsp;&nbsp;<tt>$immunity</tt></td>
</tr>
EOF
	}

	foreach $distrun (@distributed) {

		$firstproc = $components{$distrun}->[0];
		$value = "$distrun" . ":::$dirpath{$firstproc}:::$dbase{$firstproc}:::" . join(":::",map "$host{$_}:$_", @{$components{$distrun}});
		my $radio_selected = ($run_dir eq $dirpath{$firstproc} || $default_selected) ? "CHECKED" : "";
		$radio{$firstproc} = qq(<input type=radio name="distribute" value="$value" $radio_selected>);
		
		foreach $seqproc (@{$components{$distrun}}) {	
			opendir(DIR,"$seqdir/$dirpath{$seqproc}");
			@allfiles = readdir(DIR);
			closedir(DIR);
			$num_outs = grep(((/\.out$/) && (-s "$seqdir/$dirpath{$seqproc}/$_")), @allfiles);	# exclude any 0-byte OUTfiles
			$num_dtas = grep /\.dta$/, @allfiles;
			$dirname = $fancyname{$dirpath{$seqproc}};
			$progress_report = ($num_outs < $num_dtas) ? "$num_outs of $num_dtas" : "done";
			$immunity = (&is_Qimmune($host{$seqproc},$seqproc)) ? "yes" : "no";

			print <<EOF;
<tr>
	<td align=center>$radio{$seqproc}</td>
	<td>&nbsp;&nbsp;<tt>$dirname</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$dbase{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$status{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$progress_report</tt>&nbsp;&nbsp;</td>
	<td>&nbsp;&nbsp;<tt>$host{$seqproc}</tt>&nbsp;&nbsp;</td>
	<td align=center>&nbsp;&nbsp;<tt>$immunity</tt></td>
</tr>
EOF
		}
	}

	
	print <<EOF;
</table>
EOF
	if (@errors) {
		print "<p><center><span style=\"color:#FF0000\">" . join("<BR>", @errors) . "</span></center>\n";
	}
	print <<EOF;
<p>
Choose a Sequest run from the list above, then choose a server for each component part into which it should be split.
You can redistribute it into anywhere from 1 to $MAX_NUM_SPLIT processes.  You needn't choose a server in every dropbox if you want to use less than $MAX_NUM_SPLIT.
</p>
EOF

	foreach $i (1..$MAX_NUM_SPLIT) {
		$i_disp = ($i < 10) ? "&nbsp;$i" : "$i";
		print qq(<nobr><tt>$i_disp.</tt> <span class=dropbox><select name="server$i">);
		
		print qq(<option value="">----------------);
		foreach $servername ($ENV{'COMPUTERNAME'},@seqservers) {
			$selected = ($servername eq uc($DEFS_SEQUEST_DISTRIBUTOR{"Process$i"})) ? " selected" : "";
			print qq(<option$selected>$servername);
		}
		print "</select></span></nobr>\n";
		print "<br>\n" if ($i % 4 == 0);
	}
	my %commandoption = ();
	$commandoption{"kill"} =  "checked" if ($FORM{"commandoption"} eq "kill");
	$commandoption{"distribute"} = "checked" if ($commandoption{"kill"} ne "checked");
	print <<EOF;
<div>
<BR>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=reset class=button value="&nbsp;&nbsp;All&nbsp;&nbsp;">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input type=button class=button value="None" onClick="unselectall()"><BR><BR>
<table><tr><td>&nbsp;&nbsp;&nbsp;&nbsp;</td><td>
<!-- 
	<table cellspacing=0 cellpadding=0 border=1 bordercolorlight='#f2f2f2' bordercolordark='BLACK'><tr height=24>
<td bgcolor='#AA66FF' align=center width=68 style="cursor:hand" onclick="submitform()">Execute</td></tr></table>
	-->
<input type=button class=button value="Execute" onclick="submitform()" style="background-color: #AA66FF;">	

</td>
<td>&nbsp;&nbsp;<input type=radio name="command" value="distribute" $commandoption{"distribute"}>Distribute</td>
<td><input type=radio name="command" value="kill" $commandoption{"kill"}>Kill</td>
<td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html" target=_blank>Help</a></td></tr></table>
<input type=hidden name="do" value="hidden">
<input type=hidden name="killtocomp" value="">

EOF

}

print "</form></body></html>";
exit;



sub distribute_html {
	my ($process) = @_;
	if ($FORM{"distribute"}) {
		($seqID,$dir,$db,@oldprocs) = split /:::/, $FORM{"distribute"};
	} else {
		$dir = $run_dir;
		@seqs = &read_status;
		foreach $proc (@seqs) {
			if ($proc !~ /^Error/) {
				if ($dirpath{$proc} eq $dir) {
					$seqID = $proc;
					$db = $dbase{$proc};
					push @oldprocs, $host{$proc} . ":" . $proc;
				}
			}
		}
	}

	$| = 1;
    &MS_pages_header ("Sequest Distributor", "#AA66FF");
	print qq(<hr><br>);

	&error("You must choose a Sequest run or group of runs to distribute.") unless ($seqID);

	print qq(<p><img src="$webimagedir/circle_1.gif">&nbsp;);

	if ($process ne "kill") {
		print qq(Distributing Sequest run...</p>);
	} else {
		print qq(Killing Sequest run...</p>);
	}

	my $killcomputer = $FORM{"killtocomp"};
	my $distrib_notifier = sub { 
		my ($msg,$machine) = @_;
		if ($msg eq "start") {
			print "&nbsp;&nbsp;&nbsp;Starting Sequest on machine $machine...";
		} elsif ($msg eq "success") {
			print "success.<br>";
		} elsif ($msg eq "failure") {
			print "no response, continuing.<br>";
		}
	};

	@newservers = ();
	
	if ($FORM{'distribute_using_defaults'}) {

		foreach $i (1..$MAX_NUM_SPLIT) {
			if ($DEFS_SEQUEST_DISTRIBUTOR{"Process$i"}) {
				push(@newservers,$DEFS_SEQUEST_DISTRIBUTOR{"Process$i"});
			}
		}

	} elsif ($process eq "kill") {

		# If this is a kill request, then this will set up the next part of code to redistribute to
		# only the computer you'd like to kill the process on.
		@newservers = ("$killcomputer");
		$distrib_notifier = sub { };

	} else {

		foreach $i (1..$MAX_NUM_SPLIT) {
			if ($FORM{"server$i"}) {
				push(@newservers,$FORM{"server$i"});
			}
		}

	}

	&error("You must choose at least 1 computer for the distribution.") unless (scalar(@newservers) >= 1);

	if ($process ne "kill") {
		# cull dead or overloaded servers
		my @evennewerservers = &get_responding_servers(@newservers);
		if ($#newservers != $#evennewerservers && $#evennewerservers > -1) {
			print "<div>&nbsp;&nbsp;&nbsp;One or more servers did not respond; Sequest will not be run on these machines.<br></div>";
			@newservers = @evennewerservers;
		}	
	}

	$operator = "dist";
	
	print "<div>"; # make sure stylesheet formatting gets applied to text
	
	# This makes sure we don't undistribute and redistribute to the same computer if it's the only
	# procedure running.  IE HOST1 is ONLY computer running sequest, and we decide to redistribute
	# it to HOST1, this prevents that from occuring.  This should be negated as a statement.
	($currentcomp, $junk) = split /:/, $oldprocs[0];
	if (scalar(@oldprocs) == 1 && scalar(@newservers) == 1 && $currentcomp eq $killcomputer) {
	} else {
		$error = &distribute($seqID,\@oldprocs,\@newservers,$dir,$db,$operator,$distrib_notifier, $FORM{"xml_output"}, $FORM{"normalize_xcorr"});
		&error("$error") if ($error);
	}

	print "</div>";

	# If killing this process, hack off the _digit since they may have been a distributed run.
	if ($process eq "kill") {
		if ($seqID =~ m/(.*)_\d$/) {
			$newseqID = $1;
		} else {
			$newseqID = $seqID;
		}
		&do_js_redirect("$seqstatus?$killcomputer:$newseqID:$db=kill&operator=$operator&control=ja");
	} else {
		&do_js_redirect("$seqstatus");
	}
}


sub distribute {

	my($seqID,$oldprocs_ref,$newserver_ref,$dir,$db,$operator,$distrib_notifier, $xml_output, $normalize_xcorr) = @_;
	my @oldprocs = @$oldprocs_ref;
	my @newservers = @$newserver_ref;
	my (@switchstamped,$switchstamp,@toberun,@myfiles,$files,$myseqID,@started,$error);

	chdir "$seqdir/$dir";

	# grab each of the old processes and prepare to kill them
	foreach (@oldprocs) {

		($oldserver,$seqid) = split /:/;
		$oldserver{$seqid} = $oldserver;

		# double check that this Sequest is still running where we think it is
		unless (&is_running($oldserver,$seqid)) {
			# clean up and abort
			foreach $id (@switchstamped) {
				$switchstamp = "SWITCHSTAMP$id";
				close $switchstamp;
				unlink "$seqprocdir/$oldserver{$id}/$id/.switch";
			}
			return "Distribution aborted -- are you sure this Sequest is still running where you think it is?" ;
		}

		# prevent more than one process at a time from trying to switch this Sequest
		$switchstamp = "SWITCHSTAMP$seqid";
		open($switchstamp, ">$seqprocdir/$oldserver/$seqid/.switch");
		if (flock $switchstamp, ($LOCK_EX | $LOCK_NB)) {
			# good, we have a lock on it now
		} else {
			close $switchstamp;
			return "Sharing violation -- someone else may have tried to switch this run at the same time.  Go to the Sequest Status page and make sure this Sequest is still running where you think it is.";
		}

		push(@switchstamped,$seqid);

	}



	# some code borrowed from &sequest_launch in microchem_include.pl:

	# run only selected DTAs if that's how Sequest was run last time:
	# i.e. if the file run_selected.txt exists
	$run_selected = (-e "run_selected.txt");
	if ($run_selected) {
		if (open(SELECTED, "<selected_dtas.txt")) {
			@selected_dtas = <SELECTED>;
			close(SELECTED)
		}
	}
	else {
		opendir (THISDIR, ".");
		@selected_dtas = grep /\.dta$/, readdir THISDIR;
		closedir THISDIR;
	}

	@toberun = ();
	foreach $dta (@selected_dtas)
	{
		chomp($dta);
		$out = $dta;
		$out =~ s/\.dta$/.out/;
		push(@toberun, $dta) if (!(-s "$out") && (-e "$dta"));	# the OUTfile must have nonzero size
	}

	unless (@toberun) {
		# clean up and abort
		foreach $id (@switchstamped) {
			$switchstamp = "SWITCHSTAMP$id";
			close $switchstamp;
			unlink "$seqprocdir/$oldserver{$id}/$id/.switch";
		}

		return "This run is already finished.  You may not distribute it.";
	}



	# split @toberun into component parts for distribution

	# use information from sequest_Q.params on servers' relative powers (if available)
	# this defines the %power hash:
	require "$seqcommdir/seqcomm_Q.params" if (-e "$seqcommdir/seqcomm_Q.params");

	$totalpower = 0;
	foreach $i (0..$#newservers) {
		$servername = $newservers[$i];
		$power{$servername} = 1 unless (defined $power{$servername});
		$number_of_processors{$servername} = 1 unless ($number_of_processors{$servername} > 0);
		$totalpower += ($power{$servername} / $number_of_processors{$servername});
		$step[$i] = $totalpower;
	}
	# added by cmw (8/10/99):
	# normalize steps according to the number of DTAs to be run
	foreach (@step) {
		$_ *= (scalar(@toberun)/$totalpower);
	}

	foreach $i (0..$#toberun) {
		$mod = &mod($i, $#toberun + 1);
		foreach $serverindex (0..$#newservers) {
			$prevstep = ($serverindex == 0) ? 0 : $step[$serverindex - 1];
			if (($mod >= $prevstep) && ($mod < $step[$serverindex])) {
				push(@{$myfiles[$serverindex]},$toberun[$i]);
				last;
			}
		}
	}


	# do the actual redistribution

	# assign a "toggle number" (0 or 1) to be appended to $seqID
	if ($seqID =~ /^(.*)_([01])$/) {
		$seqID = $1;
		# toggle 0->1, 1->0
		$seqNum = ($2 + 1) % 2;
	} else {
		$seqNum = 0;
	}

	foreach $i (0..$#newservers) {

		$files = join(" ",@{$myfiles[$i]});
		# Make sure files exist before sending them off to the server...
		if ($files eq "") {
			next;
		}

		$myseqID = ($#newservers > 0) ? $seqID . "_$seqNum\_DIST$i" : $seqID;

		# run each component with a separate sequest.params file to avoid sharing violations
		$seqparams = "sequest_dist$i.params";
		copy("sequest.params",$seqparams);

		$distrib_notifier->("start", $newservers[$i]);
		
		$error = &sequest_launch("seqid"=>$myseqID,"onServer"=>$newservers[$i],"dir"=>$dir,"files"=>$files,"seqparams"=>$seqparams,"xml_output"=>$xml_output,"normalize_xcorr"=>$normalize_xcorr);
		if ($error) {
			
			# 
			# 8/19/02 - under heavy load, servers may not respond before sequest_launch times out, 
			# although the run is eventually started.  so for now, simply report "no response" and continue
			# with the distribution. -LAB
			#

			# unstamp everything that was stamped for switch
			#foreach $id (@switchstamped) {
			#	$switchstamp = "SWITCHSTAMP$id";
			#	close $switchstamp;
			#	unlink "$seqprocdir/$oldserver{$id}/$id/.switch";
			#}
			# kill all runs that i've started
			#foreach (@started) {
			#	my ($servername,$ID) = split /:/;
			#	&kill($servername,$ID,$operator);
			#}
			#return "Distribution failed: $error -- check Sequest Status to make sure everything is still running as it should be.";

			$distrib_notifier->("failure");
		} else {
			$distrib_notifier->("success");
		}

		&Q_immunize($newservers[$i],$myseqID) unless ($#newservers == 0);
		push(@started, "$newservers[$i]:$myseqID");

	}

	sleep 2;	# give seqcomm adequate time to start new runs

	# if we've gotten this far, everything must have started up ok, we can kill the originals
	foreach (@oldprocs) {
		($oldserver,$seqid) = split /:/;
		$switchstamp = "SWITCHSTAMP$seqid";
		close $switchstamp;
		&kill($oldserver,$seqid,$operator);
	}

	return "";

}


# this implements the % operator in floating point
sub mod {
	my($a,$b) = @_;
	return (($b != 0) ? ($a - (int($a/$b) * $b)) : undef);
}



sub error
{
	print "<hr><br>";

    print "<p><b>Error:</b> $_[0]<P>\n";
    print "</BODY></HTML>";
    exit 1;
}

sub do_js_redirect {
my $newloc = shift;
print <<REDIRECT;
<script language="Javascript">
<!--
	function goto_distributor()
	{
		location.replace("$newloc");
	}
	onload=goto_distributor;
//-->
</script>
</body></html>
REDIRECT
exit 0;
}

# 
# given a list of servers, return the subset that respond to
# seqcomm pings
#
sub get_responding_servers {
	my @servers = @_;
	my @alive;

	foreach my $server (@servers) {
		if (!&seqcomm_send($server, "ping")) { # 'ping' doesn't mean anything; seqcomm silently deletes msgs it doesn't understand
			push @alive, $server;
		}
	}

	return @alive;
}
