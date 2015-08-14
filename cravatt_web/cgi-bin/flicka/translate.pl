#!/usr/local/bin/perl

#-------------------------------------
#	Translate,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/D. J. Weiner
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


##
## For muchem-specific definitions and cgilib routines
##
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
	require "html_include.pl";

}
################################################
 
&cgi_receive();

require "fastaidx_lib.pl";

$type_of_query = $FORM{'type_of_query'};
$type_of_query = $DEFS_TRANSLATE{'Please enter nucleotide'} if(!defined $type_of_query);
$type_of_query = 0 if ($type_of_query eq "sequence");
$type_of_query = 1 if ($type_of_query eq "identifier from indexed database");
$checked{"type_of_query=$type_of_query"} = ' CHECKED';

$DEF_DATABASE = $DEFS_TRANSLATE{'Database'};
if(exists $FORM{'database'}) {
	# Strip off path from database name
	($FORM{'database'}) = ($FORM{'database'} =~ m!([^/]+)$!);
} else {
	$FORM{'database'} = $DEF_DATABASE;
}

$FORM{'frame'} = $DEFS_TRANSLATE{'Frame'} if (!exists $FORM{'frame'});
$sel{"frame=$FORM{'frame'}"} = ' SELECTED';

$FORM{'transl_table'} = $DEFS_TRANSLATE{'Translation Table'} if (!exists $FORM{'transl_table'});
$sel{"transl_table=$FORM{'transl_table'}"} = ' SELECTED';

## a Perl CGI script to converts a
## nucleotide sequence into the corresponding amino acid sequence, in any frame.
##
## Currently uses the standard vertebrate translation table, but it would be possible to allow
## the users to choose from a list of options (vertebrate mitochondria, etc.)
##
## Allowable nucleotides are A, T, C, G. The following "toggle" nucleotides are allowed:
## <ul>
## <li>		Y - pYrimidine (C or T)
## <li>		R - puRine (A or G)
## <li>		N - aNy (A, C, T, or G)
## </ul>
##
## The special codes in the output are the following:
## <ul>
## <li>		X - unknown amino acid (poss stop codon)
## <li>		* - stop codon
## </ul>
##
## Author <a href="mailto:kemo@wjh.harvard.edu">Martin Baker</a>
##


## for the values:
$runHTML = qq(<span style="color:#0099cc" class=smallext>);
$knownrunHTML = qq(<span style="color:#0099cc" class=smallext>);
$num_stopsHTML = qq(<span style="color:#0099cc" class=smallext>);
$num_unknownsHTML = qq(<span style="color:#0099cc" class=smallext>);

$HTMLend = "</span>";

## for best values (longest runs, least stops)
## when translating ALL reading frames
$bestrunHTML = qq(<span style="color:red;" class=smallheading>);
$bestknownrunHTML = qq(<span style="color:red;" class=smallheading>);
$bestnum_stopsHTML = qq(<span style="color:red" class=smallheading>);
$bestnum_unknownsHTML = qq(<span style="color:red" class=smallheading>);

## heading titles:
##
$headingHTML = qq(<span class=smallheading>);
$bestrunTITLE = "Longest ORF:&nbsp;";
$bestknownrunTITLE = "Longest ORF, no X:&nbsp;";
$num_stopsTITLE = "Stops:&nbsp;";
$num_unknownsTITLE =  "X:&nbsp;";



## Headings for best values (longest runs, least stops)
## when translating ALL reading frames
$bestheadingHTML = qq(<span style="color:#8C1717; font-style:italic; font-weight:bold">);


## first, read in data:
$frame = $FORM{"frame"};
# $nuc_seq = $FORM{"pre_text"};
$searchpep = $FORM{"peptide"};

#$nuc_seq =~ s/^\s*>(.*)\n//;
#$fasta_info = $1;

