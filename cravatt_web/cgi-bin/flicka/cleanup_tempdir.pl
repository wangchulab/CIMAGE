#!/usr/local/bin/perl
#-------------------------------------
#	Cleanup TempDir,
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
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
$DEFAULT_DAYS = 2;

$cmdline = grep /^-c/, @ARGV;

if ($cmdline) {

	@days = grep /^-d/, @ARGV;
	$days = (@days ? substr($days[0],2) : $DEFAULT_DAYS);
	&do_delete;
	exit 0;

} else {

	&cgi_receive;
	&output_form if (!defined $FORM{"days"});
	$days = $FORM{"days"};
	&do_delete;

	MS_pages_header("Cleanup TempDir", "FF3300");
	print <<EOF;
<P><HR><P>
<a href="$webtempdir">$tempdir</a> has been cleaned.

</body></html>
EOF

	exit 0;

}

sub do_delete {

	chdir "$tempdir";

	opendir(TEMP,".");
	while($file = readdir(TEMP)) {
		foreach $ext (@extensions_to_delete) {
			unlink $file if ( ($file =~ /\.$ext$/) && ((-A "$file") > $days) );
		}
	}
	close(TEMP);

	open(STAMP,">stamp");
	close(STAMP);

	open(LOG,">>cleanup.log");
	print LOG localtime() . ": tempdir cleaned\n";
	close(LOG);

}


sub output_form {

	MS_pages_header("Cleanup TempDir", "FF3300");

	@exts = @extensions_to_delete;
	foreach $ext (@exts) {
		$ext =~ tr/a-z/A-Z/;
	}
	$last = pop(@exts);
	$exts = $last;
	$exts = join(", ",@exts) . " and " . $exts if (@exts);

	print <<EOF;
<P><HR><P>

<div>
<FORM ACTION="$ourname" METHOD=get>
Delete all $exts files in <a href="$webtempdir">$tempdir</a> older than
<INPUT NAME="days" VALUE="$DEFAULT_DAYS" SIZE=2 MAXLENGTH=2> days? <P>
<INPUT TYPE=submit CLASS=button VALUE="Proceed"></FORM>
</div>


</body></html>
EOF

	exit 0;

}


sub error {

	MS_pages_header("Cleanup TempDir", "FF3300");
	print <<EOF;
<P><HR><P>

<H2>Error:</H2>
<div>
@_
</div>
</body></html>
EOF

	exit 0;

}