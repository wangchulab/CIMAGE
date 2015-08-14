#!/usr/local/bin/perl

#-------------------------------------
#	Inspector,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



$ALERT = 10;   # Inspector will produce an alert if the newest OUTfile in a directory
# where Sequest is running is older than $ALERT times the average time.

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
################################################

&cgi_receive;


if ($FORM{"directory"}) {
	&inspector;
} else {
	&output_form;
}

exit 0;


sub convertTimeToSecs {
	$_ = shift;
	
	if (/(\d+) hr/) {
		$hours = $1
	} else {
		$hours = 0
	}
	if (/(\d+) min/) {
		$min = $1
	} else {
		$min = 0
	}
	if (/(\d*.\d+) sec/) {
		$sec = $1
	} else {
		$sec = 0
	}
	$secstoadd = (3600 * $hours) + (60 * $min) + $sec;	
	return $secstoadd;
}

sub convertSecsToTime {
	my $totalsecs = shift;
	my ($hrstr, $minstr, $secstr);
	
	$avgsectenth = (int ($totalsecs * 10)) / 10;
	$avgmins= int($totalsecs / 60);
	$avgsectenth = $avgsectenth - (60 * $avgmins);
	$avgsectenth = precision($avgsectenth, 1);
	$avghrs = int ($avgmins/ 60);
	$avgmins= $avgmins - (60 * $avghrs);
	$hrstr = "$avghrs hrs." if ($avghrs);
	$minstr = "$avgmins min." if ($avgmins);
	$secstr = "$avgsectenth sec.";
	
	return ($hrstr, $minstr, $secstr);
}

