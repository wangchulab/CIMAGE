#!/usr/local/bin/perl

#-------------------------------------
#	Sequence Lookup,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/T. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# 11/19/78 Lea - added note at the bottom of page and link
#					to FastaIdx
# 08/01/00 Peter changed Lea's comment so people would know what she was talking about
# 08/02/00 11:42 AM, Ben added Peter's comment
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
require "fastaidx_lib.pl";

&cgi_receive();

unless ($FORM{"running"}) {
	&output_form;
	exit 0;
}

#print "Content-type:  text/html\n\n";
#print "<html>\n";

# changed by Martin:
#&MS_pages_header ("Sequence Lookup Results", 0 , "Sequence Lookup Results");
&MS_pages_header ("Sequence Lookup Results");

$database=$FORM{'Database'};
$seqid=$FORM{'seqid'};

$database=~s/\.fasta//g;
$seqid=parseentryid($seqid);

chdir($dbdir);

if (!openidx("$dbdir/$database")) {
	&error("cannot open index for database $database");
	exit 1;
} else {
	(@seq)=lookupseq($seqid);

	print "<P><b>Database</b> = <i>$database</i>, <b>Sequence Id</b> = <i>$seqid</i>\n<hr>";

	if (@seq==()) {
		print "Sequence id <i>$seqid</i> not found in <i>$database</i>.";
	} else {
	      foreach $line (@seq) {
	        print "<BR><tt>$line</tt>\n";
	      }
	}
}

&closeidx();

print "</html>";


sub output_form
{

&MS_pages_header("Sequence Lookup", "FF0080");

print <<EOF;

<HR WIDTH="100%"><BR>
<P>


<FORM method="GET" action="$ourname">
<INPUT TYPE=hidden NAME="running" VALUE="ja">

<TABLE BORDER=0>
<TR VALIGN=TOP>
<td><b>* Database:</b></td>
<td>
EOF

&get_dbases;

# make dropbox:
my @indexed_db_names = &get_indexed_dbs (@ordered_db_names);
&make_dropbox ("Database", $DEFAULT_DB, @indexed_db_names);

print <<EOF;
</td>
</tr>

<tr>
<td><b>Id:</b></td>
<td><INPUT type="text" name="seqid"></td>
<tr>
<td><br><br><input type="submit" class=button value="Start Search"></td>
</tr>
</table>

<br>
<br>
<div style = "color:#000000"> 
* Databases must be <a href="$webcgi/fastaidx_web.pl">indexed</a> to lookup a sequence.
<br>Go to <a href="$webcgi/fastaidx_web.pl">FastaIdx</a>.

</div>
<UL>
<P></FORM></P>
</UL>

</BODY>
</HTML>

EOF

}


sub error {

	print "<p><div>\n";
	print join("<p>",@_);
	print "</div>\n";
	exit;

}