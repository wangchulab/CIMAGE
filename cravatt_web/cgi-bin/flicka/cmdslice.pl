#!/usr/local/bin/perl

#-------------------------------------
#	CmdSlice (Command Line Db Slice),
#	(C)1997-2002 Harvard University
#	
#	W. S. Lane/T. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# find and read in standard include file
{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################

($source, $name, $append, $contaminants, $autoindex, $logic1, $search1, $logic2, $search2, $logic3, $search3) = @ARGV;

print "$ourname\nSource=$source\nName=$name\nAppend=$append\nContaminants=$contaminants\nAutoindex=$autoindex\n";
print "logic1=$logic1\nsearch1=$search1\nlogic2=$logic2\nsearch2=$search2\n";

$starttime = time;

$i=0;
if ($search1) {    
    $search[$i]->{'logic'}=$logic1;
    $search[$i]->{'match'}=$search1;
    $i++;
}
if ($search2) {
    $search[$i]->{'logic'}=$logic2;
    $search[$i]->{'match'}=$search2;
    $i++;
}
if ($search3) {
    $search[$i]->{'logic'}=$logic3;
    $search[$i]->{'match'}=$search3;
}

if ($append) {
    $openmethod = ">>";
} else {
    $openmethod = ">";
}

if (!open(SRC, "$dbdir/$source")) {
	exit;
}

# This opens the output database and will either append or overwrite it with
# the lines in the source database that match the pattern.
if (!open (FASTA, $openmethod . "$dbdir/$name")) {
	die;
}

# MAIN ACTION
my($done) = 0;
my($goodid) = 0;
my($num) = 0;
while ( (!$done) ) {
	if (!($line = <SRC>)) {
		$done = 1;
    }
    $a = substr($line, 0, 1);
    if (($a eq ">") || $done) {
		# write out last id if good
		#	if ($id =~ /$search/i) {
		if (&complexsearch($id, \@search)) {
		    $num++;
			print FASTA $id;
			print FASTA @seq;
			print ".";
		}
		# set up next
		$id = $line;
		@seq = ();
    } else {
		push(@seq, $line);
    }
}
close SRC;

print "\n";

# If contaminants is anything but no, include the contaminants.fasta database
# at the end of the output database.
# SDR(08/22/01) contaminants.fasta should not really be an argument to this, as it
#	may not always be the database to include.  $contaminants is the name of the included database though :)
if ($contaminants) {
	#if (open(CONT, "$dbdir/contaminants.fasta")) {
	if (open(CONT, "$dbdir/$contaminants")) {
		while (<CONT>) {
			print FASTA $_;
			print ".";
		}
		close CONT;
    }
}    

close FASTA;
print "\n";

$endtime = time;

print "Started at " . localtime($starttime) . ".\nEnded at " . localtime($endtime) . ".\n";

exit;

sub complexsearch {
    my($string, $searchthing) = @_;
    my(@search) = @{$searchthing};

    # @search should be an array of records
    # $search[i]->{'logic'} = "OR" or "AND",
    # $search[i]->{'match'} = search string

    # how we do it
    # LOOP:  while AND, keep 0 after a test fails
    # on OR, quit with 1 if 1, else continue LOOP
    # on END, quit with whatever we have

    $tmp = 1;
    foreach $thing (@search) {
		%rec = %$thing;
		if ($rec{'logic'} eq "AND") {	    
		    $tmp = $tmp && ($string =~ /$rec{'match'}/i);
		} elsif ($rec{'logic'} eq "OR") {
		    if ($tmp) { return 1; }
			$tmp = ($string =~ /$rec{'match'}/i);
		} elsif ($rec{'logic'} eq "NOT") {
		    $tmp = ($tmp) && ($string !~ /$rec{'match'}/i);
		}
    }
	return $tmp;
}

1;