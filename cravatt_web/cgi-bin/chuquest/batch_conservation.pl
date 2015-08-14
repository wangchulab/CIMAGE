#!/usr/bin/perl

###############################################################################################
#
################################################################################################



use CGI;
#use GD;
#use GD::Graph::points;
#use GD::Graph::axestype;
#use Math::Trig;

$q = new CGI;

$minrat = $q->param('minrat');
$maxrat = $q->param('maxrat');
$dset = $q->param('dset');
$pdbon = $q->param('pdbon');
$show15 = $q->param('show15');
$mode = $q->param('mode');
$insituoverlay = $q->param('insituoverlay');
$ismouse = $q->param('ismouse');

$mode = "html" if ($mode eq "");
$minrat = 0 if ($minrat eq "");
$maxrat = 10000 if ($maxrat eq "");

$ymax = 15;

@orgs = ("a_gambiae","a_thaliana","b_taurus","c_elegans","d_pseudoobscura","d_rerio","m_musculus","s_cerevisiae","s_pombe","x_tropicalis");


#$defaultdset = '/home/chuwang/public_html/from_DTASelect/combined_all.txt';
#$defaultdset = '/home/chuwang/public_html/from_DTASelect/combined_231_mcf7_jurkat.txt';
$defaultdset = '/home/chuwang/public_html/from_DTASelect/new_probe/combined_231_mcf7_jurkat.txt';

#$dset231 = '/home/chuwang/public_html/from_DTASelect/231/231_combined.txt';
#$dsetmcf7 = '/home/chuwang/public_html/from_DTASelect/mcf7/mcf7_combined.txt';
#$dsetjurkat = '/home/chuwang/public_html/from_DTASelect/jurkat/jurkcat_combined.txt';
#$bothdsets = '/home/chuwang/public_html/from_DTASelect/combined_all.txt';

$dset = $defaultdset if ($dset eq "");

$ismouse = 1 if ($dset =~ /heart/);


$htmllink = $dset;

$htmllink =~ s/\/home\//\/\~/;
$htmllink =~ s/public_html\///g;
$htmllink =~ s/txt/html/g;


$scmin = $q->param('scmin');

if ($ismouse == 1) {
    $xreffile = '/home/gabriels/public_html/ipi.genes.MOUSE.xrefs';
} else {
    $xreffile = '/home/gabriels/public_html/ipi.genes.HUMAN.xrefs';
#$xreffile = '/home/gabriels/perl/fasta/ensipi/ipi.genes.HUMAN.xrefs';
}


if ($pdbon == 1) {
    $uniprotfile = '/home/gabriels/public_html/uniprot_sprot_HUMAN.dat';
} else {
    if ($ismouse == 1) {
	$uniprotfile = '/home/gabriels/public_html/uniprot_sprot_MUS_IDACFTSQ.dat';
    } else {
	$uniprotfile = '/home/gabriels/public_html/uniprot_sprot_HUMAN_IDACFTSQ.dat';
    }
}

if ($insituoverlay == 1) {
#    open (INSITU, '/home/chuwang/public_html/from_DTASelect/insitu/mcf_231_insitu_invitro/combined_insitu_1_2_invitro.txt') or die "er4";
    open (INSITU, '/home/chuwang/public_html/from_DTASelect/insitu/mcf_231_insitu_invitro/combined_insitu_1_2.txt') or die "er4";
    @insitutxt = <INSITU>;
    close INSITU;
}


my $time = localtime;
my $remote_addr = $ENV{'REMOTE_ADDR'};

open (XREF, $xreffile) or die "er";
@xrefs = <XREF>;
close XREF;

open (TIN, $dset) or die "er2";
@tin = <TIN>;
close TIN;

open (UNI, $uniprotfile) or die "er3";
@uni = <UNI>;
close UNI;

#open (OUTPUT, ">>/home/gabriels/public_html/mpdlog.txt");
#print OUTPUT "TOPO: $remote_addr used batch_topo ($scmin) on $time\n";
#close OUTPUT;

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

    foreach (@curaccs) {
	$unihash{$_} = $curentry;
    }


}



##############################################################

################# get x-refs ################################
%unixens = ();

