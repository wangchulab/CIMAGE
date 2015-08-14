#!/usr/local/bin/perl

#-------------------------------------
#	Update Flatfile SampleList,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# now with ALL NEW WEB WRAPPING! (-cmw,7/24/98)

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
require "flatfile_lib.pl";

##
## this is a short script to re-generate our flatfile database of directory information
##

&cgi_receive;

unless ($FORM{"proceed"}) {
	&output_form;
}

@error = &rewrite_flatfile;
if (shift @error) {
	&MS_pages_header("Update Flatfile","008000");
	print "<br><hr><br>";
	print @error;
	print "<br><br>You may want to check and make sure $SAMPLELIST is still intact.\n";
	exit;
}

# redirect browser to flatfile
&redirect($webSAMPLELIST);

exit;





sub output_form {

	&MS_pages_header("Update Flatfile","008000");


	print <<EOF;
<P><HR><P>
<div>
<FORM ACTION="$ourname" METHOD="get">
This program will delete the existing flatfile and generate a new one from information in the current directories.<br><br>
<INPUT TYPE=submit CLASS=button NAME="proceed" VALUE="Proceed">
</FORM>
</div>
EOF

	exit 0;

}