#$nuc_seq =~ tr/a-z/A-Z/; # to uppercase, remove non-alphas
#$nuc_seq =~ tr/A-Z//cd;
#$nuc_seq =~ tr/U/T/;     # in case someone inputs RNA
#$nuc_seq =~ tr/ACTGYRNU/N/c; # unknowns become "N"

# display header
&MS_pages_header ("Translate", "#336699", $nocache);
print "<hr>\n";

# added by david 6/99 to handle database lookups.
if ($FORM{"pre_text"} eq "") {
  &output_form;
  
  #print ("No sequence input provided. Please go back and try again.\n");
  #exit;
} else {

	#we are checking if the sequence is a database identifier regardless of the query method
	#this enables us to do an automatic switch to db query if we have an identifier
	# Ask database -- based on etc/sequence_lookup.pl
	my $database=$FORM{"database"};
	$db = $database;
	$FORM{"pre_text"} =~ s/>//g;
	my $seqid = $FORM{"pre_text"};
	($fid = $seqid) =~ s/\s+//g;
	my @seq;

	$database=~ s/\.fasta//g;
	$seqid = parseentryid($seqid);
  
	chdir($dbdir);

	if (not &openidx($database)) {
		if ($FORM{'type_of_query'}) {
			# we are specifically doing a db lookup so there is nothing to be done but fail 
			print ("<p><i>\nNo flatidx file was found for the $database.fasta database, please generate one before running Pepcut\n</i><p>");

			@text = ("Index $database.fasta", "Goto Translate");
			@links = ("$fastaidx_web?running=ja&Database=$database.fasta", "$ourname");
			&WhatDoYouWantToDoNow(\@text, \@links);
			exit;
		}
	} else {
		(@seq) = lookupseq($seqid);
		&closeidx();
	}

	# DJW 8/12
	if ($seq[0] =~ /^>/)
	{
		$fasta_info = shift @seq;
		$fasta_info =~ s/^>*(.*)$/\1/i;
    }

	$DBnuc_seq = join "\n", @seq;
    $DBnuc_seq =~ s/\n//g;
    $DBnuc_seq =~ s/\s*//g;

	if ($FORM{'type_of_query'} or $DBnuc_seq)
	{
		$nuc_seq = $DBnuc_seq;

		# Check for unsuccessful lookup if method is explicitly by DB
		if ($FORM{'type_of_query'} and (length $DBnuc_seq) == 0)
		{
			print ("Identifier not found in database $database.\n");
			exit;
		}
		#$fasta_info = $1 if ($DBnuc_seq =~ s/^>(.*)\n//);

		#autoswitch to DB if needed
		$type_of_query = $FORM{'type_of_query'} = 1;
		$checked{"type_of_query=$type_of_query"} = ' CHECKED';
	} else {
		$nuc_seq = $FORM{"pre_text"};
		$nuc_seq =~ s/^\s*>(.*)\n//;
		$fasta_info = $1;
		$nuc_seq =~ tr/a-z/A-Z/; # to uppercase, remove non-alphas
		$nuc_seq =~ tr/A-Z//cd;
		$nuc_seq =~ tr/U/T/;     # in case someone inputs RNA
		$nuc_seq =~ tr/ACTGYRNU/N/c; # unknowns become "N"
	}

	



## for the search peptide:
## B is allowed, and is matched against D or N
## Z is allowed, and is matched against E or Q
## X is allowed, and is matched against any
##
## O and J are treated as X is

$searchpep =~ tr/a-z/A-Z/; # to uppercase and remove non-alphas
$searchpep =~ tr/A-Z*//cd;
$searchpep =~ tr/OJ/X/;

$disp_searchpep = $searchpep; # what we will display to the user
$searchlen = length ($searchpep); # the real "length" against which this peptide matches

## now we continue processing $searchpep into a regular expression
##
$q = quotemeta ($STOP);
$searchpep =~ s!$q!$q!g; # quote the STOP symbol (*) to protect it

$searchpep =~ s/B/[DN]/g;
$searchpep =~ s/Z/[EQ]/g;
$searchpep =~ tr/X/./;


## prepare translation apparatus:
##
$transl_table = $FORM{"transl_table"};
$transl_name = &calculateTranslationTable($transl_table);

&print_header;




##
## just one reading frame is simple: display, and exit
##
if ($frame ne "ALL") {
  ($displaystr, $bestrun, $bestknownrun, $num_stops, $num_unknowns) = &translate ($nuc_seq, $frame);
	
	# for send to buttons
	($translated_seq = $displaystr) =~ s/<.*?>|\s//g;	# Strip all html tags and whitespace
	
	$displaystr = "&nbsp;&nbsp;" . $displaystr;
	$displaystr =~ s/(<br>)/$1&nbsp;/g;

	$sep = "&nbsp;" x 5;

  print ("<tr height=20><td class=title>Frame:&nbsp;</td><td class=smalltext nowrap colspan=3>&nbsp;$frame", $sep);
  print ($headingHTML, $bestrunTITLE, $HTMLend, $bestrunHTML, $bestrun, $HTMLend, $sep);
  print ($headingHTML, $bestknownrunTITLE, $HTMLend, $bestknownrunHTML, $bestknownrun, $HTMLend, $sep);
  print ($headingHTML, $num_stopsTITLE, $HTMLend, $bestnum_stopsHTML, $num_stops, $HTMLend, $sep);
  print ($headingHTML, $num_unknownsTITLE, $HTMLend, $bestnum_unknownsHTML, $num_unknowns, $HTMLend, $sep);


  
  print qq(</td></tr>\n);
  print qq(<tr height=25><td class=title width=100>Send To:&nbsp;</td><td class=smalltext colspan=3>&nbsp;\n);
  &print_buttons;
  print qq(</td></tr>);
  print qq(</table><br style=font-size:8><tt class=small>$displaystr</tt><p>\n);

  exit;
}

##
## if we translate into all reading frames, we need to keep track of all values,
## and compute who has the best of each. This is displayed by using different colors
## in the output.
##
## the best of each %array is kept in $array{"best"}

$rev_seq = &reverse_nuc ($nuc_seq); # only do this once 
print qq(</table>);
foreach $f ("+1", "+2", "+3", "-1", "-2", "-3") {
  ($displaystr{$f}, $bestrun{$f}, $bestknownrun{$f}, $num_stops{$f}, $num_unknowns{$f})
    = &translate ($nuc_seq, $f, $rev_seq);
	# Added by Ulas 11/23/98 for pepcut button
	($translated_seq{$f} = $displaystr{$f}) =~ s/<.*?>|\s//g;	# Strip all html tags and whitespace
    # Added by David 6/99 for flicka button
#	if (defined $searchpep) {
#	   ($to_flicka_seq{$f} = $searchpep{$f}) =~ s/\*|\#//g;
#  	} else {
#	   ($to_flicka_seq{$f} = $to_pepcut_seq{$f}) =~ s/\*|\#//g;
#	}

  $bestrun{"best"} = &max ($bestrun{"best"}, $bestrun{$f});
  $bestknownrun{"best"} = &max ($bestknownrun{"best"}, $bestknownrun{$f});
  $num_stops{"best"} = &min ($num_stops{"best"}, $num_stops{$f});
  $num_unknowns{"best"} = &min ($num_unknowns{"best"}, $num_unknowns{$f});
}




$sep = "&nbsp;" x 5;

foreach $frame ("+1", "+2", "+3", "-1", "-2", "-3") {

$translated_seq = $translated_seq{$frame};

if ($bestrun{$frame} == $bestrun{"best"}) {
	$t1 = join ("", $bestrunHTML, $bestrun{$frame}, $HTMLend);
} else {
	$t1 = join ("", $runHTML, $bestrun{$frame}, $HTMLend);
}

if ($bestknownrun{$frame} == $bestknownrun{"best"}) {
	$t2 = join ("", $bestknownrunHTML, $bestknownrun{$frame}, $HTMLend);
} else {
	$t2 = join ("", $knownrunHTML, $bestknownrun{$frame}, $HTMLend);
}

if ($num_stops{$frame} == $num_stops{"best"}) {
	$t3 = join ("", $bestnum_stopsHTML, $num_stops{$frame}, $HTMLend);
} else {
	$t3 = join ("", $num_stopsHTML, $num_stops{$frame}, $HTMLend);
}

if ($num_unknowns{$frame} == $num_unknowns{"best"}) {
	$t4 = join ("", $bestnum_unknownsHTML, $num_unknowns{$frame}, $HTMLend);
} else {
	$t4 = join ("", $num_unknownsHTML, $num_unknowns{$frame}, $HTMLend);
}

$h1 = join ("", $headingHTML, $bestrunTITLE, $HTMLend);
$h2 = join ("", $headingHTML, $bestknownrunTITLE, $HTMLend);
$h3 = join ("", $headingHTML, $num_stopsTITLE, $HTMLend);
$h4 = join ("", $headingHTML, $num_unknownsTITLE, $HTMLend);

print qq(<br style=font-size:8><table cellpadding=0 cellspacing=0 border=0 width=730 style="border:solid #e4e4e4 1px;">\n);

print qq(<tr height=20><td class=title width=100>Frame:&nbsp;</td><td class=smalltext width=630>&nbsp;$frame&nbsp;&nbsp;$sep); 
print qq($h1 $t1 </tt> $sep);
print qq($h2 $t2 </tt> $sep);
print qq($h3 $t3 </tt> $sep);
print qq($h4 $t4 </tt> $sep);
		 
print "</td></tr>";
print qq(<tr height=25><td class=title width=100>Send To:&nbsp;</td><td width=630>&nbsp;);

&print_buttons;
print qq(</td></tr><tr height=5><td></td></tr>\n);

$displaystr{$frame} = "&nbsp;&nbsp;" . $displaystr{$frame};
$displaystr{$frame} =~ s/(<br>)/$1&nbsp;/g;

print "<tr><td colspan=2 width=730><tt class=small>$displaystr{$frame}</tt>\n";
print qq(</td></tr><tr height=3><td></td></tr></table><br style=font-size:8>);


}

} # end of else clause
exit;

