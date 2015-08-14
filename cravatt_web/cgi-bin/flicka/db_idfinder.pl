#!/usr/local/bin/perl
#-------------------------------------
#	Database Id Finder,
#	(C)2001 Harvard University
#	
#	L. Bergstrom, Robert Yumol
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# rigorous variable checking at compile time
use strict;
use vars qw(%FORM %DEFS_DTACAL $webseqdir $webjsdir $webimagedir $seqdir $dbdir);
use vars qw($ourname $ourshortname @ordered_db_names @dbases $retrieve @outs $pull_to_top);

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

require "fasta_table_include.pl";		# contains code for expandcollapse table and ref mouseovers

&cgi_receive();
&MS_pages_header ("Database Id Search Results", "#800080");

unless ($FORM{"running"}) {
	&output_form;
	exit 0;
}

print <<EOF;
<HR WIDTH="100%"><BR>
<P>
EOF

my $database = $FORM{'Database'};
my $sorttype = $FORM{'sort'};

# trap for large database 
chdir($dbdir);
my $size = -s "$dbdir/$database";
if ($size > (5000*1024)) {
	print "<p><b>Database is over 5000KB; aborting search.</b><p>";
	print "</html>";
	exit;
}

# otherwise continue
require "fastaidx_lib.pl";
&get_dbases;
my @indexed_db_names = &get_indexed_dbs (@ordered_db_names);
my $indexed = grep /$database/, @indexed_db_names;
unless (-e "$dbdir/$database") { print "The database $database could not be found."; exit 1; }

my $add_hidden_fields =<<FIELDS;
	<input type=hidden name="running" value="1">
	<input type=hidden name="Db" value="$database">
	<input type=hidden name="NucDb" value="">
	<input type=hidden name="MassType" value="">
	<input type=hidden name="Dir" value="">
	<input type=hidden name="Ref" value="">
	<input type=hidden name="Pep" value="">
	<input type=hidden name="mode" value="">
FIELDS

&loadJavascript($database);

###################################
## get the sequences to display
my @seqsf = &getSortedSeqs($database, $sorttype, $indexed);

###################################
## display the sequences
print "<table border=0 width=100% cellspacing=0 cellpadding=2><tr><td valign=top><b>Database:</b> $database<p><td><td>&nbsp;</td>";
unless ($indexed) {
	print "<td valign=top>This database is not indexed.  To index it and enable sequence lookup, click <a href='fastaidx_web.pl?selected=$database' target=new>here.</a.</td>";
}
print "</tr></table>";

&makeExpandCollapseTable(\@seqsf, $database, $indexed, undef, $add_hidden_fields);

print "</body></html>"; exit;				# finish the page

########################
## the initial form
sub output_form
{

#&MS_pages_header("Database Id Finder", "#800080");

print <<EOF;

<HR WIDTH="100%"><BR>
<P>


<FORM method="GET" action="$ourname">
<INPUT TYPE=hidden NAME="running" VALUE="true">

<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=2>
<TR>
<td><b>Database:</b></td>
<td>
EOF

&get_dbases;

&make_dropbox ("Database", "", @dbases);
print <<EOF;
</TD></TR>
<tr><td></td><td><span class="smalltext">Search will be aborted if database is larger than 5000kb.</span></td></tr>
<tr><td></td>
	<td><br><input type="submit" class=button value="List Sequences">
	&nbsp;&nbsp;<a class="smallheading" href="/help/help_$ourshortname.html" target="new">Help</a></td>
</tr>
</table>
<br>
<br>
<UL>
<P></FORM></P>
</UL>

</BODY>
</HTML>
EOF

}

##PERLDOC##
# Function : getSortedSeqs
# Argument : $database = "FASTA database name"
# Argument : $sorttype = 'id' | 'desc' | 'seq'		attribute to sort data on
# Argument : $indexed = "FASTA database name" | ""
# Globals  : $dbdir 
# Returns  : array of arrays [$id, $desc, $seq] = [FASTA id, description header, start of sequence (40 chars)] for all IDs in database
# Descript : This function takes a chosen FASTA database and retrieves the description header (and sequence if indexed) for all IDs in db 
# Notes    : need to require "fastaidx_lib.pl"
##ENDPERLDOC##
sub getSortedSeqs {
	my ($database, $sorttype, $indexed) = @_;
	open(DBFILE, "$dbdir/$database");
	my @seqs;
	while (my $line = <DBFILE>) {
		if ($line =~ /^\>/) {
			$line =~ s/^\>//;		# chop leading >
			my ($id, $desc) = split(' ', $line, 2);
			if (length($id) > 15) { # limit length of id to 15 chars
				$id = substr($id, 0, 15);  
			}
			my $myref = &parseentryid($id);
			my @seq = ();
			if ($indexed) {
				openidx($database);
				@seq = &lookupseq($myref);
				closeidx();
			} else { @seq = &search_unindexed_db($database,$myref); }
			shift @seq;
			my $seq = join ("", @seq);
			my $seq_len = length($seq);
			my $formatted_seq = "";
			$seq = substr($seq, 0, 40);						# limit length of seq to 40 chars
			if ($seq_len > 0) {								# do formatting if non-empty string
				$formatted_seq = ($seq_len > 22) ? substr($seq, 0, 22) . "<BR>" . substr($seq, 22, 18) : $seq;
				if($seq_len > 40) { $formatted_seq .= "..."; }
				$seq = $formatted_seq;
			} else { $seq = "(N/A)"; }
			if (length($desc) == 0) { $desc = "(N/A)"; }	# trap for empty desc
			push(@seqs, [$id, $desc, $seq]);
		}
	}

	my @seqsf;
	if ($sorttype eq 'id') {
		@seqsf = sort { lc($a->[0]) cmp lc($b->[0]) } @seqs;
	} elsif ($sorttype eq 'desc') {
		@seqsf = sort { lc($a->[1]) cmp lc($b->[1]) } @seqs;
	} elsif ($sorttype eq 'seq') {
		@seqsf = sort { $a->[2] cmp $b->[2] } @seqs;
	} else {
		@seqsf = @seqs;
	}
	return @seqsf;
}

sub error {

	print "<p><div>\n";
	print join("<p>",@_);
	print "</div>\n";
	exit;

}