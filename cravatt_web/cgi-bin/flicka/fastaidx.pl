#!/usr/local/bin/perl

#-------------------------------------
#	FastaIdx,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. Baker/T. Kim
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
require "fastaidx_lib.pl";

sub menu {
    print "fasta db indexing menu\n";
    print "c) create an index from a .fasta db\n";
    print "o) open an index on a .fasta db\n";
    print "g) get a description by id (key)\n";
    print "p) get a protein by id (key)\n";
    print "q) quit\n";
}

sub main {
    my($quit, $line, $dbfile, $idxname, $id, $filepos, $numlines, $descrip);
    my($temp);  # used for efficiency, so we use %IDIDX minimal times

    menu();

    $quit=0;
    while (!$quit) {
	print "command: ";
	chop($line=<STDIN>);
	if ($line eq "c") {
	    print "fasta filename: ";
	    chop($dbfile=<STDIN>);
	    createidx($dbfile) ? print "Successful.\n" : print "Unsuccessful.\n";
	} elsif ($line eq "o") {
	    print "idx name: ";
	    chop($idxname=<STDIN>);
	    openidx($idxname) ? print "Successful.\n" : print "Could not open $idxname\n";
	} elsif ($line eq "g") {
	    print "id: ";
	    chomp($id=<STDIN>);
	    if ($descrip=lookupdesc(parseentryid($id))) {
		print $descrip;
	    } else {
		print "$id does not seem to be in our index\n";
	    }
	} elsif ($line eq "p") {
	    print "id: ";
	    chomp($id=<STDIN>);
	    @seq=lookupseq(parseentryid($id));
	    if (@seq) {
		print (join "\n", @seq);
		print "\n";
	    } else {
		print "$id does not seem to be in our index\n";
	    }
	} elsif ($line eq "q") {
	    $quit=1;
	} else {
	    menu();
	}
    }

    closeidx();
}

if ($#ARGV>=0) {
    createidx($ARGV[0]);
} else {
    main();
}
