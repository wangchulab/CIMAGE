#!/usr/local/bin/perl

#-------------------------------------
#	Exterminate,
#	(C)1999 Harvard University
#	
#	W. S. Lane/Unknown/Scott Ruffing)
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: Unknown
#
# Description: Displays the processes currently running on the server with various
# pieces of information such as their priority, memory usage, and the amount of time they've
# been running for on the server.  The page can kill off any of these processes so be careful
# when using this page.
#		
### this is a debugging utility, not part of the Microchem Intranet!
# displays a list of currently running Perl processes (with PIDs), 
# based on Ken Miller's sequest_status_kludge -cmw
#
##CGI-RECEIVE## searchstring - The regular expression to use to filter the program names on.
##CGI-RECEIVE## kill - Use to tell the program to kill the processes listed as CGI key-value below.
##CGI-RECEIVE## Kill(pid) - Set the value to yes to kill the process.  So Kill1504=yes would kill process 504.

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
	require "processstatus.pl";
}
################################################

$default_searchstring = "\\S+";
&cgi_receive;

my $searchstring = $FORM{"searchstring"};

if ($searchstring eq "perl") {
	&MS_pages_header("Exterminate!", "#871F78", "tabvalues=Perl Status&Perl Status:\"$ourname?searchstring=perl\"&Exterminate!:\"$ourname\"&Perl Process Log:\"$ourname?searchstring=log\"");
} elsif ($searchstring eq "log") {
	&MS_pages_header("Exterminate!", "#871F78", "tabvalues=Perl Process Log&Perl Status:\"$ourname?searchstring=perl\"&Exterminate!:\"$ourname\"&Perl Process Log:\"$ourname?searchstring=log\"");
} else {
	&MS_pages_header("Exterminate!", "#871F78", "tabvalues=Exterminate!&Perl Status:\"$ourname?searchstring=perl\"&Exterminate!:\"$ourname\"&Perl Process Log:\"$ourname?searchstring=log\"");
}

&nomercy if ($FORM{"kill"});

&clearlog if($FORM{"clearlog"});

unless ($searchstring eq "log") {
	&list_processes($searchstring);
} else {
	&show_process_log;
}

&leave;


sub error
{
    print $_[0];
    print "</BODY></HTML>";
    exit 0;
}


sub leave {
	print $_ if (shift);  # Output a the argument (if exists) as a message
	print "</body></html>";
	exit(1);
}

