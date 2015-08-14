#!/usr/bin/perl

print "Content-type: text/html\n\n";

open (HAN, 'human_annotated.txt') or die "Cannot open annotation";
@han = <HAN>;
close HAN;

$uniprotfile = '/home/gabriels/public_html/uniprot_sprot_HUMAN.dat';

open (UNI, $uniprotfile);
@uni = <UNI>;
close UNI;


############## load uniprot data #############################

for ($i = 0; $i < scalar @uni; ++$i) {
    
    if ($uni[$i] =~ /^ID\s+(\S+)/) {
	@names = ();
	@curaccs = ();
	$accstring = "";
	$curentry = $uni[$i];
	while ($uni[$i] !~ /^\/\//) {
	    if ($uni[$i] =~ /^AC   (.*)$/) {
		$accstring .= $1;
	    }
	    if ($uni[$i] =~ /^DE/) {
		if ($uni[$i] =~ /Full=([^\;]*)\;/) {
		    push (@names, $1) if ($1 !~ /^Protein/);
		} elsif ($uni[$i] =~ /Short=([^\;]*)\;/) {
		    push (@names, $1) if ($1 !~ /^Protein/);
		}
	    }

	    if ($uni[$i] =~ /^GN/) {
		if ($uni[$i] =~ /Name=([^\;]*)\;/) {
		    push (@names, $1) if ($1 !~ /^Protein/);
		} 
		if ($uni[$i] =~ /Synonyms=([^\;]*)\;/) {
		    push (@names, $1) if ($1 !~ /^Protein/);
		}
	    }


	    $curentry .= $uni[$i];
	    ++$i;
	}
	
    }

    $accstring =~ s/\n//g;
    $accstring =~ s/\s+//g;
    @curaccs = split(/\;/,$accstring);



    foreach (@curaccs) {
	$unihash{$_} = $curentry;
	@{$altnames{$_}} = @names;
    }


}

##############################################################



print "<TABLE BORDER=1>\n";

foreach (@han) {
    @currow = split(/\t/,$_);
    print "<TR>\n";
    foreach (@currow) {
	print "\t<TD>$_</TD>\n";
    }
    $curuni = $currow[3];
    print "\t<TD>";
    $namestring = "";
    foreach (@{$altnames{$curuni}}) {
	$namestring .= "%22$_%22%20OR";
#	print "$_<BR>";
    }

    chop $namestring;
    chop $namestring;
    chop $namestring;
    chop $namestring;
    chop $namestring;
#    print "($namestring) AND pka";

    print '<A HREF="http://www.ncbi.nlm.nih.gov/sites/entrez?cmd=search&db=pubmed&term=' . "($namestring) AND pKa AND (cysteine OR thiol)\"" . ' TARGET="_blank">pKa</A>';

    print "</TD>\n";
    print "</TR>\n";
    
}

print "</TABLE>\n";








print "end";
