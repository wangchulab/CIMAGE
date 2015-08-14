#!/usr/bin/perl

use CGI;
#use LWP::Simple;

$q = new CGI;

$uniprotfile = '/home/gabriels/public_html/uniprot_sprot_HUMAN_IDACFTSQ.dat';

open (UNI, $uniprotfile) or die "er3";
@uni = <UNI>;
close UNI;


############## load uniprot data #############################

for ($i = 0; $i < scalar @uni; ++$i) {

    
    if ($uni[$i] =~ /^ID\s+(\S+)/) {
	@curaccs = ();
	$accstring = "";
	$curentry = $uni[$i];
	while ($uni[$i] !~ /^\/\//) {
	    if ($uni[$i] =~ /^AC   (.*)$/) {
		$accstring .= $1;
	    }
	    $curentry .= $uni[$i];
	    ++$i;
	}
	
    }

    $accstring =~ s/\n//g;
    $accstring =~ s/\s+//g;
    @curaccs = split(/\;/,$accstring);

#    foreach (@curaccs) {
	$unihash{$curaccs[0]} = $curentry;
#    }


}


@hashsorter = sort {$a <=> $b} keys %unihash;

##############################################################






print "Content-type: text/html\n\n";
print "<HTML><HEAD><TITLE>Cystome annotate</TITLE></HEAD><BODY>\n";
#print "<A HREF=\"batch_annotate.pl?dset=$dset231\">231</A> <A HREF=\"batch_annotate.pl?dset=$dsetmcf7\">mcf7</A> <A HREF=\"batch_annotate.pl?dset=$bothdsets\">231 + mcf7</A><P>\n";
#print "<A HREF=\"$htmllink\">click here to see chromatographs</A>\n";
#print "<H3>cystomation</H3>\n";
#print "<HR>\n";

#print "<B>Proteome size: </B>" . scalar (keys %unihash) . "<P>\n";

print "<TABLE BORDER=1>\n";

for ($i = 0; $i < scalar @hashsorter; ++$i) {
#for ($i = 0; $i < 1000; ++$i) {
    $curuni = $hashsorter[$i];

    print "<TR>\n";
    print "<TD>" . ($i+ 1) . "</TD>\n";


    $dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$curuni&format=default&style=default&Retrieve=Retrieve";

    print "<TD><A HREF=\"$dbfetchlink\" TARGET=\"_blank\">$curuni</A></TD>\n";


    $curunidata = $unihash{$hashsorter[$i]};
    @uni = split(/\n/,$curunidata);
    
    $curuniseq = "";
    foreach (@uni) {
	$curuniseq .= $_ if ($_ =~ /^\s+/);
    }
    $curuniseq =~ s/\n//g;
    $curuniseq =~ s/\s+//g;

    @seqarray = split(//,$curuniseq);
    $ccount = 0;
    $curpos = 0;
    $fnres = 0;
    foreach (@seqarray) {
	++$curpos;
	$exactstring = "";
	if ($_ eq 'C') {
	    ++$ccount;
	    ++$tolccount;
	    $resfunctional = 0;
	    foreach (@uni) {

		if ($_ =~ /^FT   (\S+)\s+(\d+)\s+(\d+)(.*)/) {

		    ($type, $p1, $p2) = ($1, $2, $3);
		    $type .= " $4";


		    if ($type =~ /^DISULFI(.*)/) {
			$restofstring = $1;
			if ($restofstring =~ /Redox/) {
			    $typetocount = "DISULFID Redox-active";
			} else {
			    $typetocount = "DISULFID Other";
			}
		    } else {
			$type =~ /(\S+)/;
			$typetocount = $1;
		    }



		    if (($p1 == $p2) && ( $p1 == $curpos ) &&  ($type !~ /MUTAGEN.*No effect/g) ){

			$resfunctional = 1;
			$exactstring .= "$type, ";
			++$typecounter{$typetocount};
		    } 
		    if (($p1 != $p2) && ( ($p1 == $curpos) || ($p2 == $curpos) ) )  {
			if ($type =~ /DISULFID/) {
			    $exactstring .= "$type, ";
#			    ++$fnres;
			    $resfunctional = 1;
			    ++$typecounter{$typetocount};
			}
		    }
		}
	    }

	    chop $exactstring;
	    chop $exactstring;
	    ++$fnres if ($resfunctional == 1);
	    ++$functioncounter{$exactstring};

	}
    }

    if ($ccount > 0) {
	$fncperc = $fnres / $ccount;
    } else {
	$fncperc = "";
    }

    print "<TD>" . length($curuniseq)  . "</TD>\n";
    print "<TD>$ccount</TD>\n";
    print "<TD>$fnres</TD>\n";
    print "<TD>$fncperc</TD>\n";

    print "</TR>\n";



}

print "</TABLE>\n";

@fnsorted = sort {$functioncounter{$a} <=> $functioncounter{$b}} keys %functioncounter;
@typesorted = sort {$typecounter{$a} <=> $typecounter{$b}} keys %typecounter;

print "<TABLE BORDER=1>\n";

for ($i = 0; $i < scalar @fnsorted; ++$i) {

    print "<TR>\n";
    print "<TD>$functioncounter{$fnsorted[$i]}</TD><TD>$fnsorted[$i]</TD>\n";
    print "</TR>\n";

}

print "</TABLE>\n";


print "<TABLE BORDER=1>\n";

for ($i = 0; $i < scalar @typesorted; ++$i) {

    print "<TR>\n";
    print "<TD>$typecounter{$typesorted[$i]}</TD><TD>$typesorted[$i]</TD>\n";
    print "</TR>\n";

}

print "</TABLE>\n";
print "<H3>total cysteines: $tolccount</H3>\n";