##PERLDOC##
# Function : list_processes
# Argument : $searchstring - The regexp search string to look for as a programs name
# Globals  : $default_searchstring - Defined in this code, the name of the text to look for.
# Returns  : NONE
# Descript : Displays to stdout all the pages currently running.  
# Notes    : This is really the output_form for this page and does not simply list the
#            processes in a table, but rather the entire page worth of information.
#			 This program requires pstat.exe to be location in the $cgidir directory
##ENDPERLDOC##
sub list_processes {
	my ($searchstring) = @_;

	# get PID of Q if necessary
	if ($multiple_sequest_hosts) {
		if ((!defined $searchstring) || (lc($searchstring) =~ /perl/)) {
			require "seqcomm_include.pl";
			open(QLOG,"<$seqcommdir/logs/seqcomm_Q.log");
			while (<QLOG>) {
				$Qpid = $1 if (/started, pid=(\d+)$/);
			}
			close QLOG;
		}
	}


	print <<EOF;
<script language="Javascript">
<!--

function showAll()
{
	document.stringform.searchstring.value = "";
	document.stringform.submit();
}

function stringFocus()
{
	document.stringform.searchstring.focus();
	document.stringform.searchstring.select();
}
onload=stringFocus;
//-->
</script>
<div>
<TABLE BORDER=0 CELLPADDING=6 CELLSPACING=3><form name="stringform" action="$ourname" method=get>
<TR><TD COLSPAN=3><span class="smallheading">
Show only programs whose names contain the regular expression: </span>
<input name="searchstring" value="$searchstring"> 
<input type=submit class=button value="Refresh"> 
<input type=button class=button value="Show All" onClick="showAll()"></TD></TR>
</form>
</div>
EOF
	$searchstring = $default_searchstring unless (defined $searchstring);
	print qq(<div><form name="killprocs" action="$ourname" method=get>);
	print qq(<TR><TD COLSPAN=3>Kill arbitrary PIDs: <input name="pid" size=16>\n);
	print qq(<input type=submit style="color:white;background:FF0000" class=button name="kill" value=" Kill ">&nbsp;&nbsp;<FONT color="#FF0000">Admin Only!</FONT></TD></TR>);
	print "<TR><TD valign=top><table cellpadding=0 cellspacing=0 border=0>\n";

	# Get the processes currently running on 	
	my %processes = &getServerProcesses;

	# Sort the hash based on the name of the process.
	my @allprocs = ();
	foreach (keys %processes) {
		push(@allprocs,$_) unless ($_ == $$);
	}
	@allprocs = sort { (lc($processes{$a}{"name"}) cmp lc($processes{$b}{"name"})) || ( $a <=> $b ) } @allprocs;
	unshift(@allprocs,$$) if ($processes{$$});

	# Now make up the table containing all the information for each process that matches the name of
	# the searchstring, color coding the Q, Sniffer, and current pid.
	print "<TH align=left>Program&nbsp;&nbsp;</TH><TH align=left>PID&nbsp;&nbsp;</TH><TH align=left>Priority&nbsp;&nbsp;</TH>";
	print "<TH align=left>Memory&nbsp;&nbsp;</TH><TH align=left>Time&nbsp;&nbsp;</TH>";
	print "<TH align=left>Kill</TH>";
	foreach $pid (@allprocs) {
		my $name = $processes{$pid}{"name"};
		if ($name =~ m/$searchstring/i) {
			$color = ($pid == $$) ? qq( style="color:#FF0000") : "";		# color red if process is self
			$color = qq( style="color:#00A000") if ($pid == $Qpid);		# color green if process is Q
			$color = qq( style="color:#0000AA") if ($pid == $Sniffpid);  # color blue if process is Sniffer
			print "<TR><TD$color>$name&nbsp;&nbsp;</TD>\n";
			print qq(<TD$color><a href="$ourname?searchstring=log&whichprocs=byid&matchid=$pid"$color title="Search perl process log for this process ID">$pid</a>&nbsp;&nbsp;</TD>\n);
			print "<TD$color>$processes{$pid}{\"priority\"}&nbsp;&nbsp;</TD>\n";
			print "<TD$color>$processes{$pid}{\"memory\"}&nbsp;&nbsp;</TD>\n";
			print "<TD$color>$processes{$pid}{\"kerneltime\"}&nbsp;&nbsp;</TD>\n";
			print "<TD> <input type=checkbox name=Kill$pid value=yes> </TD>" unless ($pid == $$);
			print "<TR>";
		}
	}
	print '</table><br></TD><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD><TD valign=top></form>';
	print <<EOF;
<TABLE  border=0 cellspacing=0 cellpadding=5 ><TR><TD bgcolor="#c0c0c0" valign=top><b>Legend</b></TD></TR>
<TR><TD bgcolor="#e2e2e2"><span style="color:#FF0000">Red: the transient Perl process that created this page<br>
<span style="color:#00A000">Green: seqcomm_Q.pl -- kill only if you know what you're doing<br>
<span style="color:#0000AA">Blue: sniffer.pl -- Sniffer for new .RAW files
</div></td></tr></TABLE></TD></TR></TABLE>
EOF

}

