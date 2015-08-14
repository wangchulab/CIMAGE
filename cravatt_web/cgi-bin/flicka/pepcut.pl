#!/usr/local/bin/perl

#-------------------------------------
#	PepCut,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/Georgi Matev
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# Called "PepCut", takes a peptide and a cleavage enzyme and outputs
# the theoretical resulting peptides.

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
	require "microchem_var.pl";
	require "interfaces_include.pl";
	require "html_include.pl";
}
################################################
&cgi_receive;

$ENZYME_FILE = $ENZYME_DEFAULTS;
$MAX_ENZYMES = 17;

$CELLBGCOLOR = '#f2f2f2';
$TITLEBGCOLOR = '#e8e8fa';
# Added by Ulas 10/22/98 to define constants (based on ionquest.pl)
# $sel variables work this way:
# if something is selected, $sel{"$name_of_form_variable=$value_of_selected_form_variable"} is
# equal to " SELECTED"
# Similarly, with $checked. If it is on, the value is "on" (although it may not be specified in the form)
# default settings may be edited in microchem_var.pl
#
# Now we have two modes of running: make_form, run and backlink_run. These are specified in the "mode" variable.

$FORM{'mode'} = 'make_form' if(!exists $FORM{'mode'});

#formatting
if ($FORM{"frame"} == 1) { $FORM{'frame'} = "+1"; }
if ($FORM{"frame"} == 2) { $FORM{'frame'} = "+2"; }
if ($FORM{"frame"} == 3) { $FORM{'frame'} = "+3"; }


$DEF_TYPE_OF_QUERY = $DEFS_PEPCUT{'Please enter protein'};
$DEF_TYPE_OF_QUERY = 0 if ($DEF_TYPE_OF_QUERY eq "sequence");
$DEF_TYPE_OF_QUERY = 1 if ($DEF_TYPE_OF_QUERY eq "identifier from indexed database");
$FORM{'type_of_query'} = $DEF_TYPE_OF_QUERY if(!exists $FORM{'type_of_query'});
$checked{"type_of_query=$FORM{'type_of_query'}"} = ' CHECKED';

$DEF_DATABASE = $DEFAULT_DB;
if(exists $FORM{'database'}) {
	# Strip off path from database name
	($FORM{'database'}) = ($FORM{'database'} =~ m!([^/]+)$!);
} else {
	$FORM{'database'} = $DEF_DATABASE;
}

$db = $FORM{'database'};
$path_to_db = "$dbdir/$db";
$is_nucleo = &get_dbtype("$path_to_db") if (-e $path_to_db);

$DEF_ENZYME = $DEFS_PEPCUT{'Enzyme'};

$FORM{'Enzyme'} = $DEF_ENZYME if(!exists $FORM{'Enzyme'});
$sel{"enzyme=$FORM{'Enzyme'}"} = ' SELECTED';

$DEF_ORDER = lc($DEFS_PEPCUT{'Sort'});
$DEF_ORDER = "retengraph" if ($DEF_ORDER eq "&nbsp;omatogram");
$FORM{'order'} = $DEF_ORDER if(!exists $FORM{'order'}); 
$checked{"order=$FORM{'order'}"} = ' CHECKED';

$FORM{'minmass'} = 0 if ($FORM{'minmass'} == '');
$FORM{'maxmass'} = 0 if ($FORM{'maxmass'} == '');

$DEF_CHARGES = $DEFS_PEPCUT{'Charges'};
$FORM{'charges'} = $DEF_CHARGES if(!exists $FORM{'charges'}); 
$checked{"charges=$FORM{'charges'}"} = ' CHECKED';

$DEF_DIRECTION = lc($DEFS_PEPCUT{'Decreasing/Increasing'});
$FORM{'direction'} = $DEF_DIRECTION if(!exists $FORM{'direction'}); 
$checked{"direction=$FORM{'direction'}"} = ' CHECKED';

$DEF_MASSTYPE = $DEFS_PEPCUT{'Mass Type'};
$DEF_MASSTYPE = 0 if ($DEF_MASSTYPE eq "Avg");
$DEF_MASSTYPE = 1 if ($DEF_MASSTYPE eq "Mono");
$FORM{'MassType'} = $DEF_MASSTYPE if(!exists $FORM{'MassType'});
$checked{"MassType=$FORM{'MassType'}"} = ' CHECKED';

$DEF_CYS_ALKYL = $DEFS_PEPCUT{'Cys Alkyl'};
$FORM{'cys_alkyl'} = $DEF_CYS_ALKYL if(!exists $FORM{'cys_alkyl'});
$sel{"cys_alkyl=$FORM{'cys_alkyl'}"} = ' SELECTED';

#$FORM{'disp_sequence'} = ($DEFS_PEPCUT{'Sequence'} eq 'yes') if(!exists $FORM{'disp_sequence'} && $FORM{'mode'} ne 'saveState');
if ($FORM{'mode'} ne 'save_state') {
	$checked{"disp_sequence"} = $DEFS_PEPCUT{'Sequence'} eq 'yes' ? ' CHECKED' : '';
}
else {
	$checked{"disp_sequence"} = $FORM{'disp_sequence'} ? ' CHECKED' : '';
}

$FORM{'partials'} = ($DEFS_PEPCUT{'Partials'} eq 'yes') if (!exists $FORM{'partials'} && $FORM{'mode'} ne 'save_state');
$checked{"partials"} = $FORM{'partials'} ? ' CHECKED' : '';

$FORM{'disp_unmodified'} = ($DEFS_PEPCUT{'Unmodified'} eq 'yes') if (!exists $FORM{'disp_unmodified'} && $FORM{'mode'} ne 'save_state');
$checked{'disp_unmodified'} = $FORM{'disp_unmodified'} ? ' CHECKED' : '';

$FORM{'methionine'} = ($DEFS_PEPCUT{'Oxidized Methionines'} eq 'yes') if (!exists $FORM{'methionine'} && $FORM{'mode'} ne 'save_state');
$checked{'methionine'} = $FORM{'methionine'} ? ' CHECKED' : '';


$DEF_TOLERANCE = $DEFS_PEPCUT{'+/-'};
$FORM{'tolerance'} = $DEF_TOLERANCE if(!exists $FORM{'tolerance'});
$sel{"tolerance=$FORM{'tolerance'}"} = ' SELECTED';

$sel{"frame=$FORM{'frame'}"} = ' SELECTED';

# Added by Ulas 10/16/98 to enable fasta sequence lookups (see processing of type_of_query)
require "fastaidx_lib.pl";

#get enzyme info
open ENZYME_FILE or die "Can't open enzyme file $ENZYME_FILE $!\n";
<ENZYME_FILE>; #discard first line
while ($line = <ENZYME_FILE>)
{
    ($a, $offset, $sites, $nonsites) = split (' ', $line);
	push @enzymes, $a;
    $sites{$a} = $sites;
    $nonsites{$a} = $nonsites;
    $offset{$a} = $offset;
}
close ENZYME_FILE;


if ($FORM{'query'} && !$FORM{'saveState'})
{
	&MS_pages_header ("PepCut", "#336699", '<body onLoad="enableHideSeq()">');
	print"<hr>\n";
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
			if (document.all.hide_opt)
				document.all.hide_opt.innerHTML = '<span class="actbuttonover" id="hide_button" title="Hide Sequence" style="width=60"  onClick="hideSeq()">Hide Seq</span>&nbsp;&nbsp;&nbsp;';
		}
	}
			
</script>
SCRIPT
}
else
{
	&MS_pages_header ("PepCut", "#336699");
	print "<hr>\n";
}

#while (($key, $val) = each %FORM) { print STDERR ("$key=$val\n");}

# Added by Ulas 10/19/98: prints greeting page if first time in page
# save_state mode added by Georgi to deal with form field caching issues
if ($FORM{"mode"} eq "make_form" || $FORM{"mode"} eq "save_state") {
	&output_form;
	exit 0;
}

if (defined $FORM{"saveDefaults"})
{
	&save_enzyme_info;
	exit 0;
}


# width and height of images
$HSIZE = 725;
$VSIZE = 500;

##
## if you turn off underlining in $matchHTML, comment out the lines
## "$underlined++" and "$underlined--" in &pretty_print
##
## KEEP THE FOLLOWING IN lowerCASE

$matchHTML = qq(<span style="color:red; text-decoration:underline">); # peptide matches
$matchHTMLend = "</span>";

$siteHTML = qq(<span style="color:#ff8000">);
$siteHTMLend = "</span>";

$addmassHTML = qq(<b><span style="color:#ff00ff; text-decoration:underline">);
$addmassHTMLend = "</span></b>";

$trimHTML= qq(<span style="color:#c0c0c0">); # a light grey
$trimHTMLend = "</span>";

$nxsORtHTML = qq(<span style="color:#0099cc; text-decoration:underline; font-weight:bold">);
$nxsORtHTMLend = "</span>";

$multipleTAG = qq(<span style="color:#0099cc">+</span>);


#commented out by Georgi 07/01/2000

#
# process all the %FORM values
#


#we are checking if the sequence is a database identifier regardless of the query method
#this enables us to do an automatic switch to db query if we have an identifier
# Ask database -- based on etc/sequence_lookup.pl
my $database=$FORM{"database"};
my $seqid = $FORM{"query"};
my @seq;

$database=~s/\.fasta//g;
$seqid = parseentryid($seqid);

chdir($dbdir);


if (not &openidx($database)) {
    if ($FORM{'type_of_query'}) {
		# we are specifically doing a db lookup so there is nothing to be done but fail 
		print ("<p><i>\nNo flatidx file was found for the $database.fasta database, please generate one before running Pepcut\n</i><p>");

		@text = ("Index $database.fasta", "Goto PepCut");
		@links = ("$fastaidx_web?running=ja&Database=$database.fasta", "$ourname");
		&WhatDoYouWantToDoNow(\@text, \@links);
		exit;
	}
} else {
	(@seq) = lookupseq($seqid);
	&closeidx();
}

if ($is_nucleo) 
{
    $transl_table = 1;
	$transl_name = &calculateTranslationTable($transl_table);
       
	if ($seq[0] =~ /^>/) 
	{
		$fasta_info = shift @seq;
		$fasta_info =~ s/^>*(.*)$/\1/i;
    }
		
	$frame = $FORM{"frame"};
	$DBprotein = join "\n", @seq;
    $DBprotein =~ s/\n//g;
	$DBprotein =~ s/\s*//g;
	($DBprotein) = &translate ($DBprotein, $frame);
		
	$DBprotein =~ s/<.*?>|\s//g;  # Strip HTML tags   
}else{
	
	$DBprotein = join "\n", @seq;
}

if ($FORM{'type_of_query'} or $DBprotein)
{
	$protein = $DBprotein;

	# Check for unsuccessful lookup if method is explicitly by DB
	if ($FORM{'type_of_query'} and (length $protein) == 0)
	{
		print ("Identifier not found in database $database.\n");
		exit;
	}
	
	#autoswitch to DB if needed
	$type_of_query = $FORM{'type_of_query'} = 1;
	$checked{"type_of_query=$type_of_query"} = ' CHECKED';
} else {
	$protein = $FORM{"query"};
}

