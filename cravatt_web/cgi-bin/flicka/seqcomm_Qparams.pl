#!/usr/local/bin/perl      # yo, emacs, this is in -*- Perl -*- mode

#---------------------------------------------------
#	Sequest Communicator: seqcomm_Q.params editor
#	(C)1998 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#---------------------------------------------------


################################################
# find and read in standard include file
{
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
if ($multiple_sequest_hosts) {
	require "seqcomm_include.pl";
} else {
	&MS_pages_header("SeqComm Qparams Editor", "8934FE");
	print <<EOF;
<HR><P>

<h2>Error</h2>
Your website is not using multiple Sequest hosts; you cannot use this program.
EOF
	exit;
}



&cgi_receive();

&output_form unless (defined $FORM{"edit"});

foreach $variable (keys %FORM) {
	if ($variable =~ /^(.+):(.+)$/) {
		${$1}{$2} = $FORM{$variable};
	} else {
		$$variable = $FORM{$variable};
	}
}
$Q = "off" unless ($Q);
$Q_hours = "$bHour:$bMin to $eHour:$eMin";
$db_autodownload_hours = "$dbbHour:$dbbMin to $dbeHour:$dbeMin";
$db_autodownload_nr = 0 unless ($db_autodownload_nr);
$db_autodownload_est = 0 unless ($db_autodownload_est);
$NR_cutoff--;		# this is a <= value, but is worded as a < value on the page

foreach $remserver ($ENV{'COMPUTERNAME'},@seqservers) {
#foreach $remserver (keys %num_seqs_allowed) {
	$num_seqs_allowed{$remserver} = 0 unless ($num_seqs_allowed{$remserver});
	$power{$remserver} = 0 unless ($power{$remserver});
	$seqs_allowed{$remserver} = 0 unless ($seqs_allowed{$remserver});
	$EST_server{$remserver} = 0 unless ($EST_server{$remserver});
	$NR_server{$remserver} = 0 unless ($NR_server{$remserver});
}

&MS_pages_header("SeqComm Qparams Editor", "8934FE");
print <<EOF;
<HR><P>

EOF

# edit seqcomm_Q.params
if (open(PARAMS,">$seqcommdir/seqcomm_Q.params")) {
	print PARAMS <<EOF;
#!/usr/local/bin/perl      # yo, emacs, this is in -*- Perl -*- mode

#--------------------------------------------
#	Sequest Communicator: Queue parameters
#	(C)1998 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#--------------------------------------------

# seqcomm_Q.params: this file is created and edited automatically by seqcomm_Qparams.pl

\$Q = "$Q";				# "on" if Q should run (during Q hours), "off" to sleep until further notice

EOF
	foreach $seqserver ($ENV{'COMPUTERNAME'},@seqservers) {
#	foreach $seqserver (keys %num_seqs_allowed) {
		print PARAMS "\$num_seqs_allowed{\"$seqserver\"} = $num_seqs_allowed{$seqserver};\n";
		print PARAMS "\$seqs_allowed{\"$seqserver\"} = $seqs_allowed{$seqserver};\n";
		print PARAMS "\$EST_server{\"$seqserver\"} = $EST_server{$seqserver};\n";
		print PARAMS "\$NR_server{\"$seqserver\"} = $NR_server{$seqserver};\n";
		print PARAMS "\$power{\"$seqserver\"} = $power{$seqserver};\n";
	}
print PARAMS <<EOF;

\$ESTs_allowed_ifnoNRs = $ESTs_allowed_ifnoNRs;
\$ESTs_allowed_ifNRs = $ESTs_allowed_ifNRs;
\$NR_cutoff = $NR_cutoff;

\$EST_to_NR = $EST_to_NR;

\$Q_interval = "$Q_interval";		# minutes for Q to wait between iterations

\$Q_hours = "$Q_hours";	# times for Q to start and stop paying attention
					# form must be "xx:xx to xx:xx" (24 hour time scale, midnight = 0:00)

\$db_autodownload_hours = "$db_autodownload_hours";  # times during which ftp_fastadb.pl is allowed to run (form "xx:xx to xx:xx")

\$db_autodownload_nr = "$db_autodownload_nr";		# 1 for enable autodownload, 0 for disable
\$db_autodownload_est = "$db_autodownload_est";		# 1 for enable autodownload, 0 for disable

\$db_max_age = "$db_max_age";	# the autodownload takes place when the db is more than this many days old

\$onlyQhours = "$onlyQhours";	# whether Q should pay attention only during Q_hours or always

# defaults for automatic Sequest reallow countdown
\$REALLOW_AFTER_DAY = $REALLOW_AFTER_DAY;        # produce countdown if Sequest has been disallowed on a certain machine for this many hours during the day
\$REALLOW_AFTER_NIGHT = $REALLOW_AFTER_NIGHT;    # produce countdown if Sequest has been disallowed on a certain machine for this many hours during the night
\$REALLOW_COUNTDOWN = $REALLOW_COUNTDOWN;        # countdown from this many minutes

\$minimum_power_sigcalc = $minimum_power_sigcalc;	# minimum machine strength to run significance calculation

1; # needed for Perl to consider the reading in of this file a "success"

EOF
	close PARAMS;

} else {
	print "<B>Error</B>: cannot write to seqcomm_Q.params.";
	exit;
}


print <<EOF;
<b>seqcomm_Q.params</b> has been edited.<p>
Changes will take effect at the next iteration of <b>seqcomm_Q.pl</b>.

EOF

sub output_form {

	# read in current values
	require "$seqcommdir/seqcomm_Q.params";

	$checked{"Q"} = " CHECKED" if ($Q eq "on");
	$checked{"onlyQhours"} = ($onlyQhours) ? " CHECKED" : "";
	($bHour,$bMin,$eHour,$eMin) = ($Q_hours =~ /(\d+):(\d+)\s*to\s*(\d+):(\d+)/);
	($dbbHour,$dbbMin,$dbeHour,$dbeMin) = ($db_autodownload_hours =~ /(\d+):(\d+)\s*to\s*(\d+):(\d+)/);
	$checked{"db_autodownload_nr"} = ($db_autodownload_nr) ? " CHECKED" : "";
	$checked{"db_autodownload_est"} = ($db_autodownload_est) ? " CHECKED" : "";

	$NR_cutoff++;	# this is a <= value, but is worded as a < value on the page

	foreach $remserver ($ENV{'COMPUTERNAME'},@seqservers) {
#	foreach $remserver (keys %num_seqs_allowed) {
		$checked{"seqs_allowed:$remserver"} = ($seqs_allowed{$remserver}) ? " CHECKED" : "";
		$checked{"NR_server:$remserver"} = ($NR_server{$remserver}) ? " CHECKED" : "";
		$checked{"EST_server:$remserver"} = ($EST_server{$remserver}) ? " CHECKED" : "";
	}

	&MS_pages_header("SeqComm Qparams Editor", "8934FE");
	print <<EOF;

<HR><P>

<div>
<FORM ACTION="$ourname" METHOD="post">
<input type=hidden name="edit" value=1>

Q on? <INPUT NAME="Q" TYPE=checkbox VALUE="on"$checked{"Q"}><P>

Run only during Q hours? <INPUT TYPE=checkbox NAME="onlyQhours" VALUE="1"$checked{"onlyQhours"}>
&nbsp;&nbsp;
Q hours: <INPUT NAME="bHour" VALUE="$bHour" SIZE=2 MAXLENGTH=2> : <INPUT NAME="bMin" VALUE="$bMin" SIZE=2 MAXLENGTH=2> to 
	<INPUT NAME="eHour" VALUE="$eHour" SIZE=2 MAXLENGTH=2> : <INPUT NAME="eMin" VALUE="$eMin" SIZE=2 MAXLENGTH=2><br><br>

DB Autodownload hours: <INPUT NAME="dbbHour" VALUE="$dbbHour" SIZE=2 MAXLENGTH=2> : <INPUT NAME="dbbMin" VALUE="$dbbMin" SIZE=2 MAXLENGTH=2> to
	<INPUT NAME="dbeHour" VALUE="$dbeHour" SIZE=2 MAXLENGTH=2> : <INPUT NAME="dbeMin" VALUE="$dbeMin" SIZE=2 MAXLENGTH=2>
(use 24 hour scale, midnight = 0:00)<BR><BR>

Autodownload nr? <INPUT NAME="db_autodownload_nr" TYPE=checkbox VALUE="1"$checked{"db_autodownload_nr"}><BR>
Autodownload est? <INPUT NAME="db_autodownload_est" TYPE=checkbox VALUE="1"$checked{"db_autodownload_est"}><BR><BR>

Autodownload a database when it is more than <INPUT NAME="db_max_age" VALUE="$db_max_age" SIZE=3 MAXLENGTH=3> days old<BR><BR>

Interval between iterations: <INPUT NAME="Q_interval" VALUE="$Q_interval" SIZE=3 MAXLENGTH=4> minutes<P>

<!--Number of Sequest process allowed on each computer:<BR>-->
<TABLE BORDER=2 CELLPADDING=0 CELLSPACING=0>
<TR>
	<TD><b>&nbsp;Server&nbsp;</b></TD>
	<TD><b>&nbsp;Sequest runs allowed?&nbsp;</b></TD>
	<TD><b>&nbsp;NR database?&nbsp;</TD>
	<TD><b>&nbsp;EST database?&nbsp;</TD>
	<TD><b>&nbsp;Number allowed unpaused&nbsp;</b></TD>
	<TD><b>&nbsp;<A HREF="$webincdir/Sequest%20Hosts%20CPU%20Power%20Calc.xls">Relative CPU power</A>&nbsp;</b></TD>
</TR>
EOF

#	foreach $seqserver (sort {$a cmp $b} keys %num_seqs_allowed) {
	foreach $seqserver (sort {$a cmp $b} ($ENV{'COMPUTERNAME'},@seqservers)) {
		print <<EOF;
<TR>
	<TD>&nbsp;$seqserver&nbsp;</TD>
	<TD ALIGN=CENTER><input type=checkbox name="seqs_allowed:$seqserver" value=1$checked{"seqs_allowed:$seqserver"}></TD>
	<TD ALIGN=CENTER><input type=checkbox name="NR_server:$seqserver" value=1$checked{"NR_server:$seqserver"}></TD>
	<TD ALIGN=CENTER><input type=checkbox name="EST_server:$seqserver" value=1$checked{"EST_server:$seqserver"}></TD>
	<TD ALIGN=CENTER><input name="num_seqs_allowed:$seqserver" value="$num_seqs_allowed{$seqserver}" size=2 maxlength=2></TD>
	<TD ALIGN=CENTER><input name="power:$seqserver" value="$power{$seqserver}" size=4 maxlength=4</TD>
</TR>
EOF
	}
	print <<EOF;
</TABLE>
<P>

<p>Minimum machine power to run Significance Calculation: <input name="minimum_power_sigcalc" value="$minimum_power_sigcalc" size=3></p>

Ratio <i>L<sub>EST</sub> : L<sub>NR</sub></i> = <input name="EST_to_NR" value="$EST_to_NR" size=4 maxlength=4> : 1. 
This indicates the relative weighting of EST and NR runs in computing the current load on a server.<p>

# EST runs allowed unpaused when few (&lt; <input name="NR_cutoff" value="$NR_cutoff" size=1 maxlength=2>) NRs are running: <input name="ESTs_allowed_ifnoNRs" value="$ESTs_allowed_ifnoNRs" size=2 maxlength=2><br>
# EST runs allowed unpaused when many NRs are running: <input name="ESTs_allowed_ifNRs" value="$ESTs_allowed_ifNRs" size=2 maxlength=2><br>
<p>
Produce automatic <i>Allow SEQUEST</i> countdown after <INPUT NAME="REALLOW_AFTER_DAY" VALUE="$REALLOW_AFTER_DAY" SIZE=2 MAXLENGTH=2> hour(s) during the day, or <INPUT NAME="REALLOW_AFTER_NIGHT" VALUE="$REALLOW_AFTER_NIGHT" SIZE=2 MAXLENGTH=2> during the night.<br>
Countdown from <INPUT NAME="REALLOW_COUNTDOWN" VALUE="$REALLOW_COUNTDOWN" SIZE=2 MAXLENGTH=2> minute(s) for automatic reallow.<p>

<INPUT TYPE=submit CLASS=button VALUE="Change">&nbsp;<INPUT TYPE=reset CLASS=button VALUE="Revert">
</FORM>
</div>

</BODY></HTML>
EOF

	exit;
}