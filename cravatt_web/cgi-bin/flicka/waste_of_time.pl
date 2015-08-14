#!/usr/local/bin/perl

#-------------------------------------
#	Waste of Time,
#	(C)1999-2002 Harvard University
#	
#	W. S. Lane/Unknown)
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
}
################################################
### Additional includes go here
require "seqcomm_include.pl";
&cgi_receive;

&MS_pages_header("Ridiculous Waste of Time", "8800FF");
print "<HR><BR>\n";

select(STDOUT);
$| = 1;

$message = $FORM{"message"};
$machine = $FORM{"machine"};
$signature = $FORM{"signature"};
$machine = uc($machine);

&output_form unless (defined $FORM{"message"});

$message .= "\n    -- $signature \@ $ENV{'REMOTE_HOST'}";
$message =~ s/"/\\"/gs;

print "<pre>\n";
$cmdline = "net send $machine \"$message\"";
system("$cmdline");
print "</pre></body></html>";

exit;



sub output_form {

	print <<EOF;

<div>
<form action="$ourname" method="post">
<span style="color:#FF0000">Note: you can send messages from any computer, but the recipient must be running Windows NT.  Try to avoid using double quotes.</span><br><br>

Message recipient (computer name): <input name="machine" size=10><br><br>

Message: <br>
<tt><textarea name="message" wrap=virtual cols=40 rows=5></textarea></tt><br><br>

Signature: <input name="signature" size=12><p>

<input type=submit class=button value="Send">

</form>
</div>

</body></html>
EOF

	exit;

}
