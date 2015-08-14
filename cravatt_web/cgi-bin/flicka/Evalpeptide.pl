#!/usr/bin/perl 

############################################################
# Eval peptide: templated on EvalocusB                     #
# changes tags for peptides in DTASelect.txt and .sqt file #
############################################################

#use diagnostics;
#use strict;
# take input from CGI call ...
my $input = $ENV{QUERY_STRING};
# remove URL-encoding (special attention to "|") ...
$input =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
# Stop people from using subshells to execute commands ...
        $input =~ s/~!/ ~!/g;
        $input =~ s/^peptide_ID=//g;
# Make data available ...
my @input = split (/\&/,$input);
chomp (@input);
my $path = $input[0];
#if ($path_plus =~ /peptide_ID=(\S+)/) {$path = $1}
my $sqt = $input[1];
my $scan = $input[2];
my $charge = $input[3];
my $peptide = $input[4];
my $evalflag = $input[5];
# construct path of DTASelect.txt in question ...
my $completepath = $path . "/DTASelect.txt";
my $completebakpath = ">" . $path . "/DTASelect.txt.bak";
my $statpreeval = -s "$completepath";

open (DTAFILE, $completepath);
my @DTAlines = <DTAFILE>;
close (DTAFILE);

my $i;
open (DTAFILEBAK, $completebakpath);
for ($i=0; $i<=$#DTAlines; $i++) {
    chomp ($DTAlines[$i]);
    $DTAlines[$i] =~ s/^(D\t$sqt\.$scan\.\d+\.$charge\t.+)[YUMN]$/$1$evalflag/;
    print DTAFILEBAK "$DTAlines[$i]\n";
}
close (DTAFILEBAK);

$completebakpath = $path . "/DTASelect.txt.bak";
my $statposteval = -s "$completebakpath";

if ($statpreeval == $statposteval) {
    print STDOUT "Content-type: text/html\n\n";
    print STDOUT "Done changing evaluation flag of $peptide to $evalflag in $completepath\n";
    rename ($completebakpath, $completepath);
} else {
    print STDOUT "Content-type: text/html\n\n";
    print STDOUT "Changing the evaluation flag of $peptide to $evalflag failed!\n";
    print STDOUT "Size of $completepath before attempt was $statpreeval\n";
    print STDOUT "Size of $completepath after attempt was $statposteval\n";
}


# construct path of .sqt file in question
my $sqtpath = $path . "/$sqt.sqt";
$statpreeval = -s "$sqtpath";
my $sqtbakpath = ">" . $path . "/$sqt.sqt.bak";

open (SQTFILE, $sqtpath);
my @sqtlines = <SQTFILE>;
close (SQTFILE);
my @sqtlinepieces;

for ($i=0; $i<=$#sqtlines; $i++) {
    chomp ($sqtlines[$i]);
    if (index($sqtlines[$i], "S") == 0) {
	@sqtlinepieces = split /\t/, $sqtlines[$i];
	if (($sqtlinepieces[1] == $scan) && ($sqtlinepieces[3] == $charge)) {
	    $i++;
	    chomp ($sqtlines[$i]);
	    while (index($sqtlines[$i], "S") != 0) {
		$sqtlines[$i] =~ s/^(M\t.+\S\.$peptide\.\S\t)[YUMN]$/$1$evalflag/;
		$i++;
		chomp ($sqtlines[$i]);
	    }
	}
    }
}

open (SQTFILEBAK, $sqtbakpath);
for ($i=0; $i<=$#sqtlines; $i++) {
    print SQTFILEBAK "$sqtlines[$i]\n";
}
close (SQTFILEBAK);

$sqtbakpath = $path . "/$sqt.sqt.bak";
$statposteval = -s "$sqtbakpath";

if ($statpreeval == $statposteval) {
    print STDOUT "and done changing flag in $sqtpath";
    rename ($sqtbakpath, $sqtpath);
} else {
    print STDOUT "Changing flag in $sqtpath failed!\n";
    print STDOUT "Size of $sqtpath before attempt was $statpreeval\n";
    print STDOUT "Size of $sqtpath after attemp was $statposteval\n";
}
