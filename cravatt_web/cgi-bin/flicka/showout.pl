#!/usr/local/bin/perl

#-------------------------------------
#	Web ShowOut,
#	(C)1999 Harvard University
#	
#	W. S. Lane/D. J. Weiner/B. L. Miller/Xianghui Liu
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# Created: 6/11/99 by David J. Weiner
# Last Modified: 3/11/03 By Xianghui Liu
# Show the sequest out file using the package SequestOut to read and parse the out file
###############################################

# find and read in standard include file
BEGIN{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}

use SequestOut;

Message->initialize($etcdir, $documentdir);

# set flag not to print out the error or warning messages on screen
Message->setPrintMsgToOutput(Message::OFF);

&MS_pages_header("Showout", "#871F78");

&cgi_receive;

## threshold values for some of the columns displayed:
$XCORR_THRESH = $DEFS_RUNSUMMARY{"XCorr threshold"};           # lower bound for bolding
$DELTACN_THRESH = $DEFS_RUNSUMMARY{"DeltaCN threshold"};         # lower bound for bolding
$SP_THRESH = $DEFS_RUNSUMMARY{"Sp threshold"};              # lower bound for bolding
$RSP_THRESH = $DEFS_RUNSUMMARY{"RSp threshold"};               # UPPER bound for bolding

my $outfile = $FORM{"OutFile"};

my $seqout = new SequestOut($outfile); # Create a SequestOut object 

$seqout->read_seqoutfile; # Read and parse the sequest out file

# Retrieve the out file information, and adjust the data for display
my $origfile = $seqout->get_origfilename;
if ($outfile =~ /^\s*.*:(.*)/) {
	$textfile = $1;
	$directory = $1 if ($textfile =~ /.*\/(.*)\/.*/);
}

my $runinfo = $seqout->get_runinfo;
my $rundate = $runinfo->{rundate};
$rundate =~ s/,//;
my $date =  $rundate . ", " . $runinfo->{runlengthsecs} . "s on " . $runinfo->{runmachine};

my $mhplus = $seqout->get_mhplus;
$mhplus =~ s/(\.\d\d).*/$1/;
my $srchtolerance = $seqout->get_srchtolerance;
$srchtolerance =~ s/(\.\d\d).*/$1/;
my $srchchgstate = $seqout->get_srchchgstate;
my $mhmass = $mhplus . " ±" . $srchtolerance . " (" . $srchchgstate . ")";

my $fragtolerance = $seqout->get_fragtolerance;
my $mass_type = $seqout->get_mass_type_parent . "/" . $seqout->get_mass_type_fragment;
my $useMono = 1 if ($mass_type =~ /MONO/i);

my $totalinten = $seqout->get_totalinten;
my $lowestsp = $seqout->get_lowestsp;

my $display = $seqout->get_display;
my $ionpercent = $seqout->get_ionpercent;
my $code = $seqout->get_code;

my $database = $seqout->get_database;
my $databasehdr = $seqout->get_databasehdr;
my $db = $1 if ($database =~ /.*[\\\/](.*)/);
$database .= ", $databasehdr" if ($databasehdr);

my $matchedpeptide = $seqout->get_nummatchedpeptides;
my $numaaorbases = $seqout->get_numaminoacids;

#If it is a nucleo type 
unless ($numaaorbases) {		
	$numaaorbases = $seqout->get_numbases ;
	$nucleo = 1;
}
my $base = $nucleo ? "Bases" : "Amino Acid";

my $numproteins = $seqout->get_numproteins;

my $ions = $seqout->get_ion_series;
my $ion_series = "$ions->{nlA} $ions->{nlB} $ions->{nlY} $seqout->{ion_series}->{ionA} $seqout->{ion_series}->{ionB} $seqout->{ion_series}->{ionC} $seqout->{ion_series}->{ionD} $seqout->{ion_series}->{ionV} $seqoutf->{ion_series}->{ionW} $seqout->{ion_series}->{ionX} $seqout->{ion_series}->{ionY} $seqout->{ion_series}->{ionZ}";

my $diffmods = $seqout->get_diffmods;
my @mods = ("*", "#", "@", "^", "+", "\$", "]", "[");