##PERLDOC##
# Function : list_processes
# Argument : $searchstring - The regexp search string to look for as a programs name
# Globals  : $default_searchstring - Defined in this code, the name of the text to look for.
# Returns  : NONE
# Descript : Displays to stdout all the pages currently running.  
# Notes    : This is really the output_form for this page and does not simply list the
#            processes in a table, but rather the entire page worth of information.
#			 This program requires pstat.exe to be location in the $cgidir directory
##ENDPERLDOC##
sub show_process_log {

my $num_most_recent = 25; # default to displaying most recent 25 lines

print <<EOF;
<script language="JavaScript">
<!--
function showid()
{
	if (document.logform.matchid.value == "") {
		alert("You must specify a process ID.");
	} else {
		document.logform.whichprocs.value = "byid";
		document.logform.submit();
	}
}
function showall()
{
	document.logform.whichprocs.value = "all";
	document.logform.submit();
}
function showrecent()
{
	document.logform.whichprocs.value = "$num_most_recent";
	document.logform.submit();
}
-->
</script>
<form name="logform" action="$ourname" method="get">
<input type=hidden name="whichprocs">
<input type=hidden name="searchstring" value="log">
<span class="smallheading">Show processes matching process ID:</span>
<input type=text name="matchid" size=4>
<input type=button class=button value="Refresh" onclick="showid()">
<input type=button class=button value="Show All" onclick="showall()">
<input type=button class=button value="Most Recent $num_most_recent" onclick="showrecent()">
<input type=submit class=button name="clearlog" value="Clear Log">
</form>
EOF

if (! $FORM{"clearlog"}) {
	open LOGFILE, "<$perlproclog" or die "Couldn't open log file";
	if ($FORM{'whichprocs'} eq "all") {
		while (chomp($line = <LOGFILE>)) {
			unshift @loglines, $line;
		}
	} elsif ($FORM{'whichprocs'} eq "byid") {
		while (chomp($line = <LOGFILE>)) {
			unshift @loglines, $line if ($line =~ /pid=$FORM{'matchid'}/);
		}
	} else {
		$num_to_display = $FORM{'whichprocs'} ? $FORM{'whichprocs'} : $num_most_recent;
		while (chomp($line = <LOGFILE>)) {
			unshift @loglines, $line;
			if ($#loglines >= $num_to_display) {
				pop @loglines;
			}
		}
	}
	close LOGFILE;
}

print <<EOF;
<table border=0 cellspacing=5 cellpadding=2 width=90%>
<tr>
<th align=left>Script path</th>
<th align=left>Start time</th>
<th align=left>Server</th>
<th align=left>Username</th>
<th align=left>IP Address</th>
<th align=left>Process ID</th>
</tr>
EOF

foreach my $line (@loglines) {
	if (my ($prog,$ptime,$machine,$pid,$user,$ip) = $line =~ m!^(.*) at (.*) on (.*) with pid=(.*) by (.*) through IP (.*)$!) {
		print qq(<tr><td>$prog</td><td>$ptime</td><td>$machine</td><td>$user</td><td>$ip</td><td>$pid</td></tr>);
	}
}

print qq(</table>);
}

##PERLDOC##
# Function : nomercy
# Argument : NONE
# Globals  : %FORM - Uses the CGI form values to find out which processes to kill
# Returns  : NONE
# Descript : Kills processes regardless of what they are running.
# Notes    : Be careful using this function, as it kills a process regardless of what it is doing.
#            It could cause certain parts of our code to get into an odd state if killed.
##ENDPERLDOC##
sub nomercy {

	foreach (keys %FORM) {
		if (/^Kill([0-9]+)/ && $FORM{$_} eq "yes") {
			unshift(@procs, $1);
		}
	}

	unshift(@procs, split(/\D/,$FORM{"pid"})) if ($FORM{"pid"});

	# Needs pskill in the cgi-bin directory.  Should probably do error checking in the future as well.
	foreach $proc (@procs) {
		`$cgidir/pskill.exe $proc`; 
	}

#	kill 9,@procs;

	print <<EOF;
<h3> Processes @procs killed. </h3>

</body>
</html>
EOF
	exit;

}

##PERLDOC##
# Function : clearlog
# Argument : NONE
# Globals  : %FORM - Uses the CGI form values to clear the log file
# Returns  : NONE
# Descript : Rename the old log file.
##ENDPERLDOC##
sub clearlog {
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$year = $year - 100;
	$mon++;	
	$year = "0$year" if ($year <10);
	$mon = "0$mon" if ($mon < 10);
	$mday = "0$mday" if ($day <10);
	$newname = $perlproclog;
	$newname =~ s/\./_$year$mon$mday./;
	my $tempname = $newname;
	my $i = 0;
	while ( -e "$newname") {
		$newname = $tempname;
		$i++;
		$newname =~ s/\./_$i./;	
	}
	rename $perlproclog, $newname;
}