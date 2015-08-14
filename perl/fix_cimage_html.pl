#!/usr/bin/perl

###############################################################################################
#
#    fix cimage output html by updating file locations when they are moved.
#
################################################################################################


$dset = $ARGV[0]; # input is the full file name of comb*.html
$html = "$dset.html";
$text = "$dset.txt";
open (DSET, $html) or die "cannot open cimage output table $! -- $html";
my @dsettable;
@dsettable = <DSET>;
close DSET;

################# parse the header line #############################
$old_dset = $dsettable[1]; # always the second line in html
chomp($old_dset);

open (DSET, ">$html") or die "cannot write to cimage output table $! -- $html";
foreach (@dsettable) {
    if (/$old_dset/) {
	$_ =~ s/$old_dset/$text/g;
	print DSET "$_";
    } else {
	print DSET $_;
    }
}