foreach $diffmod (@$diffmods) {
	my $symbol = $diffmod->{diffmodsymbol};
	my $value = $diffmod->{diffmodvalue};
	# Get the mod values
	my $i = 1;
	foreach $mod (@mods) {
		my $modnum = "mod" . $i;
		$i++;
		if ($symbol eq $mod) {
			$$modnum = $value;
			last;
		}
	}
	$diff_mods .= "($diffmod->{diffmodname}$symbol $value)";
}

my $addedmasses = $seqout->get_addedmasses;
my $staticmods = $addedmasses->{staticmods};
my $enzyme = $seqout->get_enzyme;

my $seqinfo = $seqout->get_sequestinfo;
my ($turboseq, $turboinfo) = split ',', $seqinfo;
my $creator = $seqout->get_creator;
my ($dep, $uni, $cre) = split ',', $creator;
my $license = $seqout->get_license;
my ($license, $div) = split ",", $license;
my $proteins = $seqout->get_proteins;
my @header = ("#", "Rank/Sp", "Id#", "MH+", "deltCn", "XCorr", "Sp", "Ions", "Reference", "()", "Sequence");

print <<HEADER; 
<HR WIDTH="100%">
<table  cellpadding=0 cellspacing=0 border=0 width=975>
<tr><td valign=top>
<table cellpadding=0 cellspacing=0 border=0>
<tr height=19>
	<td class=title nowrap>File:&nbsp&nbsp;</td>
	<td bgcolor="#f2f2f2"class="smallheading" style="color:red; cursor:hand" title="Click to open actual out file" onclick="window.open('$textfile','_blank')" nowrap>$origfile</td>
</tr>
<tr height=19>
	<td class="title" nowrap>Directory:&nbsp&nbsp;</td>
	<td class="data" nowrap>$directory</span></td>
</tr>
<tr height=19>
	<td class="title" nowrap>Date:&nbsp&nbsp;</td>
	<td class="data" nowrap>$date</td>
</tr>
<tr height=19>
	<td class="title" nowrap>MH+ Mass:&nbsp&nbsp;</td>
	<td class="data" nowrap>$mhmass</td>
</tr>
<tr height=19>
	<td nowrap class="title">&nbsp;Fragment Tol:&nbsp&nbsp;</td>
	<td nowrap class="data">$fragtolerance&nbsp;&nbsp;&nbsp;&nbsp;$mass_type</td>
</tr>
<tr height=19>
	<td nowrap class="title">Total Inten:&nbsp&nbsp;</td>
	<td bgcolor="#f2f2f2" nowrap><span class="smalltext">$totalinten</span>&nbsp;&nbsp;		
	<span class="smallheading">Lowest Sp:&nbsp&nbsp;</span><span class="smalltext">$lowestsp</span></td>
</tr>
<tr height=19>
	<td class="title" nowrap>Display:&nbsp&nbsp; </td>
	<td bgcolor="#f2f2f2" nowrap><span class="smalltext">$display&nbsp;&nbsp;&nbsp;&nbsp;</span>
	<span class="smallheading">Ion:&nbsp;&nbsp;</span><span class="smalltext">$ionpercent&nbsp;&nbsp;&nbsp;&nbsp;</span>
	<span class="smallheading">Code:&nbsp;&nbsp;</span><span class="smalltext">$code</span>&nbsp;</td>
</tr></table></td>
<td valign=top nowrap><table cellpadding=0 cellspacing=0 border=0>
<tr  height=19>
	<td class="title" nowrap>Database:&nbsp&nbsp;</td>
	<td class="data" nowrap>$database&nbsp;&nbsp;</td>
</tr>
<tr height=19>
	<td class="title" nowrap>Matched Peptide:&nbsp&nbsp;</td>
	<td class="data" nowrap>$matchedpeptide&nbsp;&nbsp;
	<span class="smallheading">$base:&nbsp&nbsp;</span><span class="smalltext" nowrap>$numaaorbases&nbsp;&nbsp;
	<span class="smallheading" nowrap>Proteins:&nbsp&nbsp;</span><span class="smalltext">$numproteins&nbsp;</span></td>
</tr>
<tr height=19>
	<td class="title" nowrap>&nbsp;nABY ABCDVWXYZ:&nbsp&nbsp;</td>
	<td class="data" nowrap>$ion_series</td>
</tr>
<tr height=19>
	<td class="title" nowrap>Diff Mods:&nbsp&nbsp;</td>
	<td class="data" width=300>$diff_mods</td>
