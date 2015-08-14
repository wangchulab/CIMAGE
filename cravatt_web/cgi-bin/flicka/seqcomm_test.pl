#!/usr/local/bin/perl

#-------------------------------------
#	SeqComm Test,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#-------------------------------------


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
require "seqcomm_include.pl";

&MS_pages_header("SeqComm Test", "8800FF");
print "<br><hr><br><div>\n";

&cgi_receive();
$command = $FORM{"command"};
$remserver = $FORM{"remserver"};
&output_form unless ($command);

$error = &seqcomm_send($remserver,$command);
print "$remserver: $command: <span style=\"color:#FF0000\">";
if ($error) {
	print "$error";
} else {
	print "success";
}
print "</span></div>\n";

&output_form;


sub output_form {

	print "<h3>SeqComm Running?</h3><div>\n";
	foreach $remserver (@seqservers) {
		$running = (&seqcomm_remote_is_running($remserver)) ? "yes" : qq(<span style="color:#FF0000">no</span>);
		print "$remserver: $running<br>\n";
	}
	print "</div><br><br>\n";

	$command =~ s/\"/\\"/g;
	print <<EOF;

<script language="Javascript">
<!--

function fieldfocus() {
	document.forms[0].command.focus();
}

function previous() {
	document.forms[0].command.value="$command";
	fieldfocus();
}

function clearfield() {
	document.forms[0].reset();
	fieldfocus();
}

onload=fieldfocus;

//-->
</script>

<div>
<form action="$ourname" method="get">

<b>Remote server:</b> 
<span class=dropbox><select name="remserver">
EOF
	foreach $remserver (@seqservers) {
		$selected = ($remserver eq $DEFAULT_SEQSERVER) ? " selected" : "";
		print "<option$selected>$remserver";
	}
	print <<EOF;
</select><br><br>
<b>Message for seqcomm_send:</b><br>
<input name="command" size=80><br><br>
<input type=submit class=button value="Enter">&nbsp;&nbsp;<input type=button class=button value="Clear" onClick="clearfield()">&nbsp;&nbsp;<input type=button class=button value="Previous" onClick="previous()">
</form></div>
</body></html>
EOF

	exit;
}