# original translate.pl code--transplanted here in its entirety (with slight modifications)
sub output_form 
{
	my $transl_table = $FORM{"transl_table"};
	my $frame = $FORM{"frame"};
	my @frame_array = ('ALL', '+1', '+2', '+3', '-1', '-2', '-3');
	my @transl_table_array = ('Standard',
							  'Vertebrate Mitochondrial', 
							  'Yeast Mitochondrial', 
							  'Mold, Protozoan, and Coelenterate Mitochondrial and Mycoplasma/Spiroplasma', 
							  'Invertebrate Mitochondrial', 
							  'Ciliate Dasycladacean and Hexamita Nuclear', 
							  'Echinoderm Mitochondrial', 
							  'Euplotid Nuclear', 
							  'Bacterial Code', 
							  'Alternative Yeast Nuclear', 
							  'Ascidian Mitochonrial', 
							  'Flatworm Mitochondrial', 
							  'Blepharisma Nuclear');
	 
 print <<EOF;

<div>
<form action="$ourname" method=post>
<table cellpadding=0 cellspacing=0 border=0>
<tr height=28>
	<td bgcolor=#e8e8fa nowrap>
		<span class=smallheading><nobr>&nbsp;&nbsp;Enter nucleotide</nobr></span>
		<INPUT TYPE=RADIO NAME="type_of_query" VALUE=0$checked{"type_of_query=0"}>
		<span class=smallheading>sequence</span>
		<INPUT TYPE=RADIO NAME="type_of_query" VALUE=1$checked{"type_of_query=1"}>
		<span class=smallheading>identifier&nbsp;from&nbsp;db:&nbsp;</span>
EOF

# The following based on sequence_lookup.pl
&get_dbases;

# make dropbox:
&make_dropbox ("database", $FORM{'database'}, @ordered_db_names);

	print <<EOF;
		<span class=smallheading>&nbsp;&nbsp;Frame:&nbsp;</span>
		<SPAN CLASS="dropbox"><SELECT NAME="frame">
EOF

  foreach $value (@frame_array) 
  {
	print <<EOF;
				<OPTION$sel{"frame=$value"}>$value
EOF
  }
  my $helplink = &create_link;
  my $translink = &create_link(link=>"http://www.ncbi.nlm.nih.gov/htbin-post/Taxonomy/wprintgc?mode=c", text=>"Translation Table:");
  print <<EOF;
		</SELECT></SPAN>&nbsp;
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2>&nbsp;</td></tr>
<tr bgcolor=#f2f2f2>
	<td align=center>
		<tt><textarea name="pre_text" rows=15 cols=88 class=outline>$FORM{'pre_text'}</textarea></tt><BR>
	</td>
</tr>
<tr><td style="font-size:3" bgcolor=#f2f2f2>&nbsp;</td></tr>
<tr height=5><td>&nbsp;</td></tr>
<tr>
	<td>
		<input type=submit class="outlinebutton button" value="Translate">&nbsp;&nbsp;&nbsp;
		<input type=reset class="outlinebutton button" value="Clear">&nbsp;&nbsp;&nbsp;
		<span class=smallheading>Highlight&nbsp;Peptide:&nbsp;&nbsp;</span>
		<input name="peptide" SIZE=45>
		&nbsp;&nbsp;&nbsp;$helplink
	</td>
</tr>
<tr height=5><td>&nbsp;</td></tr>
<tr>
	<td>$translink&nbsp;&nbsp;<SPAN CLASS="dropbox"><SELECT NAME="transl_table">
EOF
	foreach $val (@transl_table_array) 
	{
		print <<EOF;
				<OPTION $sel{'$transl_table=$val'}>$val
EOF
	}

	print <<EOF;
				</SELECT></SPAN>
	</td>
</tr>
</table>
</FORM>

<!--
<h2 style="color:#8C1717"><i>Instructions:</i></h2>

This program will convert a nucleotide sequence to an amino acid
sequence. The following special nucleotides are recognized:

<ul>
<li>         Y - pYrimidine (C or T)
<li>         R - puRine (A or G)
<li>         N - aNy (A, C, T, or G)
<li>         U - uridine (uracil) is treated just like T, in case an RNA
rather than an DNA sequence is entered.
</ul>

The special characters in the output are the following:
<ul>
<li>         X - unknown or ambiguous amino acid (possibly a stop codon)
<li>         * - stop codon
</ul>

The Peptide input field will let you specify an amino acid sequence which
the Translate program will search for in the resulting translated
sequences. In the search peptide:
<ul>
<li> B is allowed, and is matched against D or N.
<li> Z is allowed, and is matched against E or Q.
<li> X is allowed, and is matched against any character.
<li> O and J are treated as X is.
<li> * is allowed, and is matched against a stop codon.
<li> All other characters are ignored.
</ul>
-->

</div>
</body>
</html>
EOF

}