</tr>
<tr height=19>
	<td class="title" nowrap>Static Mods:&nbsp&nbsp;</td>
	<td class="data">$staticmods</td>
</tr>
<tr height=19>
	<td class="title" nowrap>Enzyme:&nbsp&nbsp;</td>
	<td class="data" nowrap>$enzyme</td>
</tr>
<tr height=19 valign=bottom>
	<td colspan=2 align=center><span class="actbuttonover" title="Click to review the sequences against spectrum" onclick="javascript:openDTA_VCR()">&nbsp;DTA VCR&nbsp;</span>
   <form action="" name="DTAVCR" method="post">
   <INPUT TYPE=hidden name="DTAVCR:tempfile" value="">
   <INPUT TYPE=hidden NAME="DTAVCR:conserve_space" VALUE=1>
   <INPUT TYPE=hidden NANE="DTAVCR:display_eject" VALUE=1>
  </FORM>
</td></tr>
</table></td>
<td valign=top><table cellpadding=0 cellspacing=0 border=0 >
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$turboseq&nbsp;&nbsp;</td></tr>
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$turboinfo&nbsp;&nbsp;</td></tr>
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$dep&nbsp;&nbsp;</td></tr>
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$uni&nbsp;&nbsp;</td></tr>
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$cre&nbsp;&nbsp;</td></tr>
<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;$license&nbsp;</td></tr>

HEADER

print qq(<tr height=19><td bgcolor="#e8e8fa" align=center height=19 nowrap class="smalltext" style="color:#800080">&nbsp;&nbsp;$div&nbsp;&nbsp;</td></tr>) if ($div);

print <<EOF;
</table></td></tr></table>
<br style="font-size:5">
<table cellpadding=0 cellspacing=0 width=975 border=0>
<tr height=18>
EOF

