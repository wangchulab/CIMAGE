#!/usr/local/bin/perl

#-------------------------------------
#	PepStat,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# pepstats, a program for taking in a peptide sequence and outputting
# useful statistics on it

# quick changes by Martin 98/07/07 to allow multiple modifications

# big changes by Martin 98/07/29 to allow the use of the "Peptide" package
# seems pretty successful; next I will try to get PepCut to use the Peptide.pl package.


################################################
# find and read in standard include file
{
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
require "Peptide.pl";

&cgi_receive;

require "fastaidx_lib.pl"; # We need this for the database lookup

# Fill in default values into non-existing FORM variables
# set the database straight
if(exists $FORM{'database'}) {
	# Strip off path from database name
	($FORM{'database'}) = ($FORM{'database'} =~ m!([^/]+)$!);
} else {
	$FORM{'database'} = $DEFAULT_DB;
}

#formatting
if ($FORM{"frame"} == 1) { $FORM{'frame'} = "+1"; }
if ($FORM{"frame"} == 2) { $FORM{'frame'} = "+2"; }
if ($FORM{"frame"} == 3) { $FORM{'frame'} = "+3"; }

# get database type
$db = $FORM{'database'};
$path_to_db = "$dbdir/$db";
$is_nucleo = &get_dbtype("$path_to_db") if (-e $path_to_db);

# type_of_query
$type_of_query = $FORM{'type_of_query'};
$type_of_query = $DEFS_PEPSTAT{'Please enter protein'} if(!defined $type_of_query);
$type_of_query = 0 if ($type_of_query eq "sequence");
$type_of_query = 1 if ($type_of_query eq "identifier from indexed database");
$checked{"type_of_query=$type_of_query"} = ' CHECKED';

# cys_alkyl
$FORM{'cys_alkyl'} = $DEFS_PEPSTAT{'Cys Alkyl'} if(!exists $FORM{'cys_alkyl'});
$sel{"cys_alkyl=$FORM{'cys_alkyl'}"} = ' SELECTED';

# modifiedAA
$FORM{'modifiedAA'} = $DEFS_PEPSTAT{'Modified Amino Acids'} if(!exists $FORM{'modifiedAA'});
$sel{"modifiedAA=$FORM{'modifiedAA'}"} = ' SELECTED';

$sel{"frame=$FORM{'frame'}"} = ' SELECTED';

## debugging output
#print STDERR ("pepstat: caller is ", $ENV{"REMOTE_HOST"}, "\n");
#while (($k, $v) = each %FORM) { print STDERR ("pepstat:$k=$v.\n"); }

# the blue for sequence ion info
$seqcolor = "0000FF";

# the dark green for highlighting
$fontcolor = "#336699";

# leave off initial "<" and final ">" so we can put these variables in easily
$emphasis = qq(span class="smallheading");
$unemphasis = "/span";

$modstyle = qq(b><i><span style="color:blue" class="normaltimes");
$modstyleoff = "/span></i></b";

# the blue for the 1+,2+, and composition items
$compf = qq(span class=smallheading);
$uncompf = "/span";

$bfragwidth = "WIDTH=62";  # width of "b" columns in sequence ion info
$yfragwidth = "WIDTH=52";  # width of "y" columns in sequence ion info
$dwidth = "WIDTH=29";      # width of second and fourth "#" columns
$seqwidth = "WIDTH=50";      # width of second and fourth "Seq" columns

$modsHTML = qq(<span style="color:red"><b>);
$modsHTMLend = "</b></span>";
$running = $FORM{'running'};

# set protein according to query type. value = 1 means we have to look up

if ($running)
{
	&MS_pages_header ("PepStat", $fontcolor, $nocache, '<body onload="enableHideSeq()">');
	print"<hr>\n";
	&print_hide_script;
}
else
{
	&MS_pages_header ("PepStat", $fontcolor, $nocache);
	print"<hr>\n";
}

if(exists $FORM{'clear'})
{
	$seq = "";
} else{
	#we are checking if the sequence is a database identifier regardless of the query method
	#this enables us to do an automatic switch to db query if we have an identifier
	# Ask database -- based on etc/sequence_lookup.pl
	my $database = $FORM{"database"};
	my $seqid = $FORM{"peptide"};
	my @seq;

	$database=~s/\.fasta//g;
	$seqid = parseentryid($seqid);
	
	chdir($dbdir);

	
	
	if (-e $path_to_db){
		if (not &openidx($database)) {
		    if ($FORM{'type_of_query'}) {
				# we are specifically doing a db lookup so there is nothing to be done but fail 
				print ("<p><i>\nNo flatidx file was found for the $database.fasta database, please generate one before running Pepcut\n</i><p>");

				@text = ("Index $database.fasta", "Goto PepStat");
				@links = ("$fastaidx_web?running=ja&Database=$database.fasta", "$ourname");
				&WhatDoYouWantToDoNow(\@text, \@links);
				exit;
			}
		} else {
			(@seq) = lookupseq($seqid);
			&closeidx();
		}
	}

	if ($is_nucleo) {
		$transl_table = 1;
		$transl_name = &calculateTranslationTable($transl_table);
       
		if ($seq[0] =~ /^>/) 
		{
			$fasta_info = shift @seq;
			$fasta_info =~ s/^>*(.*)$/\1/i;
        }
		
		$frame = $FORM{"frame"};
	#	$rev_seq = &reverse_nuc ($seq);
		$dbseq = join "\n", @seq;
        $dbseq =~ s/\n//g;
		$dbseq =~ s/\s*//g;
		($dbseq) = &translate ($dbseq, $frame);
		
		$dbseq =~ s/<.*?>|\s//g;  # Strip HTML tags
	} else {
	
		$dbseq = join "\n", @seq;
	}
}

if ($FORM{'type_of_query'} or $dbseq)
{
	$seq = $dbseq;

	# Check for unsuccessful lookup if method is explicitly by DB
	if ($FORM{'type_of_query'} and (length $seq) == 0)
	{
		print ("Identifier not found in database $database.\n");
		exit;
	}
	
	#autoswitch to DB if needed
	$type_of_query = $FORM{'type_of_query'} = 1;
	$checked{"type_of_query=$type_of_query"} = ' CHECKED';
} else {
	$seq = $FORM{"peptide"};
}

# strip first line if in FASTA database format
$fasta_info = $1 if ($seq =~ s/^>(.*)\n//);

$seq =~ tr/a-z/A-Z/;
$seq =~ s/\s//g;


#check for errors when adding mass 
my @add_mass = split(',', $FORM{"addmass"});
my @mod_locations = split(',', $FORM{"modlocations"});

#if no mass addition specified do nothing even if modifications locations are specified
@mod_locations = () if (not defined $add_mass[0]);

#if no mod locations are specified do nothing even if mass addition(s) is specified
@add_mass = () if (not defined $mod_locations[0]);

my $addmass_error = 1 if (not ($#add_mass == $#mod_locations or $#add_mass == 0));


&output_form ($seq, $fasta_info, $addmass_error);

#now we strip all non-letter characters since computations should be based entirely on letter characters
#note that this is done after form is output. 
#This way the actual sequence shows up in the form field but we use a "clean" one for computations
$seq =~ s/\*//gi;   #strip stars without warning
if ($seq =~ s/[^A-Z]//gi)
{
	$warning = "<span style='color:red'>WARNING:&nbsp;Some non-letter characters have been removed from the sequence!!!</span>"
}

# No computation if there is no input
if($seq eq "") 
{
    exit();
}

if ($addmass_error)
{
	exit;
}


$pep = Peptide::new (	"cys_alkyl" => $FORM{"cys_alkyl"},
				"sequence" => $seq,
				"addmass" => $FORM{"addmass"},
				"modifiedAA" => $FORM{"modifiedAA"},
				"modlocations" => $FORM{"modlocations"}
			);

$pep->calc_all();

$len = $pep->{"length"};

if ($len == 0) {
	print "<B><span style=\"color:#FF0000\">Please enter a non-empty peptide</span></B>\n";
	exit;
}
&print_sample_info;
&print_buttons;
&print_characteristics ($pep);

&print_sequence ($pep, $fasta_info);


&print_mass_and_composition($pep);

$MWavg = $pep->get_MW ("average");
if ($MWavg >= $MAXWEIGHTtosplit) {
  print ("<p><li><span class=\"smalltext\">No sequence ions printed because average molecular weight is larger than $MAXWEIGHTtosplit.</span></li>");
} else {
  &print_seq_ions($pep);
}

&print_tail();
exit();

## this subroutine prints out the sequence and fasta info in a pretty way.
## First arg is Peptide object, second is possible FASTA info header

sub print_sequence {
  my ($pep, $fasta_info) = @_;
  my ($len) = $pep->{"length"};
  my ($i, $j);
  if (defined $fasta_info) {
	  print <<HEADER;
<tr height=5><td class=title></td><td></td></tr>
<tr><td class=title valign=top width=75>Header:&nbsp;</td>
	<td colspan=3 class=data width=655 height=19>&nbsp;$fasta_info</td>
</tr>
<tr height=5><td class=title></td><td></td></tr>
HEADER
  }
  print qq(</table><span id=seq><br style=font-size:8><tt class=small>);

  if ($len <= 30) {
    for ($i = 0; $i < $len; $i++) {
      if ($pep->{"addmass_array"}->[$i]) {
        print (qq(<span style="color:red"><b>), $pep->{"pep_array"}->[$i], "</b></span>");
      } else {
        print $pep->{"pep_array"}->[$i];
      }
    }

  } else {
    # break by tens
    $i = 0;
    while ($i < $len) {
      for ($j = $i; ($j < $i + 10) and ($j < $len); $j++) {
        if ($pep->{"addmass_array"}->[$j]) {
          print (qq(<span style="color:red"><b>), $pep->{"pep_array"}->[$j], "</b></span>");
        } else {
          print $pep->{"pep_array"}->[$j];
        }
      }
      $i += 10;
      print (($i % 90) ? " " : "<br>\n");
    }
  }
  print <<EOP;
	</TT><br style=font-size:5></span>
  <script>
	var sequence = document.all.seq.innerHTML;
  </script>
EOP
}

## this subroutine prints out the table of peptide-based characteristics,
## such as isoelectric point (pI), charge, and retention times.

sub print_characteristics {
  my ($pep) = shift;
  my $sep = "&nbsp;" x 5;
  my ($regRC, $ablotRC) = $pep->get_retention_times();
  my ($cys_alkyl, $cys_add) = $pep->get_cys_alkyl();
  my ($pI, $charge, $avg_res_mw, $length);

  $length = $pep->{"length"};
  $regRC = &precision ($regRC, 1);
  $ablotRC = &precision ($ablotRC, 1);
  $cys_add = &precision ($cys_add, 2);
  $pI = &precision ($pep->get_pI(), 2);

  $charge = $pep->get_charge();
  $avg_res_mw = &precision ($pep->get_MW ("Average") / $pep->{"length"}, 1);
  
  my $blanks = '&nbsp;' x 15;
  my $CELLWIDTH = $TABLEWIDTH / 6;
  print <<TABLE2;
<TR height=20><TD class=title>Length:&nbsp;</td><td class=smalltext colspan=3>&nbsp;$length$sep
	<span class=smallheading>Cys:&nbsp;</span><span class=smalltext>&nbsp;$cys_alkyl (+$cys_add)</span>$sep
	<span class=smallheading>pI:&nbsp;</span><span class=smalltext>&nbsp;$pI</span>$sep
	<span class=smallheading>Charge:&nbsp;</span><span class=smalltext>&nbsp;$charge</span>$sep
	<span class=smallheading>Avg Res MW:&nbsp;</span><span class=smalltext>&nbsp;$avg_res_mw&nbsp;</span>$sep
	<span class=smallheading>RT:&nbsp;</span><span class=smalltext>&nbsp;:$ablotRC</span></TD></tr>
TABLE2
}


## this subroutine prints out the table of MW, MH+, [M+2H]2+, etc. and the composition breakdown
sub print_mass_and_composition {
  my ($pep) = shift;
  my ($MWavg, $MWmono) = ($pep->get_MW ("average"), $pep->get_MW ("mono"));

  # this is a reference to a hash, indexed by three-letter names, of the AAs in the peptide:
  my ($composition) = $pep->get_composition_breakdown();
  my %resinfo;

  my (@M_over_z_avg, @M_over_z_mono, $i, $A, $M);
  my $chargenum = $MWavg / 400;
  $chargenum = 5 if $chargenum < 5;

  # calculate the mass/charge ratios
  for ($i = 1; $i <= $chargenum; $i++) {
    $A = ($MWavg / $i) + $Average_mass{"Hydrogen"};
    $M = ($MWmono / $i) + $Mono_mass{"Hydrogen"};

    $M_over_z_avg[$i] = &precision ($A, 2);
    $M_over_z_mono[$i] = &precision ($M, 3);
  }
  
  # prepare composition info:
  # we want to get output of the following:
  # Xxx:    1 (08.5)
  # It is right aligned, so we must add zeros and &nbsp; if necessary
  # Note that the precentage is count/length; it will NOT always
  # add up to 100%.
  foreach $res (values %Peptide::three_letter_names) {
    $resinfo{$res} = "<td class=smallheading align=right bgcolor=#f2f2f2 width=30>$res:</td>";
    $count = $composition->{$res};
    if ($count == 0) {
	 $resinfo{$res} .= "<td class=data width=70>&nbsp;</td>";
      next;
    }
    $ratio = &precision (100 * $count/$pep->{"length"}, 1, 2);
    $count = &precision ($count, 0, 4, "&nbsp;");
    $resinfo{$res} .= "<td class=data width=70>$count&nbsp;($ratio)</td>";
  }

  $MWavg = &precision ($MWavg, 2);
  $MWmono = &precision ($MWmono, 3);

print <<TABLE_3_DONE;
<br style=font-size:8>
<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width=730>
<TR>
	<TD valign=bottom><table cellpadding=0 cellspacing=0 border=0 width=300>
	<tr bgcolor=#e8e8fa><td width=60>&nbsp;</td>
	<TD class=smallheading align=center width=120>Avg&nbsp;</td>
	<TD class=smallheading width=120>Mono&nbsp;</td>
</tr>

<TR height=14 bgcolor=#f2f2f2>
<TD class=smallheading ALIGN=center>MW</td>
<TD class=smalltext align=center>$MWavg</TD>
<TD class=smalltext>$MWmono</TD>
</tr>

<tr height=5><td></td></tr>

<TR height=14 bgcolor=#e8e8fa>
<TD ALIGN=center class=smallheading>&nbsp;z</td>
<TD ALIGN=right class=smallheading>m/z</td>
<td></td>
</tr>
<tr><td colspan=3 class=outline><div style='height:87; overflow:auto'>
<table cellpadding=0 cellspacing=0 border=0 width=300>
	
TABLE_3_DONE
	
for ($i = 1; $i <= $chargenum; $i++) {
print <<MZMASS;
<TR bgcolor=#f2f2f2>
<TD ALIGN=center width=60><$compf>$i<$uncompf><tt><sup>+</sup></tt></TD>
<TD class=smalltext align=center width=120>$M_over_z_avg[$i]</TD>
<TD class=smalltext>$M_over_z_mono[$i]</TD>
</tr>
MZMASS
}
print <<TABLE_3_DONE;
</div>
</td></tr></table></td></tr>

</table></td>
<td>&nbsp;</td>
<td valign=top align=right width=400>
<table cellpadding=0 cellspacing=0 border=0 width=400 style="border:solid #e4e4e4 1px;">
<tr height=20><td class=smallheading bgcolor=#e8e8fa colspan=8>&nbsp;&nbsp;Composition</td></tr>
<tr height=19 bgcolor=#f2f2f2>$resinfo{"Asp"}
$resinfo{"His"}
$resinfo{"Ile"}
$resinfo{"Asn"}
</TR>

<tr height=19 bgcolor=#f2f2f2>
$resinfo{"Arg"}
$resinfo{"Leu"}
$resinfo{"Glu"}
$resinfo{"Thr"}
</TR>

<tr height=19 bgcolor=#f2f2f2>
$resinfo{"Phe"}
$resinfo{"Gln"}
$resinfo{"Ala"}
$resinfo{"Lys"}
</TR>

<tr height=19 bgcolor=#f2f2f2>
$resinfo{"Asx"}
$resinfo{"Pro"}
$resinfo{"Trp"}
$resinfo{"Glx"}
</TR>

<tr height=19 bgcolor=#f2f2f2>
$resinfo{"Tyr"}
$resinfo{"Cys"}
$resinfo{"Ser"}
$resinfo{"Val"}
</TR>

<tr height=19 bgcolor=#f2f2f2>
$resinfo{"Lxx"}
$resinfo{"Gly"}
$resinfo{"Met"}
$resinfo{"Unk"}
</TR>
<tr height=3 bgcolor=#f2f2f2><td colspan=8></td></tr>
</TABLE>
</td></tr></table>

TABLE_3_DONE

} # end of &print_mass_and_composition()


## this subroutine prints out the table of sequence ions (b and y ions for mono, average, and 2+ average)
## for the peptide. It uses the variables "$bfragwidth" and "$yfragwidth" defined at the top of the script

sub print_seq_ions {
  my ($pep) = shift;
  my ($i, $len, $k, $I, $K, $res, $top, $bottom);
  my ($avg) = $pep->get_masses ("average"); # average mass info
  my ($mono) = $pep->get_masses ("mono"); # monoisotopic mass info

  my ($block);

  $block = <<BLOCKDONE;
<TD class=smallheading style=color:#ffffff $dwidth align=center>#</TD>
<TD class=smallheading $bfragwidth style=color:#ffffff align=center>b</TD>
<TD  class=smallheading $yfragwidth style=color:#ffffff align=center>y</TD>
BLOCKDONE

  print <<TABLEDONE;
<br style=font-size:8>
<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=1 width=730 bordercolor=#ffffff>
<TR height=18 bgcolor=#e8e8fa>
<TD width=240><$emphasis>&nbsp;&nbsp;Sequence Ions:&nbsp;&nbsp;Avg 1+<$unemphasis></TD>
<TD width=240 align=center><$emphasis>Mono 1+<$unemphasis></TD>
<TD width=240 align=center><$emphasis>Avg 2+<$unemphasis></TD>
</TR>
</table>
<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=1 width=730  bgcolor=#0099cc bordercolorlight=#f2f2f2 bordercolordark=#999999>
<TR ALIGN=CENTER height=15>
TABLEDONE

  print qq(<TD class=smallheading align=center $seqwidth style='color:#FFFFFF'>Seq</TD>\n);
  print $block;
  print qq(<TD $dwidth class=smallheading style='color:#FFFFFF'>&nbsp;#</TD>\n);

  print qq(<TD class=smallheading align=center $seqwidth style='color:#FFFFFF'>Seq</TD>\n);
  print $block;
  print qq(<TD $dwidth class=smallheading style='color:#FFFFFF'>&nbsp;#</TD>\n);


  print qq(<TD class=smallheading style='color:#FFFFFF' $seqwidth align=center>Seq</TD>\n);
  print $block;
  print qq(<TD $dwidth class=smallheading style='color:#FFFFFF' align=center>#</TD>\n);

  print ("</TR></table><TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width=730>\n\n");

  my ($bavg) = $avg->{"b_ions"};
  my ($yavg) = $avg->{"y_ions"};
  my ($bmono) = $mono->{"b_ions"};
  my ($ymono) = $mono->{"y_ions"};

  $len = $pep->{"length"};

  for ($i = 0; $i < $len; $i++) {
	$myline++;
	my $color = "#f2f2f2" if ($myline % 2 == 0);
    if ($pep->{"addmass_array"}->[$i]) {
      $HTML = $modsHTML;
      $HTMLend = $modsHTMLend;
    } else {
      $HTML = qq(<span style="color:#$seqcolor">);
      $HTMLend = "</span>";
    }

    $k = $len - $i;
    $I = &precision ($i + 1, 0, 2, "&nbsp;");
    $K = &precision ($k, 0, 2, "&nbsp;");

    $res = $pep->{"pep_array"}->[$i];

    $bottom = qq(<TD class=smalltext $dwidth ALIGN=center>$HTML$K$HTMLend</TD>\n);

    print ("<TR ALIGN=CENTER height=16 bgcolor=$color >\n");
    print qq(<TD class=smalltext $seqwidth>&nbsp;&nbsp;$HTML$res$HTMLend</TD>\n<TD class=smalltext $dwidth align=center>$HTML$I$HTMLend</TD>\n);
    print ("<TD ALIGN=LEFT class=smalltext $bfragwidth>", &precision ($bavg->[$i], 1, 6, "&nbsp;"), "</TD>\n");
    print ("<TD ALIGN=LEFT class=smalltext $yfragwidth>", &precision ($yavg->[$i], 1, 5, "&nbsp;"), "</TD>\n");
    print $bottom;


    print qq(<TD class=smalltext $seqwidth>&nbsp;&nbsp;$HTML$res&nbsp;$HTMLend</TD>\n<TD class=smalltext $dwidth align=center>$HTML$I$HTMLend</TD>\n);
    print ("<TD ALIGN=LEFT class=smalltext $bfragwidth>", &precision ($bmono->[$i], 1, 6, "&nbsp;"), "</TD>\n");
    print ("<TD ALIGN=LEFT class=smalltext $yfragwidth>", &precision ($ymono->[$i], 1, 5, "&nbsp;"), "</TD>\n");
    print $bottom;


    print qq(<TD class=smalltext $seqwidth>&nbsp;&nbsp;$HTML$res&nbsp;$HTMLend</TD>\n<TD  class=smalltext $dwidth align=center>$HTML$I$HTMLend</TD>\n);
    print ("<TD ALIGN=LEFT class=smalltext $bfragwidth>", &precision ( ($bavg->[$i] + $Average_mass{"Hydrogen"}) /2, 1, 6, "&nbsp;" ), "</TD>\n");
    print ("<TD ALIGN=LEFT class=smalltext $yfragwidth>", &precision ( ($yavg->[$i] + $Average_mass{"Hydrogen"}) /2, 1, 5, "&nbsp;" ), "</TD>\n");
    print qq(<TD class=smalltext $dwidth align=center>$HTML$K$HTMLend</TD>\n);
    print ("</TR>\n\n");
  }
  print ("</TABLE>\n");
}

sub print_tail {
  my ($addmass, $matchedlocs) = $pep->get_addmass_info();
  print "<li><span class=smalltext>$warning</span></li>\n" if ($warning);
  print qq(<li><span class=smalltext>The retention coefficients do not take modifications into consideration.</span></li>\n);

  if ($addmass) {
    print (qq(<li><span style="color:blue" class="smalltext">Modification of $addmass amu at residue(s): ),
           join (", ", @$matchedlocs), "</span></li>\n");
  }

  print ("</BODY>\n</HTML>\n");
}

sub output_form {
  my ($peptide, $fasta_info, $addmass_error) = @_;
  my $addmass = $FORM{"addmass"};
  my $modtype = $FORM{"modifiedAA"};
  my $modlocations = $FORM{"modlocations"};
  my $cys_alkyl = $FORM{"cys_alkyl"};
 
  # list of amino acids for the Mod: dropbox
  my @aa = ('A', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'K', 'L',
	    'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'Y');

  if (defined $fasta_info) 
  {
	$fasta_info=~ s/\r//g;
    $peptide = "&gt;$fasta_info\n" . $peptide;
  }
  if ($FORM{"clear"}) {
    $addmass = "";
    $modtype = "by Res#";
    $modlocations = "";
    $peptide = "";
  }

  print <<EOFORM1;
<FORM name=mainform ACTION="$ourname" METHOD=post style="margin-top:5; margin-bottom:5">
<input type=hidden name=running value=1>
<table cellspacing=0 cellpadding=0 border=0 width=730>
<TR height=28>
	<TD bgcolor=#e8e8fa nowrap>
		<span class=smallheading>&nbsp;&nbsp;Enter protein&nbsp;&nbsp;</span>
		<INPUT TYPE=RADIO NAME="type_of_query" VALUE=0$checked{"type_of_query=0"}>
		<span class=smallheading>sequence&nbsp;</span>
		<INPUT TYPE=RADIO NAME="type_of_query" VALUE=1$checked{"type_of_query=1"}>
		<span class=smallheading>identifier&nbsp;from&nbsp;db:&nbsp;</span>
EOFORM1

# The following based on sequence_lookup.pl
&get_dbases;

# make dropbox:
&make_dropbox ("database", $FORM{'database'}, @ordered_db_names);

  print <<EOFORM1;
		<span class=smallheading>&nbsp;&nbsp;Frame:&nbsp;
		<SPAN CLASS="dropbox"><SELECT NAME="frame">
EOFORM1

  foreach $value ('+1', '+2', '+3', '-1', '-2', '-3') 
  {
		print <<OPT;
		<OPTION $sel{"frame=$value"}>$value
OPT
  }


print <<EOFORM1;
		</SELECT></SPAN>&nbsp;&nbsp;
	</TD>
</TR>
<tr><td style="font-size:3" bgcolor=#f2f2f2>&nbsp;</td></tr>
<TR>
<TD bgcolor=#f2f2f2 align=center>
	<tt><TEXTAREA class=outline WRAP=VIRTUAL ROWS=4 COLS=86 NAME="peptide">$peptide</TEXTAREA></tt>
</TD>
</TR>
<tr><td style="font-size:3" bgcolor=#f2f2f2>&nbsp;</td></tr>
<TR><TD HEIGHT=10>&nbsp;</TD></TR>
<TR>
<TD>
	<TABLE cellspacing=0 cellpadding=0 border=0 width=100%>
	<TR>
		<TD>
			<INPUT TYPE="SUBMIT" CLASS="outlinebutton button" style="cursor:hand" VALUE="Get stats">
		</TD>
		<TD>
			<span id="clear" CLASS="actbuttonover" style="width=55" onClick="document.forms[0].running.value = 0; submit();">Clear</span>
		</TD>
		<TD align=right>
			<span class=smallheading>Cys:&nbsp;</span>
		</TD>
		<TD>
			<SPAN CLASS="dropbox"><SELECT NAME="cys_alkyl">
EOFORM1

  foreach $val (@cys_alkyl_array) 
  {
		print <<OPT;
			<OPTION $sel{"cys_alkyl=$val"}>$val
OPT
  }
  print <<EOP;
			</SELECT></SPAN>
		</TD>
		<TD align=right>
			<span class=smallheading>Add Mass:&nbsp;</span>
		</TD>
		<TD>
			<INPUT NAME="addmass" VALUE="$addmass" SIZE=10>
		</TD>
		<TD>
			<SPAN CLASS="dropbox"><SELECT NAME="modifiedAA">
EOP

  foreach $value ("At Res# :", @aa)
  {
		print <<OPT;
			<option $sel{"modifiedAA=$value"}>$value
OPT
  }

  my $last_width= ' width=1' if (!$running);

  print <<EOFORM2;
			</SELECT></SPAN>
		</TD>
		<TD$last_width>
			<INPUT NAME="modlocations" VALUE="$modlocations" SIZE=10>
		</TD>

EOFORM2

	if ($running)
	{
		print <<EOP;
		<TD width=1>
			<span id=hide_opt></span>
		</TD>
EOP
	}
  print <<EOFORM2;
	</TR>
	</TABLE>
</TD>
</TR>
</TABLE>
EOFORM2

if ($addmass_error)
{
	print <<ERR;
	<BR>
	<B><span style="color:FF0000">ERROR: Multiple add masses require an equal number of Res#</span></B>
	<BR>
ERR
}

print <<EOFORM2;
</FORM>
<hr>

EOFORM2

}

# borrowed from sequest_launcher: gets database type.
sub get_dbtype {
  my ($db) = $_[0];
  my ($line, $numchars, $numnucs, $numlines);

  open (DB, "$db") || die "Could not open database $db for auto-detecting database type.";
  while ($line = <DB>) {
    next if ($line =~ m!^>!);

    chomp $line;
    $numchars += length ($line);
    $numnucs += $line =~ tr/ACTG/ACTG/;

    $numlines++;
    last if ($numlines >= 500);
  }
  close DB;

  return (1) if ($numnucs > .8 * $numchars);

  return (0);
}
 
sub print_hide_script()
{
	print <<SCRIPT;
<script language="JavaScript">
	var now = 'shown';
	function hideSeq()
	{
		if (now == 'shown')
		{
			document.all.seq.innerHTML = '';
			now = 'hidden';
			document.all.hide_button.innerText = 'Show Seq';
			document.all.hide_button.title = 'Show sequence';
		}
		else
		{
			document.all.seq.innerHTML = sequence;
			now = 'shown';
			document.all.hide_button.innerText = 'Hide Seq';
			document.all.hide_button.title = 'Hide sequence';
		}
		
	}
	
	function enableHideSeq()
	{
		if (isIE)
		{
			if (document.all.hide_opt) {
				document.all.hide_opt.innerHTML = '<span class="actbuttonover" id="hide_button"  title="Hide Sequence" style="width=60" onClick="hideSeq()">Hide Seq</span>';
			}
		}
	}
				
</script>
SCRIPT
}

#copied from flicka.pl
sub print_buttons {
	my $ncbi_type = "p";
    my $type = $FORM{"type_of_query"};

	#if a database query pass only first 15 chars of identifier
	my $ref = $type == 1? substr($fasta_info,0, 15) : url_encode($FORM{'peptide'});
	my $temp = $ref;
	my $dir_query = "&Dir=" . url_encode($FORM{'Dir'}) if (defined $FORM{'Dir'});
	my $frame_query = "";
	my $frame_query1 = "";
	
    if ($is_nucleo) { 
		$ncbi_type = "n";
		$frame_query = "&frame=$frame";
		$frame_query1 = "&frame1=$frame";
	}
	$searchstrings = url_encode($FORM{"searchseq"});

	# DJW moved sendto buttons 7/22.  
	

    print <<EOM;
	<tr height=22><td class=title>Send To:&nbsp;</td><td class=smalltext>&nbsp;
	<nobr>
	<span class="actbuttonover" style="width=55" onclick="window.open('$pepcut?mode=backlink_run&type_of_query=$type&database=$db&query=$ref&searchseq=$searchstrings$frame_query$dir_query&MassType=$FORM{'MassType'}&disp_sequence=yes', '_blank')">PepCut</span>
EOM

	# print link to GAP
	print <<EOM;
	<span class="actbuttonover" style="width=55" onclick="window.open('$gap?type_of_query1=$type&database1=$db&peptide1=$ref$frame_query1$dir_query', '_blank')">Gap</span>
    <!--<form action="$remoteblast" name=blast method=post>-->
EOM

	#print blast link
my $d = $db;
$d =~ s!\.fasta!!;

$ncbi = "$remoteblast?$sequence_param=$seq&";

if (($d =~ m!dbEST!i) || ($d eq "est")) { $ncbi .= "$db_prg_aa_nuc_dbest"; }
elsif ($d eq "nt") { $ncbi .= "$db_prg_aa_nuc_nr"; }
elsif ($d =~ m!yeast!i) { $ncbi .= "$db_prg_aa_aa_yeast"; }
else { $ncbi .= "$db_prg_aa_aa_nr"; }

$ncbi.= ($ncbi_type eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type);

$ncbi .= "&$expect&$defaultblastoptions";

print qq(<span class="actbuttonover" style="width=55" onclick="window.open('$ncbi', '_blank')">Blast</span>);

$ref = $temp;

  # if reference is from ncbi then show links to Entrez
  if ($ref =~/gi\|/) 
  {
	  $ref =~ /^gi\|(\d*)/;
	  my $myref = $1;

	  print <<EOM;
	<span class="actbuttonover" style="width=58" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=f', '_blank')">Sequence</span>
	<span class="actbuttonover" style="width=55" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=m', '_blank')">Abstract</span>
EOM
	}
print "</nobr></td></tr>";

}

sub print_sample_info
{	
	print qq(<br style=font-size:5><table cellpadding=0 cellspacing=0 border=0 width=730 style="border:solid #e4e4e4 1px;">\n);
	if (defined $FORM{'Dir'})
	{	
		my %dir_info = &get_dir_attribs($FORM{'Dir'});
		print <<INFO;
	<tr height=20><td class=title width=75>Sample:&nbsp;</td>
		<td class=smalltext nowrap width=380>&nbsp;$dir_info{'LastName'},&nbsp;$dir_info{'Initial'}.&nbsp;&nbsp;$dir_info{'Sample'}&nbsp;&nbsp;$dir_info{'SampleID'}&nbsp;&nbsp;</td>
		<td class=title width=75>&nbspDirectory:&nbsp;</td>
		<td class=smalltext width=200>&nbsp;$FORM{'Dir'}</td>
	</tr>
INFO
	}
	if ($FORM{'type_of_query'} eq "1" && defined $db) {
		print <<INFO;
	<tr height=20>
		<td class=title width=75>&nbspReference:&nbsp;</td>
		<td class=smalltext width=380>&nbsp;$FORM{'peptide'}</td>
		<td class=title width=75>Database:&nbsp;</td>
		<td class=smalltext width=200>&nbsp;$db</td>
	</tr>
INFO
	}
}