$protein =~ s/^\s+//;
# strip first line if in FASTA database format
$fasta_info = $1 if ($protein =~ s/^>(.*)\n//);

$protein =~ tr/a-z/A-Z/;
$protein =~ tr/A-Z*@//dc;

## if $Iwantcharges is true, we use less space for the peptides
## and output mass/charge ratios for charges of 1 to 5.

$Iwantcharges = ($FORM{"charges"} eq 'm/z');
if ($Iwantcharges) {
    $masssearch = $FORM{"searchmass"};
    $tolerance = $FORM{"tolerance"};
}

if ($FORM{"MassType"}) {
  $MassType = "Mono";
} else {
  $MassType = "Average";
}

$enzyme = $FORM{"Enzyme"};
#update hashes since enzyme might be edited

$sites{$enzyme} = $FORM{"sites"} if (exists $FORM{"sites"});
$nonsites{$enzyme} = $FORM{"nosites"} if (exists $FORM{"nosites"});
$offset{$enzyme} = $FORM{"offset"} if (exists $FORM{"offset"});

$cys_alkyl = $FORM{"cys_alkyl"};
$cys_alkyl = $default_cys if ((!exists $cys_alkyl_add_mono{$cys_alkyl}) or (!exists $cys_alkyl_add_average{$cys_alkyl}));
$cys_add = ($MassType eq 'Average')? $cys_alkyl_add_average{$cys_alkyl} : $cys_alkyl_add_mono{$cys_alkyl};

$oxy_mets = ($FORM{"methionine"} eq "oxidize");

$order = $FORM{"order"};

if ($order eq "mass" or $order eq "position" or $order eq "retention") {
    $minmass = $FORM{"minmass"};
    $maxmass = $FORM{"maxmass"} || $DEFS_PEPCUT{"Really Big Number"};
}

## The following two variables, if true, instruct us to "display partials"
## (partially cleaved peptides) and "display unmodified peptides" (eg
## possible peptides for which cysteine modification failed to occur)
## respectively.
##
## Note that the methionine oxidation option always also shows unoxidized
## methionines and that the "addmass" generic modifications are assumed to
## reflect "in vitro" modifications (for example, phosphorylations), and
## so do not show the unmodified counterparts.

$disp_partials = $FORM{"partials"};
$disp_unmodified = $FORM{"disp_unmodified"};

# if a SWISS-PROT protein entered (remnant from peptide-mass program)
if ($protein =~ /\w{1,4}_\w{1,5}/ || $protein =~ /[PQ]\d{5}/i){	
	print ("BAD! Swiss-Prot entries not allowed!<p>\n");   
	exit;
}

## process the sequence entered
##
$protein =~ tr/a-z/A-Z/; # uppercase letters
$protein =~ tr/A-Z//c; # ignore all non-letter characters
$sequence = $protein;	

# find BEGIN/END values, if entered
$trim_end = $FORM{"end"};
$pos_offset = ($FORM{"begin"}) ? ($FORM{"begin"} - 1) : 0;

if ($trim_end) {
  $sequence = substr ($sequence, 0, $trim_end);
} else {
  $trim_end = length ($sequence);
}
$sequence = substr ($sequence, $pos_offset);

@sequence = split("",$sequence); # make an array 

$len = length ($sequence);

if ($len == 0) {
	print ("<span style='color:red'>Please enter a non-empty peptide.</span>\n");
	exit;
}

# if we are supposed to do modifications, check what we have to do
# @matchedlocs is an array of Res numbers that match. @matcharray is 
# an array such that $matcharray[$i] is one if and only if $peptide_array[$i]
# is modified.

$addmass = $FORM{"addmass"};

if ($addmass != 0) {
  my  $modresidues = $FORM{"locations"};
  $modresidues =~ tr/,./ /;

  my @modres = split (' ', $modresidues);

  # store residue letters and numbers into two different arrays
  my $index=0;   
  foreach $res (@modres) {
	 if ($res =~ /^\d+$/) {
		 $modlocs[$index++] = $res;
	 }
	 # if residue is numbers and letters combination, it will strip the letters and keep the numbers.
	 elsif($res =~/\w*\d+\w*/) {
		 my @elements = split /[a-zA-Z]+/, $res;
		 my $len = $#elements+1;
		 for (my $i=0;$i<$len;$i++) {
			 $modlocs[$index++] = $elements[$i];
		 }
	 }
	 elsif ($res =~ /^\w$/) {
		 $modtypes[$index++] = uc $res;
	 }
  }

 if ($#modtypes + 1 > 0) { # take all positions of the given aa
    foreach $type (@modtypes) {
		my $loc;
		for ($loc = 1; $loc <= $len; $loc++) {
			push (@matchedlocs, $loc + $pos_offset) if ($sequence[$loc-1] eq $type);
		}
	}
  }
  
  if ($#modlocs + 1 > 0) { # if specific locations are given
    foreach $loc (@modlocs) {
      next unless ($loc > $pos_offset);
	  # make sure there is no duplicated matched locations 
	  my $issameloc = 0;
	  foreach $matchedloc (@matchedlocs) {
		  if ($loc == $matchedloc) {
			  $issameloc = 1;
			  last;
		  }
	  }
	  if (!$issameloc){
		push (@matchedlocs, $loc) if ($sequence[$loc-1-$pos_offset]);
	  }
	}
  }
  $modcount = $#matchedlocs + 1; # number of matches
  foreach $mod (@matchedlocs) {
    $matcharray[$mod-1] = "1";
  }
 
  $addmass = "+" . $addmass if ($addmass > 0); # for printing
}

# if we are asked to search for a certain peptide,
# we create an array of offsets into the (longer) peptide for which
# the search peptide matches. These offsets match the position AFTER the
# match. Eg: searching for "a" in "abracadabra" gives (1, 4, 6, 8, 11)
# searching for "ab" gives in "abracadabra" returns (2, 9);

# This part is modified by Ulas 10/26/98 to allow multiple search strings
# separated by commas.

($searchseq_input = $FORM{"searchseq"}) =~ tr/a-z/A-Z/;
$searchseq_input =~ tr/A-Z, *@?//cd;

@searchseqs = split /[ ,]/, $searchseq_input;

foreach $searchseq (@searchseqs) {
  my $l = length $searchseq;
  my $x;

	$searchseq =~ s/\?/[A-Z]/g;		# ? is the wildcard char in our syntax. in regexp
							# that is [A-Z] (roughly)

  while ($sequence =~ m/$searchseq/g) {
    # $x is the position of the beginning of the match (starting from zero)
    $x = pos ($sequence) + $pos_offset - $l;

	$start_end{$x + 1} = $x + length $searchseq;		# this ugly hash needs to be created for the purposes of protein mapper.
    push (@searchmatches, $x+1);
    for ($i = $x; $i < $x + $l; $i++) {
      $searchmatchposarr[$i] = 1;
    }
    # reset pos() to point to just one after this match, in order to catch something like
    # "ABABA" by the pattern "ABA"
    pos ($sequence) = pos ($sequence) - $l + 1;
  }
}

# need to get avg_mw before we call &cleavage
$avg_mw = &mw ($MassType, $cys_add, $sequence);
$avg_mw_nice =  &precision ($avg_mw, 1, 6, " ");
$avg_mw_nice =~ s/^\s*(.*)$/$1/;

&cleavage;
$minreten = $maxreten = 0;
@arr = keys %mass;
foreach $elt (@arr) {
    # still don't take modifications into account, egads.
    $reten = (&calc_retention ($seq{$elt}))[1];
    $reten{$elt} = $reten;
    $minreten = &min ($reten, $minreten);
    $maxreten = &max ($reten, $maxreten);
}
if($FORM{"mode"} eq "backlink_run")
{
	print <<EOF;
	<form name=pepcutform action="$ourname" style="margin-top:0; margin-bottom:0" method=post>
	<input type="hidden" name="type_of_query" value="$FORM{'type_of_query'}">
	<input type="hidden" name="database" value="$FORM{'database'}">
	<input type="hidden" name="query" value="$FORM{'query'}">
	<input type="hidden" name="searchseq" value="$FORM{'searchseq'}">
	<input type="hidden" name="MassType" value="$FORM{'MassType'}">
EOF
	print "<input type=\"hidden\" name=\"frame\" value=\"$FORM{'frame'}\">" if $FORM{'frame'};
	print "<input type=\"hidden\" name=\"Dir\" value=\"$FORM{'Dir'}\">" if $FORM{'Dir'};

	print <<EOF;
	</FORM>
EOF

}
if ($order ne 'retengraph')
{
	&print_buttons;

	&print_sample_info;


	if ($fasta_info) 
	{	
		&print_header;
	}

	print "</table>";

	if ($FORM{'disp_sequence'}) 
	{	
	
		print "<span id=seq>\n";
		print "<BR CLEAR=ALL style=font-size:8>\n";
		&pretty_print;
		print "</span>\n";
  
		print <<EOP;
	<BR CLEAR=ALL style=font-size:8>
	<script>
		var sequence = document.all.seq.innerHTML;
	</script>
	
EOP
	}
	else {
		print "	<BR CLEAR=ALL style=font-size:8>"
	}

}

$res_avg = $avg_mw / $len;
$res_avg_nice = &precision ($res_avg, 1, 3, " ");

$charge = 0;
foreach $residue (@sequence) {
	$charge += $charge{$residue};
}
$charge = "+" . $charge if ($charge > 0);
if (!defined $FORM{"Enzyme"}) {
	$FORM{"Enzyme"} = $FORM{"enzyme"};
}

unless ($order eq "retengraph") 
{
	print <<EOF;
<table cellpadding=0 cellspacing=0 border=0 width=740>
<tr><td valign=top><table cellpadding=0 cellspacing=0 border=0 width=220>
<TR height=16><TD class=title width=90>Enzyme:&nbsp;</td><td class=data nowrap>&nbsp;$FORM{"Enzyme"}</td></tr>
<TR height=16><TD class=title width=90>Cys:&nbsp;</td><td class=data nowrap>&nbsp;$cys_alkyl</td></tr>
<TR height=16><TD class=title width=90>Length:&nbsp;</td><td class=data nowrap>&nbsp;$len</td></tr>
<TR height=16><TD class=title width=90>MW:&nbsp;</td><td class=data nowrap>&nbsp;$avg_mw_nice</td></tr>
<TR height=16><TD class=title width=90>pI:&nbsp;</td><td class=data nowrap>&nbsp;</td></tr>
</table></td>
EOF

	$modinfo = qq(<span class="smalltimes" style="color:#644133"><i>Modification of $addmass amu at residue(s): )
		. join (", ", @matchedlocs) . ".</i></span><BR>" if ($addmass and $modcount);

	if (scalar(@searchseqs) == 1) 
	{  # Only if there is one search string, do we want to print
		$searchinfo = qq(<i>Search string $matchHTML$searchseq_input$matchHTMLend found at residue(s): )
			. join (", ", @searchmatches) . ".</i><BR>" if ($searchseq_input and @searchmatches);
	}
	
	if ($minmass or $maxmass) {
		$mass_range_note = "$minmass-$maxmass\n";
	}

	$display_order = $order;
	$display_order =~ s/^(.)/\u\1/;
	
	my @disp_p = ();
	push @disp_p, ($FORM{'charges'} eq 'm/z')? 'm/z': 'Mr';
	push @disp_p, 'Partials' if ($FORM{'partials'});
	push @disp_p, 'Unmodified' if ($FORM{'disp_unmodified'});
	push @disp_p, 'Oxidized Methionines' if ($FORM{'methionine'});

	my $display_params = join (', ', @disp_p);
	

	if ($sequence =~ /[JOUXBZ]/){ 
		$warning = "<span class=smalltimes style='color:red'><i><B>Warning:</B> Sequence contains J, O, U, X, B, or Z. Calculations may not be exact.</i></span><BR>";
	}
	print <<EOF;
<td width=20>&nbsp;</td>
	<td valign=top align=center><table cellpadding=0 cellspacing=0 border=0 width=210>	
	<TR height=16><TD class=title width=90>Charge:&nbsp</td><td class=data nowrap>&nbsp;$charge</TD></TR>
	<TR height=16><TD class=title align=right nowrap>Mass Type:&nbsp;</td><td class=data nowrap>&nbsp;$MassType</td></tr>
	<TR height=16><TD class=title align=right nowrap>Mass Range:&nbsp;<td class=data nowrap>&nbsp;$mass_range_note</td></tr>
	<TR height=16><TD class=title align=right nowrap>Sort By:&nbsp;</td><td class=data nowrap>&nbsp;$display_order</td></tr>
	<TR height=16><TD class=title align=right nowrap>Display:&nbsp;</td><td class=data nowrap>&nbsp;$display_params</td></tr>
</table></td>
<td width=20>&nbsp;</td>	
<td valign=top align=right><table cellpadding=0 cellspacing=0 border=0 width=270>	
<tr height=16><TD class=title align=right width=40>&nbsp;&nbsp;&nbsp;&nbsp;M:&nbsp;</td><td class=data nowrap>&nbsp;Oxidized methionine</td></tr>
<tr height=16><TD class=title align=right>C:&nbsp;</td><td class=data nowrap>&nbsp;Modified cysteine</td></tr>
<tr height=16><TD class=title align=right><span style="color:red">*</span>:&nbsp;</td><td class=data nowrap>&nbsp;Number of Modifications</td></tr>
<tr height=16><TD class=title align=right>$multipleTAG:&nbsp;</td><td class=data nowrap>&nbsp;Peptide&nbsp;appears&nbsp;more&nbsp;than&nbsp;once</td></tr>
<tr height=16><TD class=title align=right>${matchHTML}X${matchHTMLend}:&nbsp;</td><td class=data nowrap>&nbsp;Matches&nbsp;against&nbsp;the&nbsp;search&nbsp;peptide(s)</td></tr>
</table></td>
EOF
	print qq(</tr></table><BR CLEAR=ALL style=font-size:8>\n);
}
else {
	print <<TOPTABLE;
<TABLE $TABLEWIDTH BORDER=0>
<TR>
<TD><span class=smallheading>Enzyme:&nbsp;</span><TT>$FORM{"Enzyme"}</TT></TD>
<TD><span class=smallheading>Cys:&nbsp;</span><TT>$cys_alkyl</TT></TD>
<TD><span class=smallheading>Length:&nbsp;</span><TT>$len</TT></TD>
<TD><span class=smallheading>MW:&nbsp;</span><TT>$avg_mw_nice</TT></TD>
<TD><span class=smallheading>Res_avg:&nbsp;</span><TT>$res_avg_nice</TT></TD>
<TD><span class=smallheading>Charge:&nbsp;</span><TT>$charge</TT></TD>
</TR>
</TABLE>
TOPTABLE
}

unless ($order eq "retengraph") {
	print <<TABLE;
<table cellpadding=0 cellspacing=0 border=1 width=740 bgcolor=#0099cc bordercolorlight=#f2f2f2 bordercolordark=#999999>
<tr><td align=center class=smallheading style='color:#FFFFFF' width=50>Res</td>
	<td align=center class=smallheading style='color:#FFFFFF' width=15>W</td>
	<td align=center class=smallheading style='color:#FFFFFF' width=15>Y</td>
	<td align=center class=smallheading style='color:#FFFFFF' width=15>C</td>
	<td align=center class=smallheading style='color:#FFFFFF' width=50>Reten</td>
TABLE
    if ($Iwantcharges) {
	print ("<td style='color:#FFFFFF' align=center>", "<tt class=small>", "&nbsp;" x 3, "</tt><span class=smallheading>1+</span>", "&nbsp;" x 2);
	print ("<tt class=small>", "&nbsp;" x 3, "</tt><span class=smallheading>2+</span>", "<tt class=small>", "&nbsp;" x 2, "</tt>");
	print ("<tt class=small>", "&nbsp;" x 3, "</tt><span class=smallheading>3+</span>", "<tt class=small>", "&nbsp;" x 2, "</tt>");
	print ("<tt class=small>", "&nbsp;" x 3, "</tt><span class=smallheading>4+</span>", "<tt class=small>", "&nbsp;" x 2, "</tt>");
	print ("<tt class=small>", "&nbsp;" x 3, "</tt><span class=smallheading>5+</span>", "<tt class=small>", "&nbsp;" x 2, "</tt>");
    } else {
	print ("<td align=center class=smallheading style='color:#FFFFFF' width=60>&nbsp;Mol&nbsp;Wt</td>");
    }
    print ("<td align=center class=smallheading style='color:#FFFFFF' width=40>&nbsp;Len&nbsp;&nbsp;</td>");
    print ("<td style='color:#FFFFFF'><tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>10</span>");
    print ("<tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>20</span>");
    print ("<tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>30</span>");
	print ("<tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>40</span>");
	unless ($Iwantcharges) {
	print ("<tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>50</span>");
	print ("<tt class=small>", "&nbsp;" x 8 , "</tt><span class=smallheading>60</span>");
    }
    print ("</td></tr></table>\n");	
}
$myline = 0;
print qq(<table cellpadding=0 cellspacing=0 border=0 width=740>);
if ($order eq "position") 
{
	# @peptides is in order, no partials
    
	#sorting by position. If ties by mass
	@print = sort by_start_mass (keys %mass);

	foreach $peptide (@print) 
	{
		#use mass bounds only with partials
		&print_pept ($peptide) if ($mass{$peptide} > $minmass && $mass{$peptide} < $maxmass);
    }
} 
elsif ($order eq "mass") 
{ 
	# print result sorted by masses
    if ($FORM{"direction"} eq "increasing") 
	{
		@print = sort by_mass (keys %mass);
    } 
	else 
	{
		@print = sort by_decreasing_mass (keys %mass);
    }

    foreach $peptide (@print)
	{
		if ($mass{$peptide} > $minmass && $mass{$peptide} < $maxmass ) 
		{
			&print_pept ($peptide);
		}
    }
} 
elsif ($order eq "retention") 
{
	# print result sorted by retention coeffs
    if ($FORM{"direction"} eq "increasing") 
	{
		foreach $peptide (sort by_reten (keys %mass))
		{
			if ($mass{$peptide} > $minmass && $mass{$peptide} < $maxmass ) 
			{
				print_pept ($peptide);
			}
		}
	} else 
	{
		foreach $peptide (sort by_decreasing_reten (keys %mass)) 
		{
			if ($mass{$peptide} > $minmass && $mass{$peptide} < $maxmass ) 
			{
				print_pept ($peptide);
			}
		}
	}

} 
elsif ($order eq "retengraph") 
{
    $pngfile = "$tempdir/$ourshortname" . "_$$.png";
    $webpngfile = "$webtempdir/$ourshortname" . "_$$.png";
    &draw_graph();

    print ("<b><tt>Retention plot: ablot values on x-axis, weighted peptide length on the y-axis:</tt></b><br>\n");
    
    print qq(<img src = "$webpngfile" WIDTH=$HSIZE HEIGHT=$VSIZE><br>\n);
}

unless ($order eq "retengraph") 
{
    print <<ENDKEY;
</table>
<HR>

$warning
$searchinfo
$modinfo
<span class="smalltimes" style="color:#644133"><i>Note: The retention coeffs do not take modifications into consideration.</i></span>

ENDKEY
}

#&print_pepcut_to_protein_mapper_form();
&print_pepcut_to_muquest_form();

exit;

#-----------------------------------------------------------------------
# subroutines:
#------------------------------------------------------------------------


##
## &cleavage
##
## the core of "pepcut"
##

# this subroutine takes $sequence and splits it up into peptide fragments
# according to the $enzyme being used. In addition, it will calculate
# partials (fragments from partial digestion by the enzyme) if we ask
# it to (by setting $disp_partials to true).
# 

# in general, positions start from 1 at the beginning of the peptide.
# this is offset by $pos_offset if we are using the BEGIN/END trimming
# facility

# some global variables we create:
# @lengths: ordered array of the lengths of fragments created
# @breaks: positions in the array (starting at zero) of a site

# Associative arrays for each element
# $elt is a unique string consisting of the start positio, length, and poss
# modification codes.

# $seq{$elt} -- the sequence of letters that make up the peptide
# $special{$elt} contains "M" if one or more Mets have been oxidized
#                contains "C" if one or more Cys's have been modified

# $realmod{$elt} is the unmodified element that corresponds to $elt
#                -- just the amino acid sequence
# $mod{$elt} is a comma-separated list of the elements that are modified versions of this one
# $nummods{$elt} is the number of modifications for this element.
#
# $length{$elt} is the number of aa's in the peptide
# $start{$elt} is the start of the peptide relative to the sequence (starts at 1)
#
# $locs{$elt} is a comma separated list of locs at which the same sequence occurs
#
# Normal peptides are just strings of uppercase letters
# Modified peptides are the sequence followed by:
#
# ":4C" for 4 modified cysteines
# ":2M" for 2 oxidized methionines
# ":2#" for 2 "addmass" modifications
# ":100.0,4,10,30" for an "addmass" modification of 100.0 amu at
#                  positions 4, 10, and 30 *relative* to the start of the peptide
#                  (not to the whole, given sequence)


sub cleavage 
{
	my ($pep, $pos, $l, $count, @arr, $base, $seq, $newelt);
	my $water = ($MassType eq "Average") ? $Average_mass{"Water"}
                                       : $Mono_mass{"Water"};
	my ($sum, $savedend, $savedsum, $end, $front);
	my $line = $sequence;
	my $totallen = length ($line) + $pos_offset;
	my ($temp, $break);

	my $sites = $sites{$enzyme};
	my $nonsites = $nonsites{$enzyme};
	# to make the regexp compile:
	$nonsites = " " if ($nonsites eq "" or $nonsites eq "-");

	# $offset is true if the cleavage site is in front of the break,
	# false if it is after the break
	my $offset = $offset{$enzyme};
	my $pattern = $offset ? "(.*?[$sites])([^$nonsites].*)"
                        : "(.*?[^$nonsites])([$sites].*)";

	my $unmod = $disp_unmodified && ($cys_add != 0);

	##
	## cleave the $sequence into peptide fragments
	##
	my @rawpeptides;
	while ($line =~ /^$pattern$/o) 
	{
		$line = $2;
		$pep = $1;
		push (@rawpeptides, $pep);
	}
	push (@rawpeptides, $line); # what's left is also a cleaved peptide

	## for each "raw peptide", calculate mass, length, start position, etc,
	## and create and store its unique name in @peptides.
	##
	## also, calculate @breaks (positions, relative to zero, of cleavage sites
	## in the sequence)

	$pos = 1 + $pos_offset;
	foreach $p (@rawpeptides) 
	{
		$l = length ($p);

		$elt = "$pos:$l";
		$seq{$elt} = $p;

		push (@peptides, $elt);

		$realmod{$elt} = $elt;
		$mass{$elt} = &mw ($MassType, $cys_add, $p);

		#helpful associative arrays
		$start{$elt} = "$pos";
		$length{$elt} = $l;

		push (@lengths, $l);
		push (@positions, $pos);

		$break = $pos - 1; # because the breaks start indexing from 0 
		$break-- if ($offset); # when the site is before the cleavage

		# add this to the list of breaks
		# unless we are the very first peptide (which is not a cleavage).
		push (@breaks, $break) 	unless ($pos == 1 + $pos_offset);
		$pos += $l;
	}

	## calculate partials
	##
	## if we are asked to calculate partials (partially cleaved fragments
	## of the sequence), we do so. These partials are concatenations of
	## neighboring fragments.
	##
	## INITIAL keeps track of the fragment at the beginning of the partial,
	## TAIL keeps track of the fragment at the end of the partial, and
	## COUNT is used merely to loop over the fragments in between to sum
	## their masses.

	if ($disp_partials && ($avg_mw > $minmass)) 
	{
		# this keeps some slightly large partials in so that their
		# unmodified counterparts are included
		my $mymaxmass = $maxmass * 1.2;

		my $numsimplepeps = $#peptides + 1;

		INITIAL: for ($i = 0; $i < $numsimplepeps; $i++) 
		{
			$max = &min ($i + 10, $numsimplepeps - 1);

			TAIL: for ($j = $i+1; $j <= $max; $j++) 
			{
				$mass = $mass{$peptides[$i]};

				COUNT: for ($k = $i+1; $k <= $j; $k++) 
				{
					$mass += $mass{$peptides[$k]} - $water;
				}

				next TAIL if ($mass < $minmass); # too light for consideration
				next INITIAL if ($mass > $mymaxmass); # too heavy for consideration

				$start = $positions[$i];
				$l = $lengths[$i];
				$seq = $rawpeptides[$i];

				# calculate length and sequence for this partial
				for ($k = $i+1; $k <= $j; $k++) 
				{
					$l += $lengths[$k];
					$seq .= $rawpeptides[$k];
				}

				$pep = "$start:$l";
				#push (@partials, $pep);

				$seq{$pep} = $seq;
				$realmod{$pep} = $pep;
				$mass{$pep} = $mass;
				$start{$pep} = $start;
				$length{$pep} = $l;

				$realmass = &mw ($MassType, $cys_add, $seq{$pep});
				if (abs ($mass - $realmass) > .000005) 
				{
					print STDERR ("PepCut: not equal; $pep is $mass, should be $realmass,");
					print STDERR ("difference is ", ($mass - $realmass), ", seq is $seq{$pep}\n");
				}
			} # matches TAIL
		} # matches INITIAL
	}

	## take care of user "Add Mass" modification
	##
	## if the user has entered special modifications, then for each
	## peptide and partial, we modify the mass accordingly

	if ($addmass && $modcount) 
	{
		@arr = keys (%mass);
	
		foreach $elt (@arr) 
		{  
			$start = $start{$elt};
			$l = $length{$elt};

			@m = ();
			$count = 0;
			# check against all addmass match lcoations
			foreach $pos (@matchedlocs) 
			{
				if ($start <= $pos and $pos < ($start + $l)) 
				{
					$count++;
					push (@m, $pos - $start);
				}
			}
			next unless $count;
      
			$base = $realmod{$elt};

			my $n;
	  
			# code for modification is the number of mods, followed by mod type, followed by
			# comma-separated list of mod locations relative to the start of the peptide.
			# this allows easy comparison of same-sequence peptides.
			if ($unmod)
			{
				for ($n=1; $n <= $count; $n++) 
				{
					$newelt = $base . ":" . $n . "#"; # this needs to be a unique identifier

					$special{$newelt} .= ":"  if $special{$newelt};
					$special{$newelt} .= $n . "_addmass" . join (",", @m); # "_addmass" for generic modification
					$mass{$newelt} += $mass{$elt} + $addmass * $n;
					
					$realmod{$newelt} = $base;
					$start{$newelt} = $start{$base};
					$length{$newelt} = $length{$base};
					$seq{$newelt} = $seq{$base};
					$locs{$newelt} = $locs{$base};
					$nummods{$newelt} += $nummods{$elt} + $n;

					$mod{$base} .= "," if $mod{$base};
					$mod{$base} .= $newelt;

					#print "$mod{$base}<BR>";
				}
			}
			else
			{	
				$special{$elt} .= ":"  if $special{$elt};
				$special{$elt} .= $count . "_addmass" . join (",", @m); # "_addmass" for generic modification
				$mass{$elt} += $addmass * $count;
				$nummods{$elt} += $#m + 1;
			}
		}
	}

	## add "special" if matches against search peptide
	## 

	if ($searchseq_input)
	{
		@arr = keys (%mass);
		my @m;

		foreach $elt (@arr)
		{
			$start = $start{$elt};
			$l = $length{$elt};
      
			@m = ();
			$count = 0;
			
			# check against all search peptide match locations
			# we use [$i-1] because $i counts using Mass Spec indexing (starting at one),
			# whereas @searchmatchposarr uses standard Perl indexing (starting at zero)
			for ($i = $start; $i < $start + $l; $i++) 
			{
				if ($searchmatchposarr[$i-1]) 
				{
					$count++;
					push (@m, $i - $start);
				}
			}

			# code for modification is the number of mods, followed by mod type, followed by
			# comma-separated list of mod locations relative to the start of the peptide.
			# this allows easy comparison of same-sequence peptides.
			if ($count) 
			{
				$special{$elt} .= ":" if $special{$elt};
				$special{$elt} .= $count . "_search" . join (",", @m); # "_search" for matches against search peptide
			}
		}
	}

	## eliminate redundancies:
	##
	## now, if we are not ordering by positions, we need to consolidate peptides
	## that appear more than once

	# Commented out by Ulas 11/30/98

	#  if ($order ne "position") {
	#    @arr = sort { $seq{$a} cmp $seq{$b} } keys (%mass);
	#    my $last = undef;
	#    foreach $elt (@arr) {
	#      # the following checks that the sequences are the same and that their addmass
	#      # mods are the same, rel. to the beginning of the peptide.	
	#
	#      if ( ($seq{$elt} eq $seq{$last}) and ($special{$elt} eq $special{$last}) ) {
	#	if ( abs($mass{$elt} - $mass{$last}) > .000005 ) {
	#	  print STDERR ("PepCut: masses different in redundancy reduction between $elt and ",
	#			"$last; masses are ", $mass{$elt}, " and ", $mass{$last}, "\n");
	#	}
	#	if (!defined $locs{$last}) {
	#	  $locs{$last} = $start{$last};
	#	}
	#	$locs{$last} .= "," . $start{$elt};
	#	$start{$last} = &min ($start{$elt}, $start{$last});
	#
	#	# eliminate $elt:
	#	$mass{$elt} = undef;
	#	$start{$elt} = undef;
	#	$length{$elt} = undef;
	#	$special{$elt} = undef;
	#	$seq{$elt} = undef;
	#	$realmod{$elt} = undef;
	#	$mod{$elt} = undef;
	#      }  else {
	#	$last = $elt;
	#      }
	#    }
	#  }

	## here we create new elements that correspond to possible cysteine modifications
	## (including conditions of modifying only some cysteines if $unmod is true)
	##
	## these new entries are linked in by using the %mod assoc array, and linked back
	## using %realmod

	# peptides with a small "c" have unmodified cysteines
	# these have their %realmod value set to the uppercase peptide
	if ($unmod) 
	{
		@arr = keys %mass;
		foreach $elt (@arr)
		{
			$count = $seq{$elt} =~ tr/C/C/;
			next unless $count;

			$base = $realmod{$elt};

			# here $n corresponds to the number of UNmodified cysteines;
			# ie ($count - $n) cysteines _are_ modified. Hence we loop
			# from 1 to $count. The original has $count modified cysteines,
			# and we create those with $count - 1 to zero modified cysteines.

			my $n;
			for ($n = 1; $n <= $count; $n++)
			{
				$newelt = $elt . ":" . $n . "C"; # this needs to be a unique identifier

				##
				## mark according to number of modified cysteines:
				##
				$special{$newelt} = $special{$elt};
				if ($n != $count) 
				{
					$special{$newelt} .= ":"  if $special{$newelt};
					$special{$newelt} .= ($count - $n) . "C";
				}

				$realmod{$newelt} = $base;
				$start{$newelt} = $start{$base};
				$length{$newelt} = $length{$base};
				$seq{$newelt} = $seq{$base};
				$locs{$newelt} = $locs{$base};
				$nummods{$newelt} += $nummods{$elt} + $count - $n;

				$mod{$base} .= "," if $mod{$base};
				$mod{$base} .= $newelt;


				# remember, $n is the number of unmodified cysteines, so we need to
				# subtract $n * $cys_add from the mass of the original element.
				$mass{$newelt} = $mass{$elt} - $n * $cys_add;
			}
      
			# modify special value of element (because it, too, has modified cysteines)
			$special{$elt} .= ":" if $special{$elt};
			$special{$elt} .= $count . "C";
			$nummods{$elt} += $count;
		}
	} 
	elsif ($cys_add != 0) 
	{
		# if $cys_add does not equal zero, then cysteine modifications
		# have occurred.
		# In this case, All cysteines are modified and thus should be emphasized
		# we do not need to alter their mass because &mw takes $cys_add
		# into consideration

		@arr = keys %mass;
		foreach $elt (@arr)
		{
			$count = $seq{$elt} =~ tr/C/C/;
			next unless $count;
			$special{$elt} .= ":" if $special{$elt};
			$special{$elt} .= $count . "C";
			$nummods{$elt} += $count;
		}
	}

	##
	## Now we create elements for oxidized methionines if asked to be the user
	##
	## here, $n is the number of oxidized methionines, so we run from 1 to $count
	## zero is the case of the original element

	if ($oxy_mets)
	{
		$temp = ($MassType eq "Average") ? $Average_mass{"Oxygen"} : $Mono_mass{"Oxygen"};

		@arr = keys %mass;
		foreach $elt (@arr) 
		{
			$count = $seq{$elt} =~ tr/M/M/;
			next unless $count;
			$base = $realmod{$elt};

			## $n counts the number of oxidized methionines in a peptide
			## therefore, $n runs from 1 to the number of Mets in the
			## base peptide
			my $n;
			for ($n=1; $n <= $count; $n++) 
			{
				$newelt = $elt . ":" . $n . "M"; # this needs to be a unique identifier

				$special{$newelt} = $special{$elt};
				$special{$newelt} .= ":"  if $special{$newelt};
				$special{$newelt} .= $n . "M";

				$realmod{$newelt} = $base;
				$start{$newelt} = $start{$base};
				$length{$newelt} = $length{$base};
				$seq{$newelt} = $seq{$base};
				$locs{$newelt} = $locs{$base};
				$nummods{$newelt} += $nummods{$elt} + $n;

				$mod{$base} .= "," if $mod{$base};
				$mod{$base} .= $newelt;

				$mass{$newelt} = $mass{$elt} + $n * $temp;
		    }
		}
	}
} # end of &cleavage

sub by_mass {			# sort list by mass of elements
    $mass{$a} <=> $mass{$b};
}
sub by_decreasing_mass {			# sort list by mass of elements
    $mass{$b} <=> $mass{$a};
}
sub by_reten {
	$reten{$a} <=> $reten{$b};
}
sub by_decreasing_reten {
	$reten{$b} <=> $reten{$a};
}

#sorts by start and if a tie by length
sub by_start_mass
{
	if ($start{$a} == $start{$b})
	{
		$mass{$a} <=> $mass{$b};
	}
	else
	{
		$start{$a} <=> $start{$b};
	}
}

# takes two arguments, the peptide and its position.
# The string is a peptide to format to the screen, giving many stats
# such as number of Cs, Ys, Ws, length, etc.

sub print_pept {
    my $givenpeptide = $_[0];
	$start = $start{$givenpeptide};
	
	my $pep = $seq{$givenpeptide};
    my $temp;
	my @locs = ();    #array for addmass locs to be passed to pepstat
	
	&push_to_peptide_list($pep);		# needed by the send to muquest functionality.

    # $locs is a comma-separated list of positions at which the peptide
    # occurs. ($locs is undef if it only occurs once).
    
    my $locs = $locs{$givenpeptide};
    my $duplicated = 1 if (defined $locs);

    my $spacestr = "&nbsp;" x 9 . ":";
    my $linelength = $Iwantcharges ? 41 : 69;
    my $rounded_linelength = int ($linelength /10) * 10;
    my $line = ""; # the line to print

    my ($display, $suffix);

    # if the peptide should be considered modified
    my $special = $special{$givenpeptide};

    # don't count search hits as "modified"
    ( my $modified = $special) =~ s/\d+_search[^:]*//;

    

    my $len = $length{$givenpeptide}; # display length of peptide

    my $viewedlen = $len; # the length of the segment of the peptide displayed

    # first step: calculate how much of the peptide we can display:
    # if modified, we add two characters (" *") at the end
    
    my $line_space = $linelength;
    $line_space -= 1 + $nummods{$givenpeptide} if $modified;

    if ($line_space < $len) {
		
      $display = substr ($pep, 0, $linelength - 3);
	  
      $suffix = $modified ? "-<span style='color:red'>*</span>&gt;" : "--&gt;";
      $viewedlen = $linelength - 3;
    } else {
      $display = $pep;
      $suffix = $modified ? "&nbsp;<span style='color:red'>". '*' x $nummods{$givenpeptide} . "</span>" : "";
      my $displaylen = $len + ($modified ? $nummods{$givenpeptide} + 1 : 0);

      # fill the rest of the line to line up the columns:
      unless ($displaylen % 10 == 0 or $displaylen >= $rounded_linelength ) {
	$suffix .= "&nbsp;" x (9 - $displaylen % 10) . ":";
      }
      $suffix .= $spacestr x int (($rounded_linelength - $displaylen) / 10);
    }

    # add HTML to show special amino acids
    # underline ALL *possibly* modified cysteines
    # these in-place substitutions require us to keep $matchHTML in lowercase.

    if ($special =~ /C/) {
	$display =~ s!(C+)!<u>$1</u>!g;
    }

    if ($special =~ /M/) {
	$display =~ s!(M+)!<u>$1</u>!g;
    }

    # trickier to do the search modifications. here, we look for the
    # modification info in $special, check that we aren't going off the display
    # length of the peptide, and use substr() to do in-place replacements.
    # we use an HTML-aware index() function to transform indices into the plaintext
    # to indices into the actual string.
    #
    # note that these indices are with respect to the $givenpeptide, and start at 0

    if ($special =~ /_search/) {
      ($temp) = $special =~ m!\d+_search([^:]*)!;
      my (@locs) = split (",", $temp);
      
      foreach $loc (@locs) {
	next if ($loc >= $viewedlen);

	$temp = &HTMLindex ($display, $loc);
	next if ($temp == -1);

	# do downstream replacement FIRST
	substr ($display, $temp + 1, 0) = $matchHTMLend;
	substr ($display, $temp, 0) = $matchHTML;
      }
    }

    # we use the same trick as above to highlight generic "addmass" modifications:
    
    if ($special =~ /_addmass/) {
      ($temp) = $special =~ m!\d+_addmass([^:]*)!;
      (@locs) = split (",", $temp);
		
      foreach $loc (@locs) {

	next if ($loc >= $viewedlen);

	$temp = &HTMLindex ($display, $loc);
	next if ($temp == -1);

	# do downstream replacement FIRST
	substr ($display, $temp + 1, 0) = $addmassHTMLend;
	substr ($display, $temp, 0) = $addmassHTML;
      }
    }


     # Added by Ulas to allow highlighting n*s or n*t
	my $highlightedN = $nxsORtHTML . 'N' . $nxsORtHTMLend;
    $display =~ s/N(.(S|T))/$highlightedN\1/sg;

	# added by Georgi 06/23/2000 to handle the special case when a combination of the 
	# type N?(S|T) "crosses" the cut between two peptides
	#example
	#    DVNK
	#	 SASDDQSDQK  
	#
	# The N should be highlighted
	
	# the 1st and 2nd AA in the next peptide (if next exists)
	my ($first_in_next, $second_in_next);
	my $total_seq_len = length($sequence);

	if ($total_seq_len > ($start + $len - 1))
	{
		$first_in_next = substr($sequence, $start + $len - 1, 1);
		$second_in_next = substr($sequence, $start + $len, 1);
	}

# Changes made on these two conditionals 8/4/00 by Paul M. to correct line-length adjustments.  Previous code 
# (at far right) was making $display too long in some cases. 

	if (($first_in_next eq 'S' or $first_in_next eq 'T') and $display =~/^(.*)N(.)$/)      # $seq{$givenpeptide} =~/^(.*)N(.)$/)
	{
		$display = $1.$highlightedN.$2;
	}

	if (($second_in_next eq 'S' or $second_in_next eq 'T') and $display =~/^(.*)N$/)    # $seq{$givenpeptide} =~/^(.*)N$/)
	{
		$display = $1.$highlightedN;
	}

	#making link to Pepstat
	#locs 0 indexed
	foreach(@locs)
	{	
		$_+=1;
	}

	my $URLpep = &url_encode($pep);
	my $pepstatLinkHTML = "<a href='$pepstat?type_of_query=0&peptide=$URLpep&cys_alkyl=$FORM{'cys_alkyl'}";
	if ($addmass)
	{
		my $myaddmass = $addmass;
		$myaddmass =~ s/\+//gi;
		$pepstatLinkHTML .= "&addmass=$myaddmass";
	}
	$pepstatLinkHTML .= "&modlocations=" . join (',', @locs) if (@locs);
	$pepstatLinkHTML .= "&running=1' title='Send to Pepstat' target='_blank'>";
	my $pepstatLinkHTMLend = "</a>";


   # we want to highlight a match if one exists, and place a star if
    # the peptide appears more than once in the protein

    if ($special =~ /_search/) {
      $temp = &precision ($start, 0, 4, "&nbsp;");

      $temp =~ s!^&nbsp;!$multipleTAG! if ($duplicated);

      $temp =~ s!$start!$pepstatLinkHTML$matchHTML$start$matchHTMLend$pepstatLinkHTMLend!;
      $line .= "<td width=52 align=center><tt style=font-size:12>" . $temp . "</tt></td>";
    } 
	else
	{
		if ($duplicated) {
			$line = "<td width=52 align=center><tt style=font-size:12>" . $pepstatLinkHTML. $multipleTAG . $pepstatLinkHTMLend. "</tt></td>";
		} 
		else
		{
			my $tmp = &precision ($start, 0, 4, "&nbsp;");
			$tmp =~ s!$start!$pepstatLinkHTML$start$pepstatLinkHTMLend!;
			$line .= "<td width=52 align=center><tt style=font-size:12>" . $tmp . "</tt></td>";
		}
    }

    my $numW = $pep =~ tr/W/W/ || "&nbsp;";
    my $numY = $pep =~ tr/Y/Y/ || "&nbsp;";
    my $numC = $pep =~ tr/C/C/ || "&nbsp;";

    $line .= "<td width=16 align=center><tt style=font-size:12>" . $numW. "</tt></td>" . "<td width=16 align=center><tt style=font-size:12>" . $numY . "</tt></td>" . "<td align=center width=16><tt style=font-size:12>" . $numC . "</tt></td>";
    $line .= "<td  width=54 align=center><tt style=font-size:12>" . &precision ($reten{$givenpeptide}, 1, 3, "&nbsp;") . "</tt></td>";
    if ($Iwantcharges) {
		my $tempmass;
		my $found;
		$line .= "<td align=center><tt style=font-size:12>";
		for ($i = 1; $i <= 5; $i++) {
			# Average mass is so close to monoisotopic there is no point in
			# making a distinction in the case of Hydrogen

			$tempmass = $mass{$givenpeptide} / $i + $Average_mass{"Hydrogen"};
			$found = $masssearch && (abs ($tempmass - $masssearch) <= $tolerance);
			$line .= "&nbsp;";
			$line .= qq(<span style="color:red; font-weight:bold">) if $found;
			$line .= &precision ($tempmass, 1, ($i == 1) ? 5 : 4, "&nbsp;");
			$line .= qq(</span>) if $found;
		}
		$line .= "</tt></td>";
    } else {
      $line .= "<td align=center width=64><tt style=font-size:12>" . &precision ($mass{$givenpeptide}, 1, 5, "&nbsp;") . "</tt></td>";
    }

    $line .= "<td align=center align=center width=44><tt style=font-size:12>" . &precision ($len, 0, 3, "&nbsp;") . "</tt></td>";

	my $color="#f2f2f2" if ($colorline % 2 == 0);	
	
	$colorline++;

    print ("<tr bgcolor=$color >", $line, "<td><tt style=font-size:12>$display$suffix</tt></td>", "", "</td></tr>\n");

}

## &HTMLindex
##
## this subroutine takes a string S and an integer N as arguments.
## It then returns the index in the string corresponding to the Nth "real" character in S,
## skipping HTML tags. Returns -1 if not found.
##
## doesn't HTML comments at this point

sub HTMLindex {
  my ($S, $N) = @_;

  my $p = 0;
  my $i;
  for ($i=0; $i<=$N; $i++) {
    $p = &skip_tag ($S, $p);
    return (-1) if ($p == -1);
    $p++; # advance so we don't hit the same position again and again
  }
  $p--; # counteract the very last $p++ statement;
  return $p;
}

sub skip_tag {
  # we are at position $p in string $S, and want to advance to the next interesting character.

  my ($S, $p) = @_;

  my $l = length ($S);
  my $c;
  
  return (-1) if ($p>=$l);
  while (1) {
    $c = substr ($S, $p, 1);
    if ($c eq "&") {
      do {
	$p++;
	return (-1) if ($p>=$l);
	$c = substr ($S, $p, 1);
      } until ($c eq ";");
    } elsif ($c eq "<") {
      do {
	$p++;
	return (-1) if ($p>=$l);
	$c = substr ($S, $p, 1);
      } until ($c eq ">");
    } else {
      return $p;
    }
    $p++;
    return (-1) if ($p>=$l);
  }
}

# this prints out the protein in sets of ten, up to eight sets per line.
# print special HTML for the sites of cleavage in bold red,
# the matches against any search sequence and locations of addmass modification
# Trimmed-off ends are lowercase.

sub pretty_print {
    my $seq = $protein;
    my $len = length ($seq);
    my @arr = split (//, $seq);

    my ($prefix, $suffix);

    print ("<tt class=small><nobr>");

	# Commented out by Ulas 12/11/98
    # don't bother searching, marking, or pretty-ifing short peptides
#    if ($len < 25) {
#	print ("$seq</tt>\n");
#	return;
#    }

    my $n = 0;
    $i = 0;

    # $underlined keeps track of underlining status for us so we can handle
    # breaks in the output better (Otherwise, spaces get underlined.)

    my $underlined = 0;

    while ($i < $len) {

	# mark cleavage sites
	# @breaks is a global array that marks these sites
	# check for definedness in case we have no cleavage sites

	$prefix = $suffix = "";
	# if we are out of range, print it lowercase
	if ($i < $pos_offset or $i > ($trim_end - 1)) {
	  $arr[$i] =~ tr/A-Z/a-z/;
	  $prefix = $trimHTML;
	  $suffix = $trimHTMLend;
	}


	if ($i == $breaks[$n] && defined $breaks[$n]) {
	  $prefix .= $siteHTML;
	  $suffix = $siteHTMLend . $suffix;
	  $n++;
	}
	# check to see if we have matched the peptide search sequence
	if ($searchseq_input && $searchmatchposarr[$i]) {
	  $prefix .= $matchHTML;
	  $suffix = $matchHTMLend . $suffix;
	}

	if ($matcharray[$i]) {
	  $prefix .= $addmassHTML;
	  $suffix = $addmassHTMLend . $suffix;
	}

	# Added by Ulas 12/11/98. Highlights N when the sequences is N*S or N*T
	if($arr[$i] eq "N" and ($arr[$i+2] eq "S" or $arr[$i+2] eq "T")) {
		$prefix .= $nxsORtHTML;
		$suffix = $nxsORtHTMLend . $suffix;
	}

	if ($i == 0) 
	{
		my $tmp = &precision($i + 1, 0, 4, '&nbsp;');	
	    print "$tmp&nbsp;";
	}

	print ($prefix, $arr[$i], $suffix);

	$i++;
	if (($i % 80) == 0) {
		my $tmp = &precision($i + 1, 0, 4, '&nbsp;');	
	    print "</nobr><br><nobr>\n$tmp&nbsp;";
	} elsif (($i % 10) == 0) {
	  print ("</u>" x $underlined, "\n", "<u>" x $underlined);
	}else {
	    print "";
	}
    }
    # miscellaneous cleanups:
    print "</nobr><br>\n" unless (($i % 80) == 0);
    print ("</tt>\n");
}

sub draw_graph {
    my @arr = keys %mass;
    my $len = length $sequence;
    my $lengthcap;
    my %l;

    # calculate largest length
    foreach $elt (@arr) {
	$l = $length{$elt};
	$l = 60 if ($l > 60);
#	$l = sqrt ($l) unless ($l == 0);

	$base = $realmod{$elt} || $elt;

	# scale intensity;
	$l *= (1.5 ** ($base =~ tr/W/W/)); # Tryptophans
	$l *= (1.2 ** ($base =~ tr/Y/Y/)); # Tyrosines
	if ($reten{$elt} > 0) {
	    $l *= (1 - (1 - .2)/100  * $reten{$elt});
	}
	$l{$elt} = $l; # the weighted length of the peptide
	$lengthcap = &max ($l, $lengthcap);
    }

    # Lincoln Stein's great Perl port
    #       http://www-genome.wi.mit.edu/ftp/pub/software/WWW/GD.html
    # of Thomas Boutell's wonderful gd (gifdraw) C library
    #       http://www.boutell.com/gd/

#    die ("is GD available yet?");
    use GD;
 
    local $im = new GD::Image($HSIZE, $VSIZE);

    my $HBUFFER = 30;
    my $VBUFFER = 40;
 
    my $HAVAIL = $HSIZE - (2 * $HBUFFER);
    my $VAVAIL = $VSIZE - (2 * $VBUFFER);
 
    my $font = gdMediumBoldFont;
    my $tickfont = gdSmallFont;
    my $labelfont = gdSmallFont;
 
    my $TICKLENGTH = 5;
    $im->interlaced("true");
 
    my $white = $im->colorAllocate (255, 255, 255);
    my $lightblue = $im->colorAllocate (70, 50, 255);
    my $black = $im->colorAllocate (0,0,0);
    my $red = $im->colorAllocate (255, 0, 0);
    my $gray = $im->colorAllocate (80, 80, 80);
#    my $orange = $im->colorAllocate (255, 127, 0);
    my $darkblue = $im->colorAllocate (0, 0, 128);
    my $darkgreen = $im->colorAllocate (0, 128, 0);
#    my $darkred = $im->colorAllocate (100, 0, 0);

    my $brown = $im->colorAllocate (166, 42, 42);     # == #A62A2A
    my $magenta = $im->colorAllocate (255, 0, 255);
    my $green = $im->colorAllocate (0, 170, 0);


    # draw axes:
    $im->line($HBUFFER, $VBUFFER, $HBUFFER, $VSIZE - $VBUFFER, $black);
    $im->line($HBUFFER, $VSIZE - $VBUFFER, $HSIZE - $HBUFFER,
	      $VSIZE - $VBUFFER, $black);

    $maxreten = int ($maxreten) + 1 unless ($maxreten == int ($maxreten));
    $minreten = -10 if ($minreten < 0);
    my $range = $maxreten - $minreten;

    # do tick marks:
    if ($range > 100) {
	$tickinterval = 10;
    } elsif ($range > 25) {
	$tickinterval = 5;
    } else {
	$tickinterval = 1;
    }

    $i = int (1.5 + $minreten/$tickinterval) * $tickinterval;
    while ($i < $maxreten) {
	$x = $HBUFFER + int ($HAVAIL * ($i - $minreten)/$range + 0.5);
	$im->line ($x, $VSIZE - $VBUFFER, $x, $VSIZE - $VBUFFER + $TICKLENGTH,
		   $black);
	&x_center_normal ($tickfont, $x, $VSIZE - $VBUFFER + $TICKLENGTH, $i,
			  $black);
	$i += $tickinterval;
    }

    if ($maxreten > 100) {
	# plot a dotted line at 100
	$x = $HBUFFER + int ($HAVAIL * (100 - $minreten)/$range + 0.5);
	$im->line ($x,  $VSIZE - $VBUFFER, $x, $VBUFFER, $gray);
    }

    # label axes:
    &x_center_normal ($font, $HBUFFER, $VSIZE - $VBUFFER + 3 * $TICKLENGTH,
		      $minreten, $red);
    &y_center_upright ($font, $HBUFFER - $font->height, $VSIZE - $VBUFFER,
		       "0", $black);
 
    &y_center_upright ($font, $HBUFFER - $font->height, $VBUFFER,
		       &precision ($lengthcap, 1), $red);
 
    my $lowy = $VSIZE - $VBUFFER + 3 * $TICKLENGTH;

    &x_center_normal ($font, $HSIZE - $HBUFFER, $lowy, $maxreten, $red);

    # display key:
    $im->string ($font, 110, $lowy, "Key:", $black);
    $im->string ($font, 150, $lowy, "W", $green);
    $im->string ($font, 170, $lowy, "Y", $magenta);
    $im->string ($font, 190, $lowy, "C", $black);
    $im->string ($font, 210, $lowy, "M", $brown);
    $im->string ($font, 230, $lowy, "Others", $lightblue);
 
    my $count = 0;
    my $color;
    my $end;
    my $pep;

    # graph and label the peaks:
    foreach $elt (@arr) {
	$reten = $reten{$elt};
	    
	$x = $HBUFFER + int ($HAVAIL * ($reten - $minreten) / $range + 0.5);
	$y = $VSIZE - $VBUFFER - int ($VAVAIL * $l{$elt}/$lengthcap + 0.5);

	my $seq = substr ($sequence, $start{$elt} - 1, $length{$elt});

	if ($seq =~ /W/) {       # Tryptophans most important
	    $color = $green;
	} elsif ($seq =~ /Y/) {  # then tyrosines
	    $color = $magenta;
	} elsif ($seq =~ /C/) { # then cysteines
	    $color = $black;
	} elsif ($seq =~ /M/) { # then methionines
	    $color = $brown;
	} else {
	    $color = $lightblue;
	}

	$label = $start{$elt} . " ";
      if ($length{$elt} > 7) {
          $label .= substr ($seq, 0, 5) . "..";
	} else {
	    $label .= $seq;
	}

	$im->line ($x, $y, $x, $VSIZE - $VBUFFER, $color);

	$x -= ($labelfont->height)/2;
        $y -= int ($VAVAIL / 3.5) unless ($y < $VAVAIL /2);

	$im->stringUp ($labelfont, $x, $y, $label, $color);
    }

    #output the image
	open (PNG, ">$pngfile") || die ("Could not write to $pngfile");
	binmode PNG;
	print PNG $im->png;
	close PNG;
}
 
sub x_center_normal {
    # given an x on which to CENTER the given font, using same y
    local ($font, $x, $y, $s, $color) = @_;
 
    local ($w) = $font->width;
 
    $im->string($font, $x - $w * length($s)/2, $y, $s, $color);
}
sub y_center_upright {
    # given an y on which to CENTER the given font, using same x
    local ($font, $x, $y, $s, $color) = @_;
 
    local ($h) = $font->width;
    $im->stringUp($font, $x, $y + $h * length($s)/2, $s, $color);
}

#
# This is the greeting html page
#

sub output_form
{
  $unique_window_name = "$$\_$^T";

  $FORM{'minmass'} = "" if (!$FORM{'minmass'});
  $FORM{'maxmass'} = "" if (!$FORM{'maxmass'});

  # method quickly changed to POST because we get errors on IE
  # martin 98/10/23
  print <<EOF;

<SCRIPT language="JavaScript">
<!--
var last_offset = null;
var last_row = $MAX_ENZYMES;
var from_offcheck = false;
var enzymes;
var advanced;
var enz_defaults = new Array();

// experience shows, optimal pop-up window heights are different in IE than in Netscape, thus:
var ez_height = (navigator.appName == "Microsoft Internet Explorer") ? 600 : 670;

// reset all form elements to default values, INCLUDING hidden elements and pop-up windows
// (HTML does not necessarily do this by default)
function resetAll()
{
	window.status = "Resetting form to default values, please wait...";

	for (i = 0; i < document.forms[0].elements.length; i++)
		document.forms[0].elements[i].value = defaults[i];

	// reset values in pop-up windows
	if (addmass && !addmass.closed)
		getValues(addmass);

	if (enzymes && !enzymes.closed)
		getValues(enzymes);

	if (advanced && !advanced.closed)
		getValues(advanced);

	// update Enzyme list in dropbox on main form
	document.forms[0].Enzyme.options.length = enz_defaults.length
	for (i = 1; i < enz_defaults.length; i++)
		document.forms[0].Enzyme.options[i].text = enz_defaults[i];	

	window.status = "Done";
}


// retrieve form values from hidden values in main window
// and display in pop-up window
function getValues(popup)
{
    window.status = "Retrieving values, please wait...";

    for (i = 0; i < popup.document.forms[0].elements.length; i++)
    {
		if (popup.document.forms[0].elements[i]) {
			elt = popup.document.forms[0].elements[i];
			if (document.forms[0][elt.name]) {
				if (elt.type == "checkbox")
					elt.checked = (document.forms[0][elt.name].value == elt.value);
				else
					elt.value = document.forms[0][elt.name].value;
			}
		}
    }

    window.status = "Done";
}

// opposite of getValues(): save values from form elements in a pop-up window
// as values of hidden elements in main window, and update enzyme dropbox
function saveValues(popup)
{
	window.status = "Saving values, please wait...";

	var next_dropbox_entry = 0;

	for (i = 0; i < popup.document.forms[0].elements.length; i++)
	{
		var elt = popup.document.forms[0].elements[i];
		
		//copy all textbox values
		if (document.forms[0][elt.name] && elt.type == 'text')
		{
			if (elt.name.substring(0,8) != "enz_name")
				elt.value = elt.value.toUpperCase();

			document.forms[0][elt.name].value = elt.value;
		}

		// update Enzyme list in dropbox on main form if necessary
		if (elt.name.substring(0,8) == "enz_name" && elt.value != '')
		{
			

			var enz_num = elt.name.substring(8,elt.name.length);
			var enz_text = elt.value.replace(/_/g, ' '); //replacing all underscores with spaces
			
			if (!document.forms[0].Enzyme.options[next_dropbox_entry])
				document.forms[0].Enzyme.options[next_dropbox_entry] = new Option();

			document.forms[0].Enzyme.options[next_dropbox_entry].text = enz_text;
			
			next_dropbox_entry++;
		}
		
	}

	//clear up unnecessary stuff from the Enzyme dropbox on main form
	for (i=document.forms[0].Enzyme.options.length; i >=next_dropbox_entry; i--)
		document.forms[0].Enzyme.options[i] = null;

	updateEnzyme();

	window.status = "Done";
}

// create pop-up window for editing enzyme-info parameters
function enzymes_open()
{
	if (enzymes && !enzymes.closed)
		enzymes.focus();
	else
	{
		enzymes = open("","enzymes_$unique_window_name","width=520,height=" + ez_height + ",resizable,screenX=0,screenY=0");
		enzymes.document.open();
		enzymes.document.writeln('<!-- this is the code for the enzyme-info pop-up window -->');
		enzymes.document.writeln('');
		enzymes.document.writeln('<HEAD><TITLE>Enzyme Information</TITLE>$stylesheet_javascript</HEAD>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<BODY BGCOLOR=#FFFFFF>');
		enzymes.document.writeln('<CENTER>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<h4>Enzyme Information</h4>');
		enzymes.document.writeln('');
		enzymes.document.writeln('<FORM method=get action="' + '$ourname' + '">');
		enzymes.document.writeln('');
		enzymes.document.writeln('<TABLE>');
		enzymes.document.writeln('<TR><TH></TH><TH ALIGN=left>Name</TH><TH>Offset</TH><TH ALIGN=left>Sites</TH><TH>No-sites</TH></TR>');

		//one extra row for for enzyme addition
		for (i = 1; i <= $MAX_ENZYMES; i++)
		{
			enzymes.document.writeln('<TR>');
			enzymes.document.writeln('	<TH ALIGN=right>' + i + '.</TH>');
			enzymes.document.writeln('	<TD><INPUT NAME="enz_name' + i + '" onBlur="opener.last_row = ' + i + '" onFocus="opener.checkOffset(opener.last_offset, self); opener.checkFields(opener.last_row, ' + i + ', self)"></TD>');
			enzymes.document.writeln('	<TD ALIGN=center><INPUT NAME="enz_offset' + i + '" SIZE=1 MAXLENGTH=1 onBlur="opener.last_offset=this; opener.last_row = ' + i + '"onFocus="opener.checkOffset(opener.last_offset, self); opener.checkFields(opener.last_row, ' + i + ', self)"></TD>');
			enzymes.document.writeln('	<TD><INPUT NAME="enz_sites' + i + '" onBlur="opener.last_row = ' + i + '" onFocus="opener.checkOffset(opener.last_offset, self); opener.checkFields(opener.last_row, ' + i + ', self)"></TD>');
			enzymes.document.writeln('	<TD ALIGN=center><INPUT NAME="enz_no_sites' + i + '" SIZE=1 MAXLENGTH=1 onBlur="opener.last_row = ' + i + '" onFocus="opener.checkOffset(opener.last_offset, self); opener.checkFields(opener.last_row, ' + i + ', self)"></TD>');
			enzymes.document.writeln('</TR>');
		}

		enzymes.document.writeln('</TABLE>');
		enzymes.document.writeln('<br>');
		enzymes.document.writeln('<INPUT TYPE=button class="outlinebutton button" NAME="saveEnzymes" style="cursor:hand" VALUE="Save" onClick="opener.saveClick(self);"> ');
		enzymes.document.writeln('<INPUT TYPE=button class="outlinebutton button" NAME="cancelEnzymes" style="cursor:hand" VALUE="Cancel" onClick="self.close()">');
		enzymes.document.writeln('<INPUT TYPE=submit class="outlinebutton button" NAME="saveDefaults" style="cursor:hand" VALUE="Make Defaults" onClick="return opener.saveDefaultsClick(self);">');
		enzymes.document.writeln('');
		enzymes.document.writeln('<INPUT TYPE=hidden name="mode" value="savedefaults">');
		enzymes.document.writeln('</FORM>');
		enzymes.document.writeln('');
		enzymes.document.writeln('</CENTER>');
		enzymes.document.writeln('</BODY>');
		enzymes.document.writeln('</HTML>');
		enzymes.document.writeln('<HTML>');
		getValues(enzymes);

		enzymes.document.close();
	
	}
}

function saveDefaultsClick(popup)
{
	if (checkOffset(last_offset, popup) && 
		checkFields(last_row, null, popup) && 
		areYouSure(popup))
	{
		popup.document.forms[0].submit();
		return true;
	}

	return false;
}

function saveClick(popup)
{
	
	if (checkOffset(last_offset, popup) && checkFields(last_row, null, popup))
	{
		saveValues(popup);
		popup.close();
	}
}

function updateEnzyme()
{
	var f = document.forms[0];
	var listValue = f.Enzyme.options[f.Enzyme.selectedIndex].text;

	for (i=1; i <= $MAX_ENZYMES; i++)
	{
		if (f['enz_name' + i].value == listValue)
			break;
	}

	f.sites.value = f['enz_sites' + i].value;
	f.nosites.value = f['enz_no_sites' + i].value;
	f.offset.value = f['enz_offset' + i].value;

}

function areYouSure(popup)
{
	for (i=0; i < popup.document.forms[0].elements.length; i++)
	{
		var elt = popup.document.forms[0].elements[i];

		if (elt.type == 'text' && elt.name.substring(0,8) != "enz_name")
				elt.value = elt.value.toUpperCase();
	}

	var ays = popup.confirm('Do you want to change the ENZYME DEFAULTS FILE?\\nThe changes will affect OTHER programs as well.');

	if (ays)
		return true;
	else
		return false;
}

function checkFields(last_row, curr_row, popup)
{
	//as a result of checkOffset
	if (from_offcheck)
	{
		from_offcheck = false;
		return true;
	}

	if (curr_row && (!last_row || last_row == curr_row))
		return true;

	var f = popup.document.forms[0];

	f['enz_name' + last_row].value = f['enz_name' + last_row].value.replace(/\\s/g, '');
	f['enz_offset' + last_row].value = f['enz_offset' + last_row].value.replace(/\\s/g, '');
	f['enz_sites' + last_row].value = f['enz_sites' + last_row].value.replace(/\\s/g, '');
	f['enz_no_sites' + last_row].value = f['enz_no_sites' + last_row].value.replace(/\\s/g, '');

	if (!(f['enz_name' + last_row].value != '' &&  f['enz_offset' + last_row].value != '' && f['enz_sites' + last_row].value != '' && f['enz_no_sites' + last_row].value != '') &&
		!(f['enz_name' + last_row].value == '' &&  f['enz_offset' + last_row].value == '' && f['enz_sites' + last_row].value == '' && f['enz_no_sites' + last_row].value == ''))
	{
		var empty;
		var lables = ['enz_name', 'enz_offset', 'enz_sites', 'enz_no_sites'];

		for (i=0; i < lables.length; i++)
		{	
			var field = f[lables[i] + last_row];
			if (field.value == '')
			{
				popup.alert('Some of the fields for enzyme number ' + last_row + ' are empty!!!');
				field.focus();
				field.select();
				return false;
			}
		}
	}

	return true;
}

function checkOffset(offset, popup)
{

	if (!offset || offset.value == '')
		return true;

	if (offset.value > 1 || offset.value < 0)
	{

		popup.alert('Offset values can only be 0 or 1');
		
		offset.value = '';
		from_offcheck = true;
		offset.focus();
		offset.select();
		return false;
	}

	return true;
}

function addMassCheck(win)
{
	var f = win.document.forms[0];
	var addmasses = f.addmass.value.toString().split(',');
	if (f.addmass.value == '')
		addmasses.length = 0;

	var locations = f.locations.value.toString().split(',');
	if (f.locations.value == '')
		locations.length = 0;

	if (addmasses.length > 1)
	{
		alert ('ERROR: Only a single mass modification is allowed!!!');
		f.addmass.focus();
		f.addmass.select();
		return false;
	}

	return true;

}

function clearAll()
{
	self.location = '$ourname';
}

function saveState()
{
	document.forms[0].mode.value = "save_state";
	document.forms[0].submit();
}

function setPartialsMass(chbox)
{
	var min = document.forms[0].minmass.value;
	var max = document.forms[0].maxmass.value;

	if (min == '' || max == '')
	{	
		if (chbox.checked == true)
		{
			if (min == '')
			{
				document.forms[0].minmass.value = "$DEFS_PEPCUT{'Partials Min'}";
			}

			if (max == '')
			{
				document.forms[0].maxmass.value = "$DEFS_PEPCUT{'Partials Max'}";
			}
		}
	}

}


//-->
</script>

<form method=post action="$ourname" onSubmit="updateEnzyme(); return addMassCheck(self);">
<INPUT TYPE=hidden NAME="mode" VALUE="run">
EOF

print "<INPUT TYPE=hidden NAME='Dir' value=$FORM{'Dir'}>\n" if ($FORM{'Dir'});

print <<EOF;
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
<TR>
<TD>
	<TABLE CELLSPACING=0 CELLPADDING=0 border=0 width=100%>
	<TR height=25>		
		<TD class=smallheading bgcolor=$TITLEBGCOLOR>&nbsp;&nbsp;Enter&nbsp;protein&nbsp;&nbsp;</TD>
		<TD class=smallheading bgcolor=$TITLEBGCOLOR>
			<INPUT TYPE=RADIO NAME="type_of_query" VALUE=0 $checked{"type_of_query=0"}>&nbsp;sequence&nbsp;
		</TD>
		<TD class=smallheading bgcolor=$TITLEBGCOLOR><INPUT TYPE=RADIO NAME="type_of_query" VALUE=1 $checked{"type_of_query=1"}>identifier&nbsp;from&nbsp;db:&nbsp;
EOF

# The following based on sequence_lookup.pl
&get_dbases;

# make dropbox:
&make_dropbox ("database", $FORM{'database'}, @ordered_db_names);
  print "	</TD>\n";
  print "	<TD class=title>Frame:&nbsp;</TD>\n";
  print "	<TD width=1 bgcolor=$TITLEBGCOLOR>\n";
  print qq(<SPAN CLASS="dropbox"><SELECT NAME="frame">\n);
  
  foreach $value ('+1', '+2', '+3', '-1', '-2', '-3') {
    print ("		<OPTION");
    print $sel{"frame=$value"};
    print (">$value\n");
  }
  print ("		</SELECT></SPAN>&nbsp;\n");
  print "	</TD>";
  print "</TR>";
  print "</TABLE>";
  print "</TD></TR>";

 # if ($fasta_info) 
  #{	
#	print "$fasta_info<BR>";
#		$fasta_info=~ s/\r//g;
#		$FORM{'query'} = "&gt;$fasta_info\n" . $protein;
 # }

print <<EOF;
<tr><td style="font-size:3" bgcolor=$CELLBGCOLOR>&nbsp;</td></tr>
<TR>
	<TD align=center bgcolor=$CELLBGCOLOR>
		<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0>
		<TR>
			<TD>
				<tt><TEXTAREA name="query" rows=8 cols=90 WRAP=VIRTUAL class=outline>$FORM{'query'}</textarea></tt>			
			</TD>
		</TR>
		</TABLE>
	</TD>
</TR>
<tr><td style="font-size:3" bgcolor=$CELLBGCOLOR>&nbsp;</td></tr>
<TR>
	<TD height=10>
	</TD>
</TR>

<TR>
<TD>
	<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 width=100%>
	<TR BGCOLOR=$CELLBGCOLOR height=30>
		<TD ALIGN=RIGHT class=smallheading>&nbsp;&nbsp;Enzyme:&nbsp;&nbsp;
			<span class="dropbox"><select name="Enzyme">
EOF

	for $enz_name (@enzymes)
	{
		print <<ENZYME;
					<option$sel{"enzyme=$enz_name"}>$enz_name
ENZYME
	}
	my $helplink = &create_link();

	print <<EOF;
					</select></span>
			</TD>
			<TD>&nbsp;&nbsp;&nbsp;<input type="submit" class="outlinebutton button" style="cursor:hand" value=" Cut ">
				&nbsp;&nbsp;<input type="button" class="outlinebutton button" value="Save State" style="cursor:hand" onClick="saveState()">
				&nbsp;&nbsp;<input type="button" class="outlinebutton button" value="Clear" style="cursor:hand" onClick="clearAll()">
				&nbsp;&nbsp;<input type="button" class="outlinebutton button" value="Edit Enzymes" style="cursor:hand" onClick="enzymes_open()">
				&nbsp;&nbsp;$helplink
			</TD>
			<TD class=smallheading>&nbsp;&nbsp;<INPUT TYPE=RADIO NAME="MassType" VALUE=1$checked{"MassType=1"}>Mono
				<INPUT TYPE=RADIO NAME="MassType" VALUE=0$checked{"MassType=0"}>&nbsp;Avg&nbsp;
			</TD>
			</TR>
			</TABLE>
		</TD>
	</TR>
	<TR>
		<TD HEIGHT=17>
		</TD>
	</TR>
	<TR><td width=100%><TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 width=100%>
		<TR><td valign=top><TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
		<tr>
			<TD class=title width=70>Sort:&nbsp;&nbsp;</TD>
			<TD BGCOLOR=$CELLBGCOLOR colspan=4>
				<input type="radio" name="order" value="position"$checked{"order=position"}>
				<span class=smallheading>Position&nbsp;&nbsp;</span>
			</td>
		</TR>
		<TR>
			<TD class=title>&nbsp;</TD>
			<TD BGCOLOR=$CELLBGCOLOR colspan=4>
				<input type="radio" name="order" value="mass"$checked{"order=mass"}>
				<span class=smallheading>Mass</span>
			</td>
		</TR>
		<TR>
			<TD class=title>&nbsp;</TD>
			<TD BGCOLOR=$CELLBGCOLOR colspan=4>
				<input type="radio" name="order" value="retention"$checked{"order=retention"}>
				<span class=smallheading>Retention</span>
			</td>
		</TR>
		<TR>
			<TD class=title>&nbsp;</TD>
			<TD BGCOLOR=$CELLBGCOLOR colspan=4>
				<input type="radio" name="order" value="retengraph"$checked{"order=retengraph"}>
				<span class=smallheading>Predicted&nbsp;chromatogram</span>
			</td>
		</TR>
	<TR><TD HEIGHT=17></TD></TR>
		<tr><td style="font-size:3" class=title width=70>&nbsp;</td><td style="font-size:3" class=data colspan=4>&nbsp;</td></tr>
		<tr>
			<TD class=title width=70 valign=top>Mods:&nbsp;&nbsp;</TD>
			<TD BGCOLOR=$CELLBGCOLOR class=smallheading width=75 align=right>&nbsp;&nbsp;&nbsp;Cysteine:&nbsp;&nbsp;</td>
				<td BGCOLOR=$CELLBGCOLOR colspan=3><span class="dropbox"><select name="cys_alkyl">
					<option value="CAP" $sel{"cys_alkyl=CAP"}>Aminopropyl (AP)
					<option value="CAM" $sel{"cys_alkyl=CAM"}>Carboxyamidomethyl (CAM)
					<option value="CM" $sel{"cys_alkyl=CM"}>Carboxymethyl (CM)
					<option value="free" $sel{"cys_alkyl=free"}>Free thiol (SH)
					<option value="PA" $sel{"cys_alkyl=PA"}>Propionoamino (PA)
					<option value="PE" $sel{"cys_alkyl=PE"}>Pyridylethyl (PE)
					</select></span>
			</TD>
		</tr>
		<TR>
			<TD bgcolor=$TITLEBGCOLOR></TD>
			<TD BGCOLOR=$CELLBGCOLOR class=smallheading align=right width=75>&nbsp;Add&nbsp;Mass:&nbsp;&nbsp;</td>
			<TD BGCOLOR=$CELLBGCOLOR><INPUT NAME="addmass" SIZE=6 value="$FORM{'addmass'}">&nbsp;&nbsp;
			<TD BGCOLOR=$CELLBGCOLOR><span class=smallheading title="Single letter AA codes or/and residue numbers">Residue(s):&nbsp;&nbsp;</span></td>
			<TD BGCOLOR=$CELLBGCOLOR><INPUT NAME="locations" SIZE=14 value="$FORM{'locations'}">&nbsp;&nbsp;</TD>
		</tr>
		<tr><td style="font-size:2" class=title width=70>&nbsp;</td><td style="font-size:2" class=data>&nbsp;</td></tr>
		</table>
	</td>
   <td valign=top align=right><TABLE CELLSPACING=0 CELLPADDING=0 BODRER=0>
		<tr><TD class=title width=70>Display:&nbsp;&nbsp;</TD>
		<TD BGCOLOR=$CELLBGCOLOR colspan=4>
			<input type="radio" name="charges" value="Mr" $checked{"charges=Mr"}>
			<script>
				if (isIE)
					document.write("<span class=smallheading>M<sub style='font-size:110%'>r</sub></span>");
				if (isNN)
					document.write("<span class=smallheading>Mr</span>");
			</script>			
			<input type="radio" name="charges" value="m/z" $checked{"charges=m/z"}>
			<span class=smallheading>m/z</span>
		 </td>
		 </TR>
		<TR><TD class=title>&nbsp;</td>
			<td bgcolor=$CELLBGCOLOR colspan=4><INPUT TYPE=CHECKBOX NAME="disp_sequence"$checked{"disp_sequence"}>
				<span class=smallheading>Sequence</span>
			</TD>
		</TR>
		<TR><TD class=title>&nbsp;</td>
			<TD bgcolor=$CELLBGCOLOR colspan=4><input type=checkbox name="methionine"$checked{"methionine"} value="oxidize">
				<span class=smallheading>Oxidized&nbsp;methionines</span>
			</TD>
		</TR>
		<TR><TD class=title>&nbsp;</td>
			<TD bgcolor=$CELLBGCOLOR colspan=4><INPUT TYPE=CHECKBOX NAME="disp_unmodified"$checked{"disp_unmodified"}>
				<span class=smallheading>Unmodified&nbsp;&nbsp;&nbsp;&nbsp;</span>
			</TD>
		</TR>			
		<TR><TD class=title>&nbsp;</td>
			<td bgcolor=$CELLBGCOLOR colspan=4><INPUT TYPE=CHECKBOX NAME="partials" $checked{'partials'} onClick="setPartialsMass(this)">
				<span class=smallheading>Partials</span>
			</TD>
		</TR>
		<TR><TD class=title>&nbsp;</td>
			<TD bgcolor=$CELLBGCOLOR><span class=smallheading>&nbsp;&nbsp;Min:&nbsp;</span></td>
			<TD bgcolor=$CELLBGCOLOR><input type=text name=minmass maxlength=7 size=6 value="$FORM{'minmass'}"></td>
			<TD bgcolor=$CELLBGCOLOR align=right><span class=smallheading>&nbsp;&nbsp;Max:&nbsp;</span></td>
			<TD bgcolor=$CELLBGCOLOR><input type=text name=maxmass maxlength=7 size=6 value="$FORM{'maxmass'}">
				<span class=smallheading>&nbsp;Da&nbsp;&nbsp;</span>
			</TD>
		</TR>
		<TR><TD class=title>&nbsp;</td>
			<TD bgcolor=$CELLBGCOLOR align=right><span class=smallheading>&nbsp;&nbsp;Begin:&nbsp;</span></td>
			<TD bgcolor=$CELLBGCOLOR><INPUT NAME="begin" value="$FORM{'begin'}" SIZE=6 MAXLENGTH=6></td>
			<TD bgcolor=$CELLBGCOLOR align=right><span class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;End:&nbsp;</span></td>
			<TD bgcolor=$CELLBGCOLOR><INPUT NAME="end" value="$FORM{'end'}" SIZE=6 MAXLENGTH=6>
			</TD>
		</TR></TABLE></TD></tr></table></tr>
	</TR>
	<TR><TD HEIGHT=17></TD></TR>
	<TR><td><table CELLSPACING=0 CELLPADDING=0 BORDER=0>
		<tr><td style="font-size:3" class=title width=70>&nbsp;</td><td style="font-size:3" class=data colspan=2>&nbsp;</td></tr>
		<tr>
		<TD class=title valign=top width=70>Highlight:&nbsp;&nbsp;</TD>
		<TD class=smallheading bgcolor=$CELLBGCOLOR valign=top align=right width=75>Sequences:&nbsp;&nbsp;</td>
		<td bgcolor=$CELLBGCOLOR><tt><textarea NAME="searchseq" cols=71 rows=3 class=outline>$FORM{'searchseq'}</textarea></tt>&nbsp;</TD>
		</TR>
		<TR><TD bgcolor=$TITLEBGCOLOR></TD>
		<TD BGCOLOR=$CELLBGCOLOR align=right width=75><span class=smallheading>m/z:&nbsp;&nbsp;</span></td>
		<td BGCOLOR=$CELLBGCOLOR><INPUT SIZE=10 MAXLENGTH=10 NAME="searchmass" value="$FORM{'searchmass'}">&nbsp;&nbsp;
			<span class=smallheading>+/-&nbsp;</span>
			<INPUT SIZE=3 MAXLENGTH=3 NAME="tolerance" value="$FORM{'tolerance'}">
		</TD>
		</TR>
		</TABLE></TD></TR>
	</TABLE></TD></TR></TABLE>

EOF

#printing some hidden fields for data exchange with EditEnzyme popup
foreach $num (1..$MAX_ENZYMES)
	{
		my $enz_name = $enzymes[$num - 1];
	print <<ENZINFO;
<INPUT TYPE=hidden NAME="enz_name$num" VALUE="$enz_name">
<INPUT TYPE=hidden NAME="enz_offset$num" VALUE="$offset{$enz_name}">
<INPUT TYPE=hidden NAME="enz_sites$num" VALUE="$sites{$enz_name}">
<INPUT TYPE=hidden NAME="enz_no_sites$num" VALUE="$nonsites{$enz_name}">

ENZINFO
	}
		
	print <<EOF;
<INPUT TYPE=hidden NAME="sites">
<INPUT TYPE=hidden NAME="nosites">
<INPUT TYPE=hidden NAME="offset">
</FORM>
<SCRIPT language='JavaScript'>
	updateEnzyme();

	if ("yes" == "$DEF_PEPCUT{'Partials'}")
		setPartialsMass(document.forms[0].partials);
	
	if (isIE)
		document.forms[0].query.cols=86;

	
</SCRIPT>



</body>
</html>
EOF

}

sub get_dbtype {
  my ($db) = $_[0];
  my ($line, $numchars, $numnucs, $numlines);

  open (DB, "$db") || die ("Could not open database $db for auto-detecting database type.");
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

sub save_enzyme_info()
{
	my $enz_copy = $ENZYME_FILE.'.previous';
	copy($ENZYME_FILE, $enz_copy);
	open DEFAULTS, ">$ENZYME_FILE" or die "Can't open enzyme file $ENZYME_FILE $!\n";
	
	print DEFAULTS sprintf ("%-30s%-10s%-15s%-10s\n", 'Name', 'Offset', 'Sites', 'No-sites');
	foreach $num (1..$MAX_ENZYMES)
	{
		if ($FORM{"enz_name$num"} ne '')
		{	
			print DEFAULTS sprintf ("%-30s%-10s%-15s%-10s\n", $FORM{"enz_name$num"}, $FORM{"enz_offset$num"}, $FORM{"enz_sites$num"}, $FORM{"enz_no_sites$num"});
		}
	}

	close DEFAULTS;


	
	print <<EOF;
	<script>
		opener.location.reload();
		self.close();
	</script>
	
	</html>
EOF
}

#copied from flicka.pl
sub print_buttons {
	my $ncbi_type = "p";
    my $type = $FORM{"type_of_query"};

	
	#if a database query pass only first 15 chars of identifier
	my $ref = $type == 1? substr($fasta_info,0, 15) : url_encode($FORM{'query'});
	my $temp = $ref;
	my $dir_query = "&Dir=". url_encode($FORM{'Dir'}) if (defined $FORM{'Dir'});
	my $frame_query = "";
	my $frame_query1 = "";
	
    if ($is_nucleo) { 
		$ncbi_type = "n";
		$frame_query = "&frame=$frame";
		$frame_query1 = "&frame1=$frame";
	}
	
	#$ref =~ s/\*//g;
	# DJW moved sendto buttons 7/22.  
	$searchstrings = url_encode($FORM{"searchseq"});
	# If we want a backlink, make it. In this case the query string must be a substring of $fasta_info
	if($FORM{"mode"} eq "backlink_run")
	{
		print <<EOF;
		<span class='actbuttonover' style='width=90' onclick="document.pepcutform.submit()"><nobr>Change Params</nobr></span>
EOF

	}

	if ($FORM{'disp_sequence'})
	{
		print <<EOP;
		<span id=hide_opt></span>
EOP
	}
	if ($order ne 'retengraph')
	{
	    print <<EOM;
	<span class="actbuttonover" style="width=55" onclick="window.open('$pepstat?type_of_query=$type&database=$db&peptide=$ref$frame_query$dir_query&running=1', '_blank')">PepStat</span>
	<span class="actbuttonover" style="width=55" onclick="window.open('$gap?type_of_query1=$type&database1=$db&peptide1=$ref$frame_query1$dir_query', '_blank')">Gap</span>
	<span class='actbuttonover' style='width=55' onClick="document.forms['muquest_form'].submit()">MuQuest</span>
EOM


		$ref = $temp;

  # if reference is from ncbi then show links to Entrez
		if ($ref =~/gi\|/) {

		  $ref =~ /^gi\|(\d*)/;
		  my $myref = $1;
		  print <<EOM;
&nbsp;
<span class='actbuttonover' style='width=58' onClick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=f', '_blank')">Sequence</span>
<span class='actbuttonover' style='width=55' onClick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=m', '_blank')">Abstract</span>
EOM
		#print blast link
		$d = $db;
		$d =~ s!\.fasta!!;

		$ncbi = "$remoteblast?$sequence_param=$protein&";

		if (($d =~ m!dbEST!i) || ($d eq "est")) { $ncbi .= "$db_prg_aa_nuc_dbest"; }
		elsif ($d eq "nt") { $ncbi .= "$db_prg_aa_nuc_nr"; }
		elsif ($d =~ m!yeast!i) { $ncbi .= "$db_prg_aa_aa_yeast"; }
		else { $ncbi .= "$db_prg_aa_aa_nr"; }

		$ncbi.= ($ncbi_type eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type);

		$ncbi .= "&$expect&$defaultblastoptions";

		print qq(<span class='actbuttonover' style='width=55' onclick="window.open('$ncbi', '_blank')">Blast</span>);

	}
	print "<br>";
}

}

sub print_header
{ 
  my $ref = $FORM{'query'};
  print qq(<tr><td class=title style=font-size:4>&nbsp;</td><td style=font-size:4 colspan=3>&nbsp;</td></tr>);
  $fasta_info =~ s/^>*//gi;
  if ($fasta_info =~ m!^\Q$ref\E(\S*\s)(.*)!i) {

		print qq(<tr><td class=title valign=top width=89>Header:&nbsp;</td><td colspan=3 class=data width=653 height=19>&nbsp;$ref$1$2</td></tr>);
  } else {
        print ("<tr><td class=title valign=top width=89>Header:&nbsp;</td><td colspan=3 class=data width=653 height=19>&nbsp;", &HTML_encode ($fasta_info), "</td></tr>");
  }
  print qq(<tr><td class=title style=font-size:4>&nbsp;</td><td style=font-size:4 colspan=3>&nbsp;</td></tr>);

}

sub print_sample_info
{	
	print qq(<br style=font-size:6><table cellpadding=0 cellspacing=0 border=0 width=740 style="border:solid #e4e4e4 1px;">\n) 	if ($FORM{'type_of_query'} eq "1" && defined $db);

	if (defined $FORM{'Dir'})
	{	
		my %dir_info = &get_dir_attribs($FORM{'Dir'});
		print <<INFO;
	<tr height=19><td class=title width=89>Sample:&nbsp;</td>
		<td class=smalltext nowrap width=385>&nbsp;$dir_info{'LastName'},&nbsp;$dir_info{'Initial'}.&nbsp;&nbsp;$dir_info{'Sample'}&nbsp;&nbsp;$dir_info{'SampleID'}&nbsp;&nbsp;</td>
		<td class=title width=75>&nbspDirectory:&nbsp;</td>
		<td class=smalltext width=199>&nbsp;$FORM{'Dir'}</td>
	</tr>
INFO
	}
	if ($FORM{'type_of_query'} eq "1" && defined $db) {
		print <<INFO;
	<tr height=19>
		<td class=title width=89>&nbspReference:&nbsp;</td>
		<td class=smalltext width=385>&nbsp;$FORM{'query'}</td>
		<td class=title width=75>Database:&nbsp;</td>
		<td class=smalltext width=199>&nbsp;$db</td>
	</tr>
INFO
	}
}