foreach (@xrefs) {

    @currow = split(/\t/,$_);
    if ($currow[10] =~ /(......)/) {
	$curuni = $1;
    } elsif ($currow[11] =~ /(......)/) {
	$curuni = $1;
    }

    @curipis = split(/\;/,$currow[9]);
    foreach (@curipis) {
	$ipixuni{$_} = $curuni;
    }

    $unixens{$currow[6]} = $curuni;
    $ensxuni{$curuni} = $currow[6] if (!exists $ensxuni{$curuni});
}
################################################################




push (@htmlholder,  "Content-type: text/html\n\n");
push (@htmlholder, "<HTML><HEAD>\n");
push (@htmlholder, '<script type="text/javascript">' . "\n", 'function swap(listIdPrefix,group) {' . "\n", 'collapsedList = document.getElementById(listIdPrefix + "_collapsed");' . "\n", 'expandedList = document.getElementById(listIdPrefix + "_expanded");' . "\n", 'if (collapsedList.style.display == "block") {' . "\n",'collapsedList.style.display = "none";' . "\n",'expandedList.style.display = "block";' . "\n",'} else {' . "\n",'collapsedList.style.display = "block";' . "\n",'expandedList.style.display = "none";' . "\n",'}' . "\n",'if (group) {', 'ensureExclusivity(listIdPrefix,group);' . "\n",'}' . "\n",'}' . "\n",'function ensureExclusivity(listIdPrefix,group) {' . "\n", '//alert("listIdPrefix is " + listIdPrefix + ", group is " + group);' . "\n", 'for (var i = 0 ; i < group.length ; i++) {' . "\n", 'if (group[i] != listIdPrefix) {' . "\n", 'document.getElementById(group[i] + "_collapsed").style.display = "block";' . "\n", 'document.getElementById(group[i] + "_expanded").style.display = "none";' . "\n",'}' . "\n",'}' . "\n",'}' . "\n",'// mutually exclusive lists' . "\n",'    var groupA = new Array();' . "\n",'groupA[groupA.length] = "list_a_excl";' . "\n",'groupA[groupA.length] = "list_b_excl";' . "\n",'var outerGroup = new Array();' . "\n",'outerGroup[outerGroup.length] = "list_1";' . "\n",'outerGroup[outerGroup.length] = "list_2";' . "\n",'var innerGroup1 = new Array();' . "\n",'innerGroup1[innerGroup1.length] = "list_1_a";' . "\n",'innerGroup1[innerGroup1.length] = "list_1_b";' . "\n",'var innerGroup2 = new Array();' . "\n",'innerGroup2[innerGroup2.length] = "list_2_a";' . "\n",'innerGroup2[innerGroup2.length] = "list_2_b";' . "\n", '</script>');

push (@htmlholder,  "<style> a:hover{color:red;} </style>\n");
push (@htmlholder,  "<TITLE>Batch annotate</TITLE></HEAD><BODY LINK=\"#696969\" VLINK=\"#696969\">\n");


push (@htmlholder, "<div id=\"list_a_collapsed\" style=\"display:block;\">\n");
push (@htmlholder, "[<A HREF=\"javascript:swap(\'list_a\')\">show available datasets</A>]<BR></DIV>\n");
push (@htmlholder, "<div id=\"list_a_expanded\" style=\"display:none;\">\n");
push (@htmlholder, "[<A HREF=\"javascript:swap(\'list_a\')\">hide available datsets</A>]<BR>\n");
push (@htmlholder, "<div style=\"margin-left:50px;margin-top:20px;\">\n");
&readdirs('/home/chuwang/public_html/from_DTASelect/');    
push (@htmlholder, "<p></div></div>\n");

push (@htmlholder,  "<A HREF=\"$htmllink\">click here to see chromatographs</A>\n");
push (@htmlholder,  "<HR>\n");

$shortfilename = $dset;
$shortfilename =~ s/\/home\/chuwang\/public_html\/from_DTASelect\///g;

push (@htmlholder, "<center><h3>$shortfilename</h3></center>\n");
#push (@htmlholder, "<CENTER><IMG SRC=\"batch_annotate.pl?mode=png&dset=$dset&minrat=$minrat&maxrat=$maxrat&insituoverlay=$insituoverlay\"></CENTER><BR>\n");



##################### read data from txt file ##############################################################