my $infoheader = "<table cellpadding=0 cellspacing=0 width=900 border=0><tr>"; # prepare for DTA_VCR link
foreach $entry (@header){
	print qq(<td bgcolor='#0099cc' class='smallheading' align=center style='border-width:1px 1px 1px 0px;border-style:solid;color:#ffffff' bordercolorlight=#f2f2f2 bordercolordark=#999999>$entry</td>\n);
	$infoheader .= "<td class='smallheading'>$entry</td>" if ($entry ne "()");
}
$infoheader .= "</tr>";
print qq(</tr>);

foreach $protein (@$proteins) {
	my $number = $protein->{number};
	my $rank = $protein->{rank};
	my $sp1 = $protein->{sp};
	my $id = $protein->{id};
	my $mhplus = $protein->{MplusH_plus};
	my $deltcn = $protein->{deltcn};
	my $xcorr = $protein->{xcorr};
	my $sp2 = $protein->{sp2};
	my $ions = $protein->{ions};
	my $reference = $protein->{reference};
	my $moreref = $protein->{moreref};
	my $peptide = $protein->{peptide};
	my $description = $protein->{description};
	my $attachedproteins = $protein->{attachedproteins};

	my ($first, $sequence, $last) = split /\./, $peptide;
	my $pep = $sequence;
	my $site = $sequence;
	
	my @mods = ("\\\*", "\\\#", "\\\@", "\\\^", "\\\+", "\\\$", "\\\]", "\\\[");

	foreach $mod (@mods) {
		$pep =~ s/($mod)//g;
	}

	# preparation of ion link
	my $ionfile = $outfile;
	$ionfile =~ s/.out/.dta/;
	$ionurl = "$displayions?Dta=$ionfile&amp;MassType=$useMono&amp;NumAxis=1&amp;";
		 
	# handle masses in ion url
	if (defined $staticmods) { $ionurl .= "Mass$staticmods&amp;" }
	# handle all differential mods
	my $i = 1;
	foreach $mod (@mods) {
		my $modnum = "mod" . $i;
		if ($sequence =~ /($mod)/ && defined $$modnum) { $ionurl .= "DMass$i=$$modnum&amp;"; } 
		$site =~ s/(\w$mod)/$i/g;
		$i++;
	}
    $site =~ s/[a-zA-Z]/0/g;
	
	(my $ref) = $reference =~ /^([^\|]+\|[^\|]+)/;

    if ($site =~ /1/ || $site =~ /2/ || $site =~ /3/ || $site =~ /4/ || $site =~ /5/ || $site =~ /6/ || $site =~ /7/ || $site =~ /8/ ) { $ionurl .= "DSite=$site&amp;"; }
	$ionurl .= "Pep=$pep&amp;";

    # preparation of flicka link
	$sequrl = "$flicka?Dir=$directory&Ref=$ref&amp;Db=$dbdir/$db&amp;MassType=$useMono&amp;";	 
	if ($nucleo) { $sequrl .= "NucDb=1&amp;"; }        
	$sequrl .= "Pep=$pep";
		
	# preparation of more refs link 
	if ($moreref) {
	    $morerefsurl = "$morerefs?OutFile=" . &url_encode($outfile) . "&Ref=" . $ref . "&Peptide=" . $pep;
	} 

	# preparation of remote blast link
	$d = $db;
	$d =~ s!\.fasta!!;

	$ncbi = "$remoteblast?$sequence_param=$pep&";

	if (($d =~ m!dbEST!i) || ($d eq "est")) { $ncbi .= "$db_prg_aa_nuc_dbest"; }
	elsif ($d eq "nt") { $ncbi .= "$db_prg_aa_nuc_nr"; }
	elsif ($d =~ m!yeast!i) { $ncbi .= "$db_prg_aa_aa_yeast"; }
	else { $ncbi .= "$db_prg_aa_aa_nr"; }

	$ncbi .= "&$expect&$defaultblastoptions";
	
	# Bold the display for threshold values
	$sp1 = qq(<b>$sp1</b>)	if ($sp1 <= $RSP_THRESH);
	$deltcn = qq(<b>$deltcn</b>)	if ($deltcn <= $DELTACN_THRESH);	
	$xcorr = qq(<b>$xcorr</b>)	if ($xcorr >= $XCORR_THRESH);
	$sp2 = qq(<b>$sp</b>)	if ($sp >= $SP_THRESH);
	my $info =<<INFO;
<tr bgcolor=#f2f2f2><td><tt style="font-size:12">$number\.</tt></td>
	<td nowrap><tt style="font-size:12">$rank / $sp1</tt></td>
	<td nowrap><tt style="font-size:12">$id</tt></td>
	<td nowrap><tt style="font-size:12">$mhplus</tt></td>
	<td nowrap><tt style="font-size:12">$deltcn</tt></td>
	<td nowrap><tt style="font-size:12">$xcorr</tt></td>
	<td nowrap><tt style="font-size:12">$sp2</tt></td>
	<td nowrap><tt style="font-size:12"><a href="$ionurl" TARGET=_blank>$ions</a></tt></td>
	<td nowrap><tt style="font-size:12"><a href="$sequrl" TARGET=_blank>$reference</a></tt>
INFO
	print "$info" . "&nbsp;&nbsp;";

	if ($moreref) {
		print qq(<tt style="font-size:12"><a href="$morerefsurl" TARGET=_blank>$moreref</tt></a>\n);
		$expandcollapes++;
		print ("<img src=\"/images/tree_closed.gif\" id=\"expand_$expandcollapes\" onclick=\"javascript:toggleGroupDisplay(this)\" style=\"cursor:hand\" act=\"collapsed\">");
	}
	my $sequenceinfo = qq(</td>\n<td colspan=2 width=200><tt style="font-size:12"><a href="$ncbi" TARGET=_blank><nobr>($first)$sequence</nobr></tt></aa></td></tr>);
	$info .= $sequenceinfo;
	print "$sequenceinfo\n";
	print "<tr><td colspan=8>&nbsp;</td><td class=smalltext colspan=3 width=500>$description</td></tr>" if ($description);
	$info = $infoheader . $info . "</td></tr></table>";

	#######################################
	###	add DTA_VCR line
	push(@dtavcr_links, $ionurl);
	push(@dtavcr_info, $info);
	#######################################

	 if ($attachedproteins){
		print qq(\n<TBODY id=\"expand_$expandcollapes\_\" style="display:none">);

		foreach $attachedprotein (@$attachedproteins) {
			if ($color eq "#f2f2f2") {
				$color = "";
			} elsif ($color eq "") {
				$color = "#f2f2f2";
			}
			my $aid = $attachedprotein->{id};
			my $aref = $attachedprotein->{reference};
			my $ades = $attachedprotein->{description};
			(my $rref) = $aref =~ /^([^\|]+\|[^\|]+)/;


			# preparation of flicka link				
			$sequrl = "$flicka?Dir=$directory&Ref=$rref&amp;Db=$dbdir/$db&amp;MassType=$useMono&amp;";	 
		  	if ($nucleo) { $sequrl .= "NucDb=1&amp;"; }   
			$sequrl .= "Pep=$pep";

			print <<EOF;
<tr bgcolor=$color><td colspan=2>&nbsp;</td>
	<td><tt style="font-size:12">$aid</tt></td>
	<td colspan=5>&nbsp;</td>
	<td colspan=3><tt style="font-size:12"><a href="$sequrl" target=_blank>$aref</a> $ades</tt></td>
</tr>
EOF
		}
		print qq(</TBODY>);
	}
}
print "</table></form>";
&print_javascript;

print "</body></html>";

##########################################################
# print form and Javascript code to control DTA VCR window
sub print_javascript {

	# create a unique name for the dta_vcr window (includes both pid and start time of this Perl process)
	$dta_vcr_name = "dtavcr" . $$ . $^T;

	my $linkvalue = join("<DTAVCR>", @dtavcr_links);
	my $infovalue = join("<DTAVCR>", @dtavcr_info);
	
	foreach ($linkvalue, $infovalue) {
		s/\n/ /g;
	}
	
	$vcr_file = "$tempdir/$dta_vcr_name.txt";
	open(VCRFILE, ">$vcr_file");
	print VCRFILE "DTAVCR:link=$linkvalue\n";
	print VCRFILE "DTAVCR:info=$infovalue\n";
	close VCRFILE;

	print <<EOF;
<script language="Javascript">
<!--
	// declare reference to DTA-VCR window as a global variable
	var dta_vcr;
	function openDTA_VCR()
	{
		if (dta_vcr && !dta_vcr.closed) {

			dta_vcr.focus();

		} else {

			oldaction = document.DTAVCR.action;
			oldtarget = document.DTAVCR.target;

			document.DTAVCR.action="$webcgi/dta_vcr.pl";
			document.DTAVCR.target="$dta_vcr_name";

			self.onfocus = DTA_VCR_cleanup;
			
			document.DTAVCR["DTAVCR:tempfile"].value = "$vcr_file";
			dta_vcr = open("javascript:opener.document.DTAVCR.submit()","$dta_vcr_name","resizable");
			//mywindows.length++;
			//mywindows[mywindows.length-1] = dta_vcr;

		}

	}
	function DTA_VCR_cleanup()
	{
		// put things back as they were
		document.DTAVCR.action = oldaction;
		document.DTAVCR.target = oldtarget;
		self.onfocus = null;
	}
	function vcr_update_opener(idx)
	{
		if (!document.DTAVCR.selected)
			return;

		cousin = (document.DTAVCR.selected.length) ? document.DTAVCR.selected[idx] : document.DTAVCR.selected;
		if (dta_vcr.middleframe.infoframe.document.forms[0].selected)
			cousin.checked = dta_vcr.middleframe.infoframe.document.forms[0].selected.checked;
	}
	// this function is called by the vcr window itself when middle frame is updated
	function vcr_update_info(idx)
	{
		if (!document.DTAVCR.selected)
			return;

		cousin = (document.DTAVCR.selected.length) ? document.DTAVCR.selected[idx] : document.DTAVCR.selected;
		if (dta_vcr.middleframe.infoframe.document.forms[0].selected)
			dta_vcr.middleframe.infoframe.document.forms[0].selected.checked = cousin.checked;
	}

	function toggleGroupDisplay(toggleButton)
	{
		var groupSpanId = toggleButton.id + "_";
		var groupSpan = document.getElementById(groupSpanId);
    
		if (toggleButton.act == "collapsed") {
			toggleButton.src = "/images/tree_open.gif";
			groupSpan.style.display = "";
			toggleButton.act = "expanded";

		} else {
			toggleButton.src = "/images/tree_closed.gif";
			groupSpan.style.display = "none";
			toggleButton.act = "collapsed";
		}
	}


//-->
</script>
EOF
}
# end of dta_vcr_code #

# Error subroutine

sub error {

	print <<EOF;
<H3>Error:</H3>
<div>
@_
</div>
</body></html>
EOF

	exit 0;
}