sub print_header
{ 
	my $ref = $FORM{'pre_text'};
	print qq(<table cellpadding=0 cellspacing=0 border=0 width=730 style="border:solid #e4e4e4 1px;">);
	if ($fasta_info) {
	 	print <<HEADER;
	<tr height=20><td class=title width=100>Referance:&nbsp;</td>
		<td class=smalltext width=280>&nbsp;$ref</td>
		<td class=title width=80>Database:&nbsp;</td>
		<td class=smalltext width=270>&nbsp;$db</td>
	</tr>
	<tr height=5><td class=title></td><td></td></tr>
	<tr><td class=title valign=top width=100>Header:&nbsp;</td>
HEADER

		$fasta_info =~ s/^>*//gi;
		if ($fasta_info =~ m!^\Q$ref\E(\S*\s)(.*)!i)
		{
			print qq(<td class=data colspan=3 height=19 width=630>&nbsp;$ref$1$2</td></tr>);
		}
		else
		{
			print ("<td class=data colspan=3 height=19 width=630>&nbsp;", &HTML_encode ($fasta_info), "</td></tr>\n");
		}
		print qq(<tr height=5><td class=title></td><td></td></tr>);
	}
	print <<LEGEND;
<tr height=20><td class=title width=100>Legend:&nbsp;</td>
	<td class=smalltext colspan=2>&nbsp;$STOPhtml = Stop&nbsp;&nbsp;&nbsp; $UNKNOWNhtml = unknown or ambiguous codon</td>
	<td class=smalltext><a href = "$trans_table_page#SG$transl_table">The $transl_name</a></td></tr>
LEGEND
	if ($searchpep) {
		print qq(</tr><tr height=20><td class=title width=100 nowrap>Search peptide:&nbsp;</td><td class=smalltext colspan=3>&nbsp;$matchHTML$disp_searchpep$matchHTMLend</td>);
	}
}

