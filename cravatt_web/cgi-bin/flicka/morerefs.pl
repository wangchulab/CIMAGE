#!/usr/local/bin/perl
#-------------------------------------
#	Morerefs,
#	(C)2001 Harvard University
#	
#	Georgi Matev
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

require "fasta_table_include.pl";			# contains code for expandcollapse table and ref mouseovers

&cgi_receive();

&MS_pages_header ("Morerefs", "#800080");
print "<hr><div>";

my $file = $FORM{"OutFile"};
my $baseref = $FORM{"Ref"};
my $peptide = $FORM{"Peptide"};

#for now this program will not be called on its own
if (!$file || !$baseref) {
	error("This program is only meant to be called through other programs.");
}

my $sorttype = $FORM{'sort'};



###################################
## get the sequences to display
my ($seqsfR, $database, $indexed) = &getSortedRefs($file, $sorttype, $baseref);
my @seqsf = @$seqsfR;

&loadJavascript($database);

###################################
## display the sequences
print "<span class=smallheading>Database:</span>&nbsp; $database<br><br>\n";
unless ($indexed) {
	print "This database is not indexed.  To index it and enable sequence lookup, click <a href='fastaidx_web.pl?selected=$database' target=new>here</a>.<br><br>";
}

my $add_hidden_fields =<<FIELDS;
	<input type=hidden name="Ref" value="$baseref">
	<input type=hidden name="Db" value="$database">
	<input type=hidden name="NucDb" value="">
	<input type=hidden name="MassType" value="">
	<input type=hidden name="Dir" value="">
	<input type=hidden name="OutFile" value="$file">
	<input type=hidden name="Pep" value="">
FIELDS

#convert the partial peptide sequence that matched in a convenient form
$peptide=~ s/^\(.\)//gi;

&makeExpandCollapseTable(\@seqsf, $database, $indexed, $peptide, $add_hidden_fields);

print "</div></body></html>"; 

exit(0);				# finish the page

##PERLDOC##
# Function : getSortedRefss
# Argument : $baseref     The base reference for which we are retreiving additional reference info
# Argument : $sorttype = 'id' | 'desc' | 'seq'		attribute to sort data on
# Globals  : $dbdir 
# Returns  : array of arrays [$id, $desc, $seq] = [FASTA id, description header, start of sequence (40 chars)] for all IDs in database
# Descript : This function takes a chosen FASTA database and retrieves the description header (and sequence if indexed) for all IDs in db 
# Notes    : need to require "fastaidx_lib.pl"
##ENDPERLDOC##
sub getSortedRefs {
	my ($file, $sorttype, $baseref) = @_;
	my @refs_info=();
	my @refs=();
	my $line;

	open (OUTFILE, $file) || error ("Could not open $file");

	my $database;
	# extract header information
	while ($line = <OUTFILE>) {
		#SDR: Added [dD] because a \Database was not working while a \database dir
		if ($line =~ /.[dD]atabase./i)    {
			my $begin;
			($begin, $database) = split /[dD]atabase\S/, $line; 
			$database =~ s/\.fasta.*$/\.fasta/;
		}

		last if ($line =~ /.deltCn./);
	}

	my $foundref = 0;

	# main while loop; reads each line and extracts the relevant additional reference information
	while ($line = <OUTFILE>) {
		

		# matches those lines which contain base refs   
		if ($line =~ /.\s{1,}(\d+\/\s*\d+)\s+\S+\s+./) { 
			my $ion = $1;   # 23/34
			
			last if ($foundref == 1);		
			
			# begin == non hyperlink stuff
			# end == hyperlink stuff plus sequence
			# so, now we have to split the end portion.
		   
			my ($begin, $end) = split $ion, $line;
			$begin =~ s/[ \t]+$//gm;
			$end =~ s/^[ \t]+//gm;
			   
			my ($fileref, $blast, $peptide) = split /\s+/, $end;
			splice @refs, 0;
			push @refs, $fileref;	
			#we are only interested in the one baseref that got passed in
			if (substr($fileref, 0, length($baseref)) eq $baseref) {
				#quit after the ref we are looking for is found
				#we got the reference we want
				$foundref = 1;		
			}
		#matches additional ref lines 
		} elsif ($line =~ /^\s+[0-9]+\s+(\S+)/) {			
				push @refs, $1;
				if (substr($1, 0, length($baseref)) eq $baseref) {
				$foundref = 1;
			}
		}	
	}

	close(OUTFILE);

	require "fastaidx_lib.pl";
	&get_dbases;
	my @indexed_db_names = &get_indexed_dbs (@ordered_db_names);
	my $indexed = grep /$database/, @indexed_db_names;
	$database =~ s/^\s*(\S+)\s*$/$1/;
	unless (-e "$dbdir/$database") { print "The database $database could not be found."; exit 1;}

	#now get the rest of the info for the references
	if ($foundref) {
		foreach (@refs) {
			my $myref = &parseentryid($_);
			my @seq = ();
			my $desc;

			if ($indexed) {
				openidx("$dbdir/$database");
				@seq = &lookupseq($myref);
				closeidx();
			} else { 
				@seq = &search_unindexed_db("$dbdir/$database",$myref); 
			}

			$desc = shift @seq;
			#eliminate possibly leading >
			$desc=~ s/^>//;


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
				push(@refs_info, [$myref, $desc, $seq]);
		}
	}
	
	my @refsf;
	if ($sorttype eq 'id') {
		@refsf = sort { lc($a->[0]) cmp lc($b->[0]) } @refs_info;
	} elsif ($sorttype eq 'desc') {
		@refsf = sort { lc($a->[1]) cmp lc($b->[1]) } @refs_info;
	} elsif ($sorttype eq 'seq') {
		@refsf = sort { $a->[2] cmp $b->[2] } @refs_info;
	} else {
		@refsf = @refs_info;
	}

	return (\@refsf, $database, $indexed);
}

sub error {

	print "<p><div>\n";
	print join("<p>",@_);
	print "</div>\n";
	exit;

}
