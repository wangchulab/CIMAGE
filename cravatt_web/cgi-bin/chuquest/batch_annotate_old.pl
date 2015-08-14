#!/usr/bin/perl

use CGI;
#use LWP::Simple;

$q = new CGI;

#$dset = $q->param('dset');

$dset = '/home/chuwang/public_html/from_DTASelect/231/231_combined.txt';
$scmin = $q->param('scmin');
$xreffile = '/home/gabriels/public_html/ipi.genes.HUMAN.xrefs';
$unidbfile = '/home/gabriels/public_html/uniprot_sprot.dat';


my $time = localtime;
my $remote_addr = $ENV{'REMOTE_ADDR'};



open (XREF, $xreffile) or die "er";
@xrefs = <XREF>;
close XREF;

open (TIN, $dset) or die "er2";
@tin = <TIN>;
close TIN;

open (UNI, $unidbfile) or die "er3";
@uni = <UNI>;
close UNI;


#open (OUTPUT, ">>/home/gabriels/public_html/mpdlog.txt");
#print OUTPUT "TOPO: $remote_addr used batch_topo ($scmin) on $time\n";
#close OUTPUT;


%unixens = ();

foreach (@xrefs) {

    @currow = split(/\t/,$_);
    $currow[10] =~ /(......)/;
    $curuni = $1;

    @curipis = split(/\;/,$currow[9]);
    foreach (@curipis) {
	$ipixuni{$_} = $curuni;
    }

    $unixens{$currow[6]} = $curuni;
    $ensxuni{$curuni} = $currow[6] if (!exists $ensxuni{$curuni});
}



print "Content-type: text/html\n\n";
print "<HTML><HEAD><TITLE>Batch annotate</TITLE></HEAD><BODY><H3>Cystannotation</H3><BR>\n";
print "<HR>\n";


print "<TABLE BORDER=1>\n";


for ($i = 1; $i < scalar @tin; ++$i) {
    if ($tin[$i] =~ /^\d+/) {
	++$counter;
	@currow = split(/\t/, $tin[$i]);
	@nextrow = split(/\t/, $tin[$i+1]);
	$curipi = $nextrow[1];
	$curipi =~ /(IPI\d+)/g;
	$curipi = $1;
	$cur10rat = $currow[8];
	$curseq = $currow[4];
	$starseq = $nextrow[4];
	$starseq =~ /\.([^\.]*)\./;
	$starseq = $1;
	$starseq =~ m/\*/g;
	$starpos = pos ($starseq);
	$dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$curuni&format=default&style=raw&Retrieve=Retrieve";

	$ewdata{$ipixuni{$curipi}}[0] = $curipi;
	$ewdata{$ipixuni{$curipi}}[1] = $cur10rat;
	$ewdata{$ipixuni{$curipi}}[2] = $starseq;
	$ewdata{$ipixuni{$curipi}}[3] = $starpos;

	print "<TR><TD>$counter</TD><TD>$curipi</TD><TD>$cur10rat</TD><TD><A HREF=\"$dbfetchlink\" TARGET=\"_blank\">$ipixuni{$curipi}</A></TD><TD>$starseq</TD><TD>$starpos</TD></TR>\n" if (length($curipi) > 10);
    }
}




$counter = 0;
foreach $curuni (keys %ewdata) {
    $dbstring .= "$curuni,";
    if ($counter % 200 == 0) {
	chop $dbstring;
	$dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$dbstring&format=default&style=raw&Retrieve=Retrieve";
	$dbholder .= get $dbfetchlink;
	$dbstring = "";
	print "<B>loading...</B><BR>\n\n";
    }
    ++$counter;
}


print "</TABLE>\n";


@unidata = split(/\n/,$dbholder);

foreach (@unidata) {
    print "$_<BR>\n";
}


=pod
for ($i = 0; $i < scalar @ensholder; ++$i) {
    print "<TR>\n";
    print "<TD>$i</TD>\n";
    print "<TD>$ensholder[$i]</TD>\n";
    $curuni = $unixens{$ensholder[$i]};
    print "<TD>$curuni</TD>\n";
    print "</TR>\n";

    $dbstring .= "$curuni,";
    if ($i % 100 == 0) {
	chop $dbstring;
	$dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$dbstring&format=default&style=raw&Retrieve=Retrieve";
#	print "<TR><TD><A HREF=\"$dbfetchlink\">link</A></TD></TR>\n";
	$dbholder .= get $dbfetchlink;
	$dbstring = "";
	print "<B>loading...</B><BR>\n\n";
    }

}