sub inspector
{
	# given a directory name, produce a table of status information
	
	$webdir = "$webseqdir/$FORM{'directory'}";
	$cwd = "$seqdir/$FORM{'directory'}";
	chdir "$cwd";
	
	
	#system ("$showsequest");
	# do our own code, so we can use tables, eliminate the process list, etc.
	opendir (DIR, ".") or &error("Cannot read directory: $!\n");
	@interesting = grep { /\.(dta|out)$/ } readdir(DIR);
	closedir DIR;
	
	@dtas = sort { $a cmp $b } (grep { /\.dta$/ } @interesting);
	@maybeouts = grep { /\.out$/ } @interesting;			# some of these may be 0-byte files
	
	# construct @outs, which is just @maybeouts, free of 0-byte files
	@outs = ();
	foreach (@maybeouts) {
		push(@outs,$_) if (-s "$_");
	}
	
	# set up hashed array to see which .dta files have .out files
	# read each .out and find the time information, which appears in a line like:
	# 04/03/97, 11:35 AM, 1 hr. 39 min. 30 sec. on $hostname
	
	# variable @secs added by cmwendl (2/17/98) to compute average timetaken
	@secs = ();
	
	foreach $out (@outs) {
		($dtaname = $out) =~ s/out$/dta/;
		
		open (FILE, "$out") || next;
		while (<FILE>) {
			# scan until we get a line of the appropriate format
			# changed to match 4-digit dates in Sequest C2 output
			if (m!(../../..+, \d+:.. ..), (.*) on (\S+)!) {
				($starttime{"$dtaname"}, $timetaken{"$dtaname"}, $onhost{"$dtaname"}) = ($1, $2, $3);
				
				# This is a hash that contains the servers name, total time in seconds the server has been running
				# and the number of completed runs on the server.
				($status{"$3"}{"time"}, $status{"$3"}{"completed"}) = 
					($status{"$3"}{"time"}+=convertTimeToSecs($2),$status{"$3"}{"completed"}+=1);
			}
			# changed by martin 98/9/2 to allow for Sequest C2 style OUT files
            chomp;
			# New post-C2 format, the line begins with #, and get the portion of the line before the first .fasta
			next unless ((/rho=.*[\/\\](\S+?)\.fasta\s*/i) || (m!\#.*?([^\\\/]*)\.fasta.*$!i));
			$db{$dtaname} = $1;
			last;
		}
		close FILE;  
		
		########### added 2/13/98 by cmwendl ########################
		# make each entry of @secs the number of seconds in timetaken
		# SDR. modified to use a function to compute time in seconds
		push (@secs, convertTimeToSecs($timetaken{"$dtaname"}));
		###################################################
	}
	
	#### compute average timetaken (2/13/98, cmwendl) ####
	$counts = @secs;
	
	# sort @secs in numerical order
	sub numerically { $a <=> $b; }
	@secs = sort numerically @secs;
	
	# cutoff the highest 10% of @secs (a bad, but easy way to eliminate obvious deviations)
	$cutoff = int ($counts/10);
	foreach (1..$cutoff) {
		pop(@secs)
	}
	$counts = @secs;
	
	# add up total (remaining) number of seconds
	$totalsecs = 0;
	foreach (@secs) {
		$totalsecs += $_;
	}
	
	@serverkeys = sort keys %status;
	$numOfServers = @serverkeys;
	
	foreach $server (@serverkeys) {
		# THis should never happen, as only a server with a completed run should show up, but just in case.
		if ($status{$server}{"completed"} == 0) {
			$status{$server}{"formattedTime"} = "No runs completed";
			next;
		}
		$avgsecs = $status{$server}{"time"} / $status{$server}{"completed"};
		($hrstr, $minstr, $secstr) = convertSecsToTime($avgsecs);
		$status{$server}{"formattedTime"} = "$hrstr $minstr $secstr";
	}
	
	# compute average and produce a string out of it
	if ($counts) {
		$avgsecs = $totalsecs / $counts;
		($hrstr, $minstr, $secstr) = convertSecsToTime($avgsecs);
		$avgtime = "Average Time: $hrstr $minstr $secstr";
	} else {
		$avgtime = "";
	}
	
	######################################################
	
	#$num_sel = 0;
	#
	# get the number selected by looking at the command line
	#                     format of a dta filename
	#while ($info[1] =~ m!([\w\-]+\.\d+\.\d+\.\d\.dta)\s!g) {
	#  $selected{$1} = 1;
	#  $num_sel++;
	#}
	# wtf were those lines supposed to do???
	# i'm commenting them out and adding something that i think
	# should determine whether each file is selected: (cmwendl, 3/16/98)
	$num_sel = 0;
	if (open(SELECTED, "<selected_dtas.txt")) {
		while (<SELECTED>)
		{
			chomp($_);
			$selected{$_} = 1;
			$num_sel++;
		}
	}
	
	$num_dtas = $#dtas + 1;
	$num_outs = $#outs + 1;
	
	
	######### added 2/17/98 (cmwendl) to estimate time left in a run #########
	$notdone = $num_dtas - $num_outs;
	if (($notdone) && ($num_outs)) {
		$secsleft = $avgsecs * $notdone;
		if ($numOfServers != 0) {
			$secsleft = $secsleft / $numOfServers;
		}
		$secsleftint = int ($secsleft);
		($hrstr, $minstr, $secstr) = convertSecsToTime($secsleftint);
		if ($hrstr) {
			$timeleft = "Time to Completion: $hrstr $minstr"
		} else {
			$timeleft = "Time to Completion: $minstr $secstr"
		}
	}
	else {
		$timeleft = "";
	}
	
	## also note use of the variables $avgtime and $timeleft below
	##########################################################################
	
	# print alert if most recent OUTfile is very old
	# if Sequest run is (or should be) in progress
	if ( $counts &&  ($#outs < $#dtas ) && ( ( $num_sel && ($#outs + 1) < $num_sel ) || ( $num_sel == 0  ) ) )
	{
		# find age of newest outfile
		$mostrecent = 3650; # assume by default that nothing's over 10 years old
		foreach (@outs)
		{
			$recent = (-M "$_");
			if ($recent < $mostrecent) {
				$mostrecent = $recent;
			}
		}
		$mostrecent *= (24 * 60 * 60);	# convert days to seconds
		if ($mostrecent > ($avgsecs * $ALERT)) {
			$alert = qq(<br><br><span style="color:#D00000" class="largetext"><b>Alert! This directory has been idle for over $ALERT times the average time!</b></span>\n);
		}
	}
	
	
	$refresh = ($notdone ? &refresh_page($INSPECTOR_REFRESH) : "");			# put in refresh meta-command only if not done
	#&MS_pages_header ("Inspector", "#7093DB", $refresh);
	&MS_pages_header ("Inspector", "#7093DB",  "tabvalues = Inspector&Inspector:\"/cgi-bin/inspector_mintu.pl\"&Sequest Distributor:\"$webcgi/sequest_distributor.pl?run_dir=$FORM{\"directory\"}\"&View Directory:\"$webdir\"&Sequest Params:\"$webdir/sequest.params\"&View Info:\"$viewheader?directory=$FORM{'directory'}\"");
	
	if ($numOfServers > 1) {
		loadjavascript();
	}
		
	#print "<HR><P>\n";
	#print <<HEADING;
	#<a href="$webdir"><img border=0  align=top src="$webimagedir/p_view_directory.gif"></a> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	#<A HREF="$webdir/sequest.params"><img border=0 align=top src="$webimagedir/p_sequest_params.gif"></A> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	#<A HREF="$viewheader?directory=$FORM{'directory'}"><img border=0  align=top src="$webimagedir/p_view_info.gif"></A> &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;
	#<a href="$webcgi/sequest_distributor.pl"><img border=0 width=105 height=14 align=top src="$webimagedir/p_seqdistributor.gif"></a>
	
	print qq(<div>$alert</div>);
	#HEADING
	
	print <<TABLETOP;
<P>
<TABLE BORDER=0 CELLPADDING=0>
<TR>
<TD VALIGN=top COLSPAN=2><B>$avgtime</B><br>&nbsp;</TD>
<TD VALIGN=top COLSPAN=2><B>$timeleft</B><br>&nbsp;</TD>
</TR>
TABLETOP

if ($numOfServers > 1) {
	print qq(<TR><TD><img src="$webimagedir/tree_closed.gif" id="toggle" onclick="toggleServerView(this);" style="cursor:hand">&nbsp;<B>Server Averages</B></TD></TR>);
	print qq(<TR><TD VALIGN=top COLSPAN=3><SPAN id=serverInfoSpan style="display:'none'">);
	
	print qq(<TABLE BORDER=0 CELLPADDING=0>);
	print qq(<TH align=left>Server</TH><TH align=left>Completed</TH><TH align=left>Avg. Time</TH>);
	foreach $server (sort keys %status) {
		print qq(<TR><TD><TT>$server&nbsp;&nbsp;</TT></TD>);
		print qq(<TD ALIGN=left WIDTH=100><TT>$status{$server}{"completed"}</TT></TD>);
		print qq(<TD ALIGN=left NOWRAP><TT>$status{$server}{"formattedTime"}</TT></TD>);
	}
	print qq(</TABLE></SPAN><BR></TD></TR>);	
}
print <<TABLETOP;

<TR>
<TH>$num_dtas input Dtafiles</TH>
<TH>$num_sel dtas</TH>
<TH COLSPAN=2>$num_outs outfiles completed</TH>
</TR>
	
<TR>
<TH HEIGHT=20>Dta filename</TH>
<TH>Selected</TH>
<TH>Time</TH>
<TH>Length of run</TH>
<TH>&nbsp;Database&nbsp;</TH>
<TH>&nbsp;Host&nbsp;</TH>
<TH></TH>
</TR>
<TR>
TABLETOP
	
	@cells = ();	# array of array refs to store cell contents
	$row = 0;		# index for @cells
	
	foreach $dta (@dtas) {
		$start = $starttime{"$dta"};
		$time = $timetaken{"$dta"};
		$sel = ($selected{"$dta"}) ? "X" : "&nbsp;";
		$db = $db{"$dta"};
		$onhost = $onhost{"$dta"};
		
		@cells[$row] = [
			"<tt>$dta&nbsp;</tt>",
			"<tt>$sel</tt>",
			"<tt>&nbsp;$start&nbsp;</tt>",
			"<tt>&nbsp;$time&nbsp;</tt>",
			"<tt>&nbsp;$db&nbsp;</tt>",
			"<tt>&nbsp;$onhost&nbsp;</tt>",
			"<tt>&nbsp;</tt>"
		];
		$row++;
	}
	
	foreach $out (@outs) {
		($dtaname = $out) =~ s/out$/dta/;
		unless (-e "$dtaname")   # for all outfiles with no corresponding dta
		{
			$start = $starttime{"$dtaname"};
			$time = $timetaken{"$dtaname"};
			$sel = ($selected{"$dtaname"}) ? "X" : "&nbsp;";
			$db = $db{"$dtaname"};
			$onhost = $onhost{"$dtaname"};
			
			@cells[$row] = [
				"<tt><b><span style=\"color:#c00000\">$out&nbsp;</span></b></tt>",
				"<tt>$sel</tt>",
				"<tt>&nbsp;$start&nbsp;</tt>",
				"<tt>&nbsp;$time&nbsp;</tt>",
				"<tt>&nbsp;$db&nbsp;</tt>",
				"<tt>&nbsp;$onhost&nbsp;</tt>",
				"<tt><b><span style=\"color:#c00000\">&nbsp;(no DTA)</span></b></tt>"
			];
			$row++;
			
		}
	}
	
	# print main table contents all at once
	print "<TD NOWRAP VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[0];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD ALIGN=center VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[1];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD NOWRAP VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[2];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD NOWRAP VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[3];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD NOWRAP ALIGN=center VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[4];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD NOWRAP VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[5];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	print "<TD NOWRAP VALIGN=top>\n";
	for ($row = 0; $row <= $#cells; $row++)
	{
		print "	" . $cells[$row]->[6];
		print ($row == $#cells ? "\n" : "<br>\n");
	}
	print "</TD>\n";
	
	print ("</TR></TABLE>\n");
	
	
	if ($no_selected_file) {
		print ("N.B. There is no selected_dtas.txt file for this directory.\n");
	}
	
}






sub output_form
{
	&MS_pages_header ("Inspector", "#7093DB");
	print "<HR><P>\n";
	
	&get_alldirs;
	
	print <<EOFORM;
<TABLE><TR><TD>
	<FORM NAME="inspector" ACTION="$ourname" METHOD=get>
	<span class="smallheading">Choose a directory:</span><br>
	<span class=dropbox><SELECT NAME="directory">
EOFORM
	
	foreach $dir (@ordered_names) {
		print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
	}
	
	print <<EOFORM2;
	</SELECT></span>&nbsp;
	<INPUT TYPE=submit CLASS=button VALUE="Inspect Status">
	</FORM>
</TD></TR></TABLE>
	
EOFORM2
	
	print "</CENTER>\n";
	print "</body></html>";
}

sub loadjavascript {
	print <<EOF;
<script language="Javascript">
<!--
	function toggleServerView() {
		var button = document.getElementById("toggle");
		var span = document.getElementById("serverInfoSpan");

		if (span.style.display == "none") {
			button.src = "$webimagedir/tree_open.gif";
			span.style.display = "";
		} else {
			button.src = "$webimagedir/tree_closed.gif";
			span.style.display  = "none";
		}
	}
//-->
	</script>
EOF
}

sub error
{
	&MS_pages_header ("Inspector", "#7093DB");
	print "<p>Error: $_[0]<P>\n";
	print "</BODY></HTML>";
	exit 1;
}