#modified from flicka.pl
sub print_buttons {
    my $type = $FORM{"type_of_query"};

	
	#if a database query pass only first 15 chars of identifier
	my $ref = $type == 1? substr($fasta_info,0, 15) : $translated_seq;
	my $temp = $ref;
	my $dir_query = "&Dir=". url_encode($FORM{'Dir'}) if (defined $FORM{'Dir'});
	
	my $ncbi_type = "n";
	
	my $myframe = $frame;
	#$myframe =~ s/^\+//;

	my $frame_query = "&frame=$myframe";
	my $frame_query1 = "&frame1=$myframe";
	
	#$ref =~ s/\*//g;
	# DJW moved sendto buttons 7/22.  
	$searchstrings = url_encode($FORM{"peptide"});

    print <<EOM;
	<span class="actbuttonover" style="width=55" onclick="window.open('$pepcut?mode=backlink_run&type_of_query=$type&database=$db&query=$ref&searchseq=$searchstrings$frame_query$dir_query&MassType=$FORM{MassType}&disp_sequence=yes', '_blank')">PepCut</span>
	<span class="actbuttonover" style="width=55" onclick="window.open('$pepstat?type_of_query=$type&database=$db&peptide=$ref$frame_query$dir_query&running=1', '_blank')">PepStat</span>
EOM

	# print link to GAP
	print <<EOM;
	<span class="actbuttonover" style="width=55" onclick="window.open('$gap?type_of_query1=$type&database1=$db&peptide1=$ref$frame_query1$dir_query', '_blank')">Gap</span>
    <!--<form action="$remoteblast" name=blast method=post>-->
EOM
   
	#print blast link
$d = $db;
$d =~ s!\.fasta!!;

$ncbi = "$remoteblast?$sequence_param=$translated_seq&";

if (($d =~ m!dbEST!i) || ($d eq "est")) { $ncbi .= "$db_prg_aa_nuc_dbest"; }
elsif ($d eq "nt") { $ncbi .= "$db_prg_aa_nuc_nr"; }
elsif ($d =~ m!yeast!i) { $ncbi .= "$db_prg_aa_aa_yiest"; }
else { $ncbi .= "$db_prg_aa_aa_nr"; }

$ncbi.= ($ncbi_type eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type);

$ncbi .= "&$expect&$defaultblastoptions";

print qq(<span class="actbuttonover" style="width=55" onclick="window.open('$ncbi', '_blank')">Blast</span>);

$ref = $temp;

  # if reference is from ncbi then show links to Entrez
  if ($ref =~/gi\|/) {

  $ref =~ /^gi\|(\d*)/;
  my $myref = $1;
  print <<EOM;
&nbsp;<span class=actbuttonover style="width=58" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=f', '_blank')">Sequence</span>
<span class=actbuttonover style="width=55" onclick="window.open('http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=m', '_blank')">Abstract</span>
EOM
}
print "<br>";

}