chop $dbstring;
$dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$dbstring&format=default&style=raw&Retrieve=Retrieve";
$dbholder .= get $dbfetchlink;
print "<FONT COLOR=FF0000><B>Done!</B> <A HREF=\"#results\">click here to jump to results</A></FONT><P>\n";
print "</TABLE>\n";
print "<HR>\n";

@db = split(/\n/,$dbholder);

$entry = 1;

print "<A NAME=\"results\"></A><TABLE BORDER=1>\n";

for ($i = 0; $i < scalar @db; ++$i) {

    if ($db[$i] =~ /^ID\s+(\S+)/) { #####################
#	print "$entry: $1 - ";
	$uniid = $1;

	++$entry;
	@acs = ();

	################### get data from Unidb #####################
	@tmdoms = ();
	@sigdoms = ();

	while ($db[$i] !~ /^\/\//) {

	    if ($db[$i] =~ /^AC\s+(.*)/) {  #uniprot IDs
		$acline = $1;
		@curacs = split(/;/, $acline);
		push (@acs, @curacs);
	    } 

	    if ($db[$i] =~ /FT\s+TRANSMEM\s+(\d+)\s+(\d+)/) {  #tm domains
		$curtmstring = "$1-$2";
		push (@tmdoms, $curtmstring);		
	    }

	    if ($db[$i] =~ /FT\s+SIGNAL\s+(\d+)\s+(\d+)/) {  #signal domains
		$cursigstring = "$1-$2";
		push (@sigdoms, $cursigstring);		
	    }

	    if ($db[$i] =~ /SQ\s+SEQUENCE\s+(\d+)/) { #sequence length
		$curseqlen = $1;
	    }






	    ++$i;
	}
	###################
	
	foreach $curuni (@acs) {
	    $curuni =~ s/\s+//g;
	    $curuni =~ s/\;//g;

	    if (($curuni ne "") && (exists $ensxuni{$curuni}) && (exists $enstracker{ $ensxuni{$curuni} } ) ) {
#		print $ensxuni{$curuni} . " - LEN: $curseqlen, SIG: @sigdoms, TM: @tmdoms<BR>\n";
		if ((scalar @tmdoms > 0) || (scalar @sigdoms > 0)) {
		    ++$domcounter;
		    @urlargs = ();
		    push (@urlargs, "len=$curseqlen");
		    if (scalar @sigdoms > 0) {
			foreach (@sigdoms) {
			    push (@urlargs, "sig=$_");
			}
		    } 
		    if (scalar @tmdoms > 0) {
			foreach (@tmdoms) {
			    push (@urlargs, "tm=$_");
			}
		    } 
		    $urlargstring = join('&',@urlargs);
		    print "<TR><TD>$domcounter</TD><TD><A HREF=" . 'http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=' . $uniid . '&format=default&style=default&Retrieve=Retrieve' . "\" TARGET=\"_blank\">$uniid</A></TD><TD>$ensxuni{$curuni}</TD><TD><A HREF=\"pmap2rec.pl?dset=$dset&searchterm=$ensxuni{$curuni}&numperpage=20&pagereq=1&scmin=0&scmax=100000\" TARGET=\"_blank\"><IMG SRC=\"dompng.pl?$urlargstring\" BORDER=0></A></TR>\n";
		}
		$curens = $ensxuni;
	    }
	    
	}

    } #####################################################

}


print "</TABLE>\n";




print "<P><HR>bye</BODY></HTML>\n";

sub get_ctrl_sc {
    $n = shift;
    $nb = shift;
    $curline = shift;
    @curentry = split(/\t/,$curline);
#    $curentry[0] =~ /(\S+)/;
    $curscsum = 0;
    for ($g = 2; $g <= ($n * $nb + 1); ++$g) {
	$curscsum += $curentry[$g];
    }
    return $curscsum;
}

sub get_exp_sc {
    $n = shift;
    $nb = shift;
    $curline = shift;
    @curentry = split(/\t/,$curline);
#    $curentry[0] =~ /(\S+)/;
    $curscsum = 0;
    for ($g = ($n * $nb + 2); $g <= ($n * $nb * 2) + 1; ++$g) {
	$curscsum += $curentry[$g];
    }
    return $curscsum;
}



=cut
