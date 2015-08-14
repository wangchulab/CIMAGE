#!/usr/bin/perl

if ($ARGV[0] eq "") {
    print "\n\n\tERROR!  No input database specified!\n\n";
    die "\tusage:  makeIPIxENS input_uniprot.dat\n\n";
}

#$whatever 6
open (UNI, $ARGV[0]) or die "cannot open $ARGV[0]";
@uni = <UNI>;
close UNI;

for ($i = 0; $i < scalar @uni; ++$i) {
#    print "$i\n";

    if ($uni[$i] =~ /^ID\s+(\S+)/) {

	$curipi = $1;

	@curentry = ();
	$curseq = "";
	$curens = "";
	while ($uni[$i] !~ /^\/\//) {
	    if ($uni[$i] =~ /(ENSGALG\d+)/) {
		$curens = $1;
	    }
	    $curseq .= $uni[$i] if ($uni[$i] =~ /^\s/);
	    ++$i;
	}
	$curseq =~ s/\s+//g;
	$curseq =~ s/\n+//g;
#	print ">$curipi\t$curens\n$curseq\n";
	$ipixens{$curens} = $curseq if (length($curseq) > length($ipixens{$curens}));
    }

}

    print scalar (keys %ipixens) . " ensebml entries\n\n";


