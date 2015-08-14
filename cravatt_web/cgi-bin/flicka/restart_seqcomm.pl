#!/usr/local/bin/perl

# ==========================================================
# Project       : Restart SeqComm
# Description   : a simple utility to restart various Sequest Communicator and/or seqcomm_Q processes
# Includes      : 
# Requires      : microchem_include.pl, seqcomm_include.pl
# Authors       : C. M. Wendl
# Date Created  : 3/11/99
# Version       : v3.1a
# Copyright     : (C)1999 Harvard University
# Comments      : this will only work when SeqComm is running on all the relevant machines
# ==========================================================



#####################################
# 0. Description
#
# Simply put, this script sends a message to SeqComm, by typical SeqComm means,
# telling it that it should restart itself.  It can also restart seqcomm_Q.pl,
# or relay a restart message to a remote seqcomm_slave.pl process.
# Very convenient for when changes in SeqComm are being made, and we want to be
# able to bring those changes into effect quickly, without touching the taskbar.
#

#####################################
# 0.5. Require'd and use'd files
#

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
### Additional includes go here
require "seqcomm_include.pl";

#######################################
# 1. Fetching data
#

&cgi_receive;

&MS_pages_header("Restart SeqComm", "8800FF");
print "<HR><BR>\n";

&output_form unless (defined $FORM{"do"});
delete $FORM{"do"};

print "<p>Sending messages to seqcomm_master.pl:</p><tt>\n";

@errors = ();
foreach (keys %FORM) {

	($remserver,$msg) = split /\.\.\./;

	$error = &seqcomm_send($remserver,$msg);
	if ($error) {
		print "$remserver: $msg: $error<br>\n";
	} else {
		print "$remserver: $msg: success<br>\n";
	}

}

print "</tt></body></html>";

exit;

sub output_form {

	print <<EOF;


<div>
<span style="color:#FF0000">Note: this program will only work if Sequest Communicator is already running on the chosen machines.</span><p>

<form action="$ourname" method="get">

<!--
<input type=checkbox name="restart_seqcomm" value=1> Restart Q and SeqComm on $ENV{'COMPUTERNAME'}<br>
<input type=checkbox name="restart_Q" value=1> Restart Q (without restarting SeqComm)<p>
//-->
EOF

	foreach $remserver (@seqservers) {
		print <<EOF
<input type=checkbox name="$remserver...restart_seqcomm" value=1> Restart SeqComm on $remserver<br>
EOF
	}

	print <<EOF;
<p>
<input type=submit class=button name="do" value=" Do ">
</form>

</div>
</body></html>
EOF

	exit();

}