if ($insituoverlay == 1) {
    for ($i = 1; $i < scalar @insitutxt; ++$i) {
	if ($insitutxt[$i] =~ /^\d+/) {
	    @currow = split(/\t/,$insitutxt[$i]);
	    @nextrow = split(/\t/, $insitutxt[$i+1]);
	    $nextrow[2] =~ /^(\S+)/;
	    $cursym = $1;
	    $curipi = $nextrow[1];
	    $curipi =~ /(IPI\d+)/;
	    $curipi = $1;
	    $curis2rat = $currow[7];
	    $curis1rat = $currow[6];
	    $curseq = $currow[4];
	    $curuni = $ipixuni{$curipi};
	    $curunidata = $unihash{$curuni};
	    @uni = split(/\n/,$curunidata);
	    $curuniseq = "";
	    foreach (@uni) {
		$curuniseq .= $_ if ($_ =~ /^\s+/);
	    }

	    $curuniseq =~ s/\n//g;
	    $curuniseq =~ s/\s+//g;

	    ++$i;
	    %unireskeeper = ();
	    %unistarposkeeper = ();
	    %posholder = ();
	    %starseqholder = ();
	    while (($insitutxt[$i] !~ /^\d+/)&& ($i < scalar @insitutxt)) {
		
		@peprow = split(/\t/, $insitutxt[$i]);
		$starseq = $peprow[4];
		$starseq =~ /\.([^\.]*)\./;
		$starseq = $1;

		$starseq =~ m/\*/g;
		$starpos = pos ($starseq);
		$posholder{$starpos} = 1;

		$nostarseq = $starseq;
		$nostarseq =~ s/\*//g;

		$curuniseq =~ /^./g;  #resets curuniseq pos to 0 to prevent matching-errors
		$curuniseq =~ /$nostarseq/gi;
		$peptidepos = pos($curuniseq);

		$unistarpos = $peptidepos - length($nostarseq) + $starpos - 1;
		@uniseq = split(//,$curuniseq);
		$unires = $uniseq[$unistarpos - 1];
		$unistarposkeeper{$unistarpos}[0] = 1;
		$unistarposkeeper{$unistarpos}[1] = "$unires$unistarpos";
		$starseqholder{"$starseq ($unires$unistarpos)"} = 1;
#		push (@htmlholder,  "$i: $curipi = $curuni, $starseq, $starpos, $peptidepos - $unires$unistarpos<BR>\n");
		$isresholder{"$curuni $unires$unistarpos"}[0] = $curis1rat;
		$isresholder{"$curuni $unires$unistarpos"}[1] = $curis2rat;
		++$i;
	    }

	    --$i;

	}
    }
}


#foreach (keys %isresholder) {
#    push (@htmlholder,  "$_: $isresholder{$_}[0] $isresholder{$_}[1]<BR>\n");
#}

@toprow = split(/\t/,$tin[1]);
$numrats = ((scalar @toprow) - 10) / 2;
$col10 = 5 + $numrats;

push (@htmlholder, "$numrats ratios<BR>\n");

push (@htmlholder,  "<TABLE BORDER=1>\n");
push (@htmlholder,  "<TR>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>#</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>IPI</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>1:1</B></TD><TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>5:1</B></TD>\n") if ($show15 == 1);
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>10:1</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>UniProt</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>Peptide</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>Residue</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>Annotation</B></TD>\n");
push (@htmlholder,  "<TD ALIGN=CENTER BGCOLOR=\"#CCCCCC\"><B>In situ?</B></TD>\n") if ($insituoverlay == 1);
push (@htmlholder, "<TD BGCOLOR=\"#CCCCCC\"><B>Conservation</B></TD>\n");
push (@htmlholder,  "</TR>\n");



for ($i = 1; $i < scalar @tin; ++$i) {

    if ($tin[$i] =~ /^\d+/) {
	++$counter;
	@currow = split(/\t/, $tin[$i]);
	$tolcols = scalar @currow;
	@nextrow = split(/\t/, $tin[$i+1]);
	$nextrow[2] =~ /^(\S+)/;
	$cursym = $1;
	$curipi = $nextrow[1];
	$curipi =~ /(IPI\d+)/g;
	$curipi = $1;
	$curipilink = 'http://www.ebi.ac.uk/cgi-bin/dbfetch?db=IPI&id=' . $curipi . '&format=default';
#	$cur10rat = $currow[8];
	$cur10rat = $currow[$col10];
	$cur5rat = $currow[$col10 - 1];
	$cur1rat = $currow[$col10 - 2];
#	$foundinruns = $currow[12];
	$foundinruns = $currow[$col10 + $numrats + 1];
	$curseq = $currow[4];
	$curuni = $ipixuni{$curipi};
	$dbfetchlink = "http://www.ebi.ac.uk/cgi-bin/dbfetch?db=uniprotkb&id=$curuni&format=default&style=default&Retrieve=Retrieve";
	$curunidata = $unihash{$curuni};
	@uni = split(/\n/,$curunidata);

	$curuniseq = "";
	foreach (@uni) {
	    $curuniseq .= $_ if ($_ =~ /^\s+/);
	}

	$curuniseq =~ s/\n//g;
	$curuniseq =~ s/\s+//g;

	++$i;
	%unireskeeper = ();
	%unistarposkeeper = ();
	%posholder = ();
	%starseqholder = ();
	while (($tin[$i] !~ /^\d+/)&& ($i < scalar @tin)) {

	    @peprow = split(/\t/, $tin[$i]);
	    $starseq = $peprow[4];
	    $starseq =~ /\.([^\.]*)\./;
	    $starseq = $1;

	    $starseq =~ m/\*/g;
	    $starpos = pos ($starseq);
	    $posholder{$starpos} = 1;

	    $nostarseq = $starseq;
	    $nostarseq =~ s/\*//g;

	    $curuniseq =~ /^./g;  #resets curuniseq pos to 0 to prevent matching-errors
	    $curuniseq =~ /$nostarseq/gi;
	    $peptidepos = pos($curuniseq);

	    $unistarpos = $peptidepos - length($nostarseq) + $starpos - 1;
	    @uniseq = split(//,$curuniseq);
	    $unires = $uniseq[$unistarpos - 1];
	    $unistarposkeeper{$unistarpos}[0] = 1;
	    $unistarposkeeper{$unistarpos}[1] = "$unires$unistarpos";
	    $starseqholder{"$starseq ($unires$unistarpos)"} = 1;
#	    print "$i: $starseq, $starpos, $peptidepos - $unires$unistarpos<BR>\n";

	    ++$i;
	}

	--$i;



	$pdbstring = "";
	$fullstring = "";
	$reslist = "";
	$curistd = "";

	foreach $unistarpos (keys %unistarposkeeper) {
	    $exactstring = "";
	    if (($isresholder{"$curuni " . $unistarposkeeper{$unistarpos}[1]}[1] > 0) || ($isresholder{"$curuni " . $unistarposkeeper{$unistarpos}[1]}[0] > 0)  ) {
		$reslist .= "$unistarposkeeper{$unistarpos}[1], ";
#		$reslist .= "<font color=\"#ff0000\">$unistarposkeeper{$unistarpos}[1]</font>, ";
#		$curistd .= "$unistarposkeeper{$unistarpos}[1] - " . $isresholder{"$curuni $unistarposkeeper{$unistarpos}[1]"}[0] . ", " . $isresholder{"$curuni $unistarposkeeper{$unistarpos}[1]"}[1] . ", ";
		$curistd .= "$unistarposkeeper{$unistarpos}[1], ";
	    } else {
		$reslist .= "$unistarposkeeper{$unistarpos}[1], ";
	    }

	    foreach (@uni) {

		if ($_ =~ /^FT   (\S+)\s+(\d+)\s+(\d+)(.*)/) {

		    ($type, $p1, $p2) = ($1, $2, $3);
		    $type .= " $4";

		    if ($type =~ /^DISULFI(.*)/) {
			$restofstring = $1;
			if ($restofstring =~ /Redox/) {
			    $basetype = "DISULFID_Redox-active";
			} else {
			    $basetype = "DISULFID_Other";
			}
		    } else {
			$type =~ /(\S+)/;
			$basetype = $1;
		    }

		    if (($p1 == $p2) && ( $p1 == $unistarpos ) &&  ($type !~ /MUTAGEN.*No effect/g)  ){
			$exactstring .= "$type, ";
			++$basetypecounter{$basetype} if((length($curipi) > 10) && ($cur10rat > $minrat) && ($cur10rat < $maxrat));
		    }
		    if (($p1 != $p2) && ( ($p1 == $unistarpos) || ($p2 == $unistarpos) ) )  {
			if ($type =~ /DISULFID/) {
			    $exactstring .= "$type, ";
			    ++$basetypecounter{$basetype} if((length($curipi) > 10) && ($cur10rat > $minrat) && ($cur10rat < $maxrat));
			}
		    }
		}


		if ($_ =~ /^DR   PDB; (....)/) {
		    $pdbstring .= "$1, ";
		}

	    }
	    chop $exactstring;
	    chop $exactstring;

	    if (($unistarposkeeper{$unistarpos}[1] =~ /C\d+/) && (length($curipi) > 10) && ($cur10rat > $minrat) && ($cur10rat < $maxrat)) {
		$bigcounter{"$curipi - $unistarposkeeper{$unistarpos}[1]"} = $exactstring;
	    }

	    if ($exactstring ne "") {
		$fullstring .= "$unistarposkeeper{$unistarpos}[1] - $exactstring<BR>  ";
		$exactstring = "";
	    }

	}


	chop $fullstring;
	chop $fullstring;
	chop $pdbstring;
	chop $pdbstring;
	chop $reslist;
	chop $reslist;
	chop $curistd;
	chop $curistd;


	$pdbstring = "($pdbstring)" if ($pdbstring ne ""); 

	$pdbstring = "" if ($pdbon != 1);

	if ((length($curipi) > 10) && ($cur10rat > $minrat) && ($cur10rat < $maxrat) ){

	    $plottype = "";
	    $fullstring =~ /^.\d+ - (.*)/;
	    $plottype = $1;

	    #### load plot-data #####
	    
	    push (@ids, $counter);
	    push (@plotrats, $cur10rat);
	    push (@plottypes, $plottype);
	    push (@names, $cursym);
	    if ($curistd eq "") {
		push (@is, 0);
	    } else {
		push (@is, 1);
	    }

	    #########################



	    push (@htmlholder,  "<TR>\n");
	    push (@htmlholder,  "<TD>$counter</TD>\n");
	    push (@htmlholder,  "<TD><A HREF=\"$curipilink\" TARGET=\"_blank\">$curipi</A> - $cursym $pdbstring [$foundinruns]</TD>\n");
	    if ($show15 == 1) {
		push (@htmlholder,  "<TD>$cur1rat</TD>\n");
		push (@htmlholder,  "<TD>$cur5rat</TD>\n");
	    }
	    push (@htmlholder,  "<TD>$cur10rat</TD>\n");
	    push (@htmlholder,  "<TD><A HREF=\"$dbfetchlink\" TARGET=\"_blank\">$curuni</A></TD>\n");
	    push (@htmlholder,  "<TD>\n");
	    @starpepholder = ();
	    foreach (keys %starseqholder) {
		push (@htmlholder,  "<FONT SIZE=-2>$_</FONT><BR>\n");
		push (@starpepholder, $_);
	    }
	    push (@htmlholder,  "</TD>\n");

	    if ($reslist =~ /-/g) {
		push (@htmlholder, "<TD><FONT COLOR=\"FF0000\"><B>$reslist</B></FONT></TD>\n");
	    } else {
		push (@htmlholder,  "<TD>$reslist</TD>\n");
	    }
	    ++$totalc if ($unires eq "C");
	    push (@htmlholder,  "<TD>$fullstring</TD>\n");
	    push (@htmlholder, "<TD>");
	    $numorthologues = 0;
	    $numconservedcs = 0;
	    push (@htmlholder, "<TABLE BORDER=0>\n");  #for conservation table
	    foreach (@orgs) {
		$curloc = "/gblast/$curuni" . "_" . "$_" . '.txt';
		if (-e "/home/gabriels/concys/gblasthits/$curuni" . '_' . "$_" . '.txt') {
		    open (BLASTIN, "/home/gabriels/concys/gblasthits/$curuni" . '_' . "$_" . '.txt') or die "cannot erxxx";
		    @blastin = <BLASTIN>;
		    close BLASTIN;
		    $blastin[1] =~ /^Q: (.*)/;
		    $qseq = $1;
		    $blastin[2] =~ /^S: (.*)/;
		    $sseq = $1;
		    @qaa = split(//,$qseq);
		    @saa = split(//,$sseq);
		    @qaar = ();
		    @saar = ();
		    for ($k = 0; $k < scalar @qaa; ++$k) {
		        if ($qaa[$k] =~ /[ACDEFGHIKLMNPQRSTVWY]/) {
			    push (@qaar, $qaa[$k]);
			    push (@saar, $saa[$k]);
			}
		    }
		    $qaarseq = join (//,@qaar);
		    $saarseq = join (//,@saar);

		    $starpepholder[0] =~ /(\S+)/;
		    $pepseq = $1;
		    
		    $pepseq =~ m/\*/g;
		    $starpos = pos ($pepseq);
#		    $posholder{$starpos} = 1;
		    $rawpepseq = $pepseq;
		    $rawpepseq =~ s/\*//g;
		    
		    $qaarseq =~ /$rawpepseq/g;
		    $peppos = pos ($qaarseq);
#		    $peppos = $peppos;
		    $realstarpos = $peppos - length($rawpepseq);
		    $realstarpos = $realstarpos + $starpos - 2;

		    push (@htmlholder, "<TR><TD>\[" . $qaar[$realstarpos] . ":$saar[$realstarpos]\]</TD>") if ($peppos>0);
		    push (@htmlholder, "<TD><A HREF=\"$curloc\">$_</A></TR></TR>") if ($peppos>0);

		    ++$numconservedcs if (($qaar[$realstarpos] eq $saar[$realstarpos]) && ($peppos>0));
		    ++$numorthologues if ($peppos > 0);
		}
	    }
	    push (@htmlholder, "</TABLE>\n");
	    
	    
	    push (@htmlholder, " $numconservedcs \/ $numorthologues $pepseq ") if ($showcons == 1);

	    if ($numorthologues > 0) {
		$consrat = ($numconservedcs / $numorthologues);
	    } else {
		$consrat = 0;
	    }
	    
	    push (@htmlholder, "</TD><TD>$consrat</TD>\n") if ($showcons == 1);

	    push (@htmlholder, "<TD ALIGN=CENTER BGCOLOR=\"E0FFFF\">$curistd</TD>\n") if ($insituoverlay == 1);




	    push (@htmlholder,  "</TR>\n");
	}
    }
}

push (@htmlholder,  "</TABLE>\n");
=pod
my $my_graph = GD::Graph::points->new(1280,480);

@data = (\@ids, \@plotrats);

$xmax = scalar @ids;
$xmax = (int($xmax / 100) + 1) * 100;


$my_graph->set(
	       t_margin          => 10,
	       b_margin          => 30,
	       r_margin          => 40,
	       l_margin          => 10,
	       x_label => "peptide #",
	       y_label => "10:1 ratio",
	       title => "chuquest annotator",
	       x_label_position => 1/2,

	       fgclr => 'black',
	       boxclr => 'lgray',
	       
	       y_max_value=>$ymax,
	       x_max_value =>$xmax,  #approx 3000 kDa
	       
	       x_tick_number => $xmax / 100,
	       y_tick_number => 15,
	       y_label_skip =>5,
	       x_long_ticks => 0,
	       y_long_ticks => 0,
	       marker_size => 0.1,
	       transparent => 0,
	       dclrs => [qw(lgray)],
	       );


push (@htmlholder,  "<HR>\n");


################################# re-draw datapoints ###################################
my $gd=$my_graph->plot(\@data);

$red = $gd->colorAllocate(255,0,0);  #define colors
$blue = $gd->colorAllocate(0,0,255);
$black = $gd->colorAllocate(0,0,0);
$grey = $gd->colorAllocate(100,100,100);
$yellow = $gd->colorAllocate(255,255,0);
$teal = $gd->colorAllocate(0,128,128);

  # add lines at 1/5/10 ratios
($curxp1, $curyp1) = $my_graph->val_to_pixel( 0, 1, 1);
($curxp2, $curyp2) = $my_graph->val_to_pixel( $xmax, 1, 1);
$gd->line($curxp1, $curyp1, $curxp2, $curyp2, $grey);

($curxp1, $curyp1) = $my_graph->val_to_pixel( 0, 5, 1);
($curxp2, $curyp2) = $my_graph->val_to_pixel( $xmax, 5, 1);
$gd->line($curxp1, $curyp1, $curxp2, $curyp2, $grey);

($curxp1, $curyp1) = $my_graph->val_to_pixel( 0, 10, 1);
($curxp2, $curyp2) = $my_graph->val_to_pixel( $xmax, 10, 1);
$gd->line($curxp1, $curyp1, $curxp2, $curyp2, $grey);


for ($i = 0; $i < scalar @ids; ++$i) {
    $curx = $i;
    $cury = $plotrats[$i];
    ($curxp, $curyp) = $my_graph->val_to_pixel( $curx, $cury, 1);

    if ($plottypes[$i] =~ /^ACT_SITE/) {
    } elsif ($plottypes[$i] =~ /^DISULFID\s+Redox/) {
    } elsif ($plottypes[$i] =~ /^DISULFID/) {
	$gd->filledArc($curxp, $curyp,5,5,0,360,$grey);
    }else {
	$gd->filledArc($curxp, $curyp,3,3,0,360,$black);
	$ascounter[$i] = 0;
    }
}

for ($i = 0; $i < scalar @ids; ++$i) {
    $curx = $i;
    $cury = $plotrats[$i];
    ($curxp, $curyp) = $my_graph->val_to_pixel( $curx, $cury, 1);

    if ($plottypes[$i] =~ /^ACT_SITE/) {
	$gd->filledArc($curxp, $curyp,5,5,0,360,$red);
	$ascounter[$i] = 1;
    } elsif ( $plottypes[$i] =~ /^DISULFID\s+Redox/) {
	$gd->filledArc($curxp, $curyp,5,5,0,360,$yellow);
	$ascounter[$i] = 1;
    } else {
    }
}

if ($insituoverlay == 1) {


    for ($i = 0; $i < scalar @ids; ++$i) {
	$curx = $i;
	$cury = $plotrats[$i];
	($curxp, $curyp) = $my_graph->val_to_pixel( $curx, $cury, 1);
	
	
	if ($is[$i] == 0) {
	} else {
#	    $gd->filledArc($curxp, $curyp - 10, 3, 3, 0, 360, $blue);
	    $gd->arc($curxp, $curyp - 10, 3, 3, 0, 360, $blue);
	}
    }


}
=cut







=pod

($oldx, $oldy) = (0,0);
$maxav = 0;

for ($i = 0; $i < scalar @ascounter; ++$i) {       #moving average
    $cursum = 0;
    if ($i + 50 > scalar @ascounter) {
	$maxi = scalar @ascounter;
    } else {
	$maxi = $i + 50;
    }
    for ($j = $i; $j < $maxi; ++$j) {
	$cursum += $ascounter[$j];
    }
    $curav = $cursum / 50;
    $maxav = $curav if ($curav > $maxav);

    $curx = $i;
    $avx[$i] = $curx;
    $avy[$i] = $curav;
}

$ycoeff = $ymax / $maxav;

for ($i = 0; $i < scalar @avx; ++$i) {                #plot moving av
    $avy[$i] = $avy[$i] * $ycoeff;
    ($curxp, $curyp) = $my_graph->val_to_pixel( $avx[$i], $avy[$i], 1);
    $gd->line($curxp, $curyp, $oldx, $oldy, $teal) if ($i > 0);
    ($oldx, $oldy) = ($curxp, $curyp);

}

$font = "cour.ttf";

($curxp, $curyp) = $my_graph->val_to_pixel( $xmax, $maxav * $ycoeff, 1);        #plot secondary y-axis
$gd->string(gdSmallFont,$curxp+3,$curyp - 5,($maxav * 100) . '%',$teal);
($curxp, $curyp) = $my_graph->val_to_pixel( $xmax, $maxav * $ycoeff * 0.67, 1);        #plot secondary y-axis
$gd->string(gdSmallFont,$curxp+3,$curyp - 5,int($maxav * 100 * 0.67) . '%',$teal);
($curxp, $curyp) = $my_graph->val_to_pixel( $xmax, $maxav * $ycoeff * 0.33, 1);        #plot secondary y-axis
$gd->string(gdSmallFont,$curxp+3,$curyp - 5,int($maxav * 100* 0.33) . '%',$teal);

($curxp, $curyp) = $my_graph->val_to_pixel( $xmax, $maxav * $ycoeff * 0.67, 1);        #plot secondary y-axis

$gd->stringFT($teal, $font, 10, 4.71238898, $curxp+30, $curyp-35, "percent functionally annotated");


###########################################################################################

=cut

push (@htmlholder,  "<HR>\n");



@basesorter = sort {$basetypecounter{$b} <=> $basetypecounter{$a}} keys %basetypecounter;

push (@htmlholder,  "<!--\n"); #######################################################################

push (@htmlholder,  "<h3>total cysteines: $totalc</h3>\n");
push (@htmlholder,  "<H3>base-type</H3><TABLE BORDER=1>\n");
for ($i = 0; $i < scalar @basesorter; ++$i) {
    push (@htmlholder,  "<TR>\n");
    push (@htmlholder,  "<TD>$basetypecounter{$basesorter[$i]}</TD><TD>$basesorter[$i]</TD>\n");
   push (@htmlholder,  "</TR>\n");
}
push (@htmlholder,  "</TABLE>\n");

push (@htmlholder,  "<HR>\n");

#---------------------------------------------------------------------------------------------------------------------------------------


push (@htmlholder,  "<H3>unique entries (non-redundant, main-type)</H3>\n");

push (@htmlholder,  "<TABLE BORDER=1>\n");

@bigsort = sort {$a cmp $b} keys %bigcounter;

for ($i = 0; $i < scalar @bigsort; ++$i) {

    if ($bigcounter{$bigsort[$i]} =~ /^DISULFI(.*)/) {
	$restofstring = $1;
	if ($restofstring =~ /Redox/) {
	    $maintype = "DISULFID_Redox-active";
	} else {
	    $maintype = "DISULFID_Other";
	}
    } elsif ($bigcounter{$bigsort[$i]} =~ /(\S+)/) {
	$maintype = $1;
    } else {
	$maintype = "";
    }

    push (@htmlholder,  "<TR>\n");
    push (@htmlholder,  "<TD>$i</TD><TD>$bigsort[$i]</TD><TD>$maintype</TD>\n");
    ++$nrtypecounter{$maintype};
    push (@htmlholder,  "</TR>\n");
}

push (@htmlholder,  "</TABLE>\n");

push (@htmlholder,  "--!>\n"); ############################################

#---------------------------------------------------------------------------------------------------------------------------------------

push (@htmlholder,  "<H3>non-redundant tally:</H3>\n");

@nrsort = sort {$nrtypecounter{$b} <=> $nrtypecounter{$a}} keys %nrtypecounter;

push (@htmlholder,  "<TABLE BORDER=1>\n");
foreach (@nrsort) {
    push (@htmlholder,  "<TR><TD>$_</TD><TD>$nrtypecounter{$_}</TD></TR>\n");
}
push (@htmlholder,  "</TABLE>\n");



&makehtml if ($mode eq "html");
&makepng if ($mode eq "png");



sub makepng {
    binmode STDOUT;

    print STDOUT "Content-type: image/png\n\n";
    print STDOUT $gd->png;
}

sub makehtml {
    foreach (@htmlholder) {
	print $_;
    }
}


sub readdirs {
    my $basedir = shift;
#    $level = shift;
    my @dircontents = glob($basedir . '*');

    foreach $filename (@dircontents) {
	if (-d $filename) {    
#	    push (@htmlholder, "$filename <BR>\n");
	    &readdirs($filename . '/');
	} else {
	    $shortfilename = $filename;
	    $shortfilename =~ s/\/home\/chuwang\/public_html\/from_DTASelect\///g;
	    push (@htmlholder, "<a href=\"batch_annotate.pl?dset=$filename\">$shortfilename</FONT><BR>\n") if ($filename =~ /combined[^\/]*\.txt$/);
	}
    }

}

sub sum {
    $tempsum = 0;
    foreach (@_) {
	$tempsum += $_;
    }
    return $tempsum;
}



sub average {
    if (scalar @_ > 0) {
	return (&sum(@_) / (scalar @_));
    } else {
	return 0;
    }
}
