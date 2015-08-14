#!/usr/local/bin/perl

#-------------------------------------
#	Protein Report,
#	(C)1999-2002 Harvard University
#	
#	W. S. Lane / Matthew Schweitzer
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------

##MICROCHEM_FILE##


################################################
# Created: 7/1/2002 by Matthew Schweitzer
#
# Description: Reports on proteins
#
################################################

################################################
# find and read in standard include file
BEGIN {
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
### Additional includes

require "fastaidx_lib.pl";
require "fasta_include.pl";

use strict;
use vars qw(%FORM $ourname $ourshortname $webimagedir $tempdir $webtempdir $dbdir $stylesheet_html $server $seqdir $webseqdir);
use vars qw(@dbases $stylesheet_IE $stylesheet $pepstat $pepcut $gap $webmuquest $NCBI);

use GD;

&cgi_receive;

my $title = "Protein Report";
my $title_color = "#0000cc";
my $darkhighlight = "#ddddf4";			# #d0d0d0
my $lighthighlight = "#f2f2f2";			# #e4e4e4

#######################################
## STYLES
my $report_style = <<STYLE;
<style type="text/css">
span.pep { background-color:#ffff00; }
span.m1 { background-color:#00ff00; }
span.m2 { background-color:#00ffff; }
span.m3 { background-color:#ff00ff; }
span.m4 { background-color:#ff8800; }
span.m5 { background-color:#ff5050; }
span.m6 { background-color:#9966ff; }
span.m7 { background-color:#cccccc; }
span.m8 { background-color:#eeeeee; }
pre { margin-bottom:0; }
.smallheading { color:#1e1e90; }
td.bgc { background-color:#ddddf4; }
body {
	scrollbar-3dlight-color:#333366;
	scrollbar-arrow-color:#333366;
	scrollbar-base-color:#ddddf4;
	scrollbar-darkshadow-color:#333366;
	scrollbar-face-color:#ddddf4;
	scrollbar-highlight-color:#ddddf4;
	scrollbar-shadow-color:#aaaaf0;
}
</style>
STYLE

my $head_style = <<STYLE;
<style type="text/css">
.outline {
	scrollbar-3dlight-color:#333366;
	scrollbar-arrow-color:#333366;
	scrollbar-base-color:#ddddf4;
	scrollbar-darkshadow-color:#333366;
	scrollbar-face-color:#ddddf4;
	scrollbar-highlight-color:#ddddf4;
	scrollbar-shadow-color:#aaaaf0;
	border:solid #000099 1px;
}
.outlinebutton {
	border:solid #000099 1px;
	background-color:#ddddf4;
}
.helpballoon {
	position:absolute;
	visibility:hidden;
	left:0;
	top:0;
	background-color:#ffff99;
	border:solid #0000cc 1px;
	padding:2px;
}
.actbutton {
	background-color:#ffffff;
	border:solid #ffffff 2px;
	text-align:center;
	vertical-align:middle;
	cursor:hand;
	font-family:Verdana;
	font-size:7.5pt;
	font-weight:bold;
	color:#3333cc;
}
.actbuttonover {
	background-color:#eeeeff;
	border:solid 2px;
	border-color:#d5d5ff #aaaacc #aaaacc #d5d5ff;
	text-align:center;
	vertical-align:middle;
	cursor:hand;
	font-family:Verdana;
	font-size:7.5pt;
	font-weight:bold;
	color:#3333cc;
}
.actbuttondown {
	background-color:#ddddf4;
	border:solid 2px;
	border-color:#aaaacc #ffffff #ffffff #aaaacc;
	text-align:center;
	vertical-align:middle;
	cursor:hand;
	font-family:Verdana;
	font-size:7.5pt;
	font-weight:bold;
	color:#3333cc;
}
</style>
STYLE
## END STYLES
#######################################


#### IMPORTANT NOTE ####
#
# Only three conditions must be met for this program to generate a report:
#    1. The variable $compare_against MUST be set to either "REF" or "SEQ"
#    2. If $compare_against is "REF", both $ref and $db MUST be defined
#    3. If $compare_against is "SEQ", $entered_sequence MUST be defined AND contain letters
#
# Do not change this (that is, rely on other conditions).  If a value is not defined, just
#  leave it out and generate everything else.  These three conditions are the interface for
#  this program - changing them will disallow backward compatibility both with other programs
#  that send data here and reports that have been saved using older versions.
#
########################

&load_dialog if $FORM{"loadwindow"};

my $db = $FORM{"db"};
my $ref = $FORM{"ref"};
my $pepstring = uc $FORM{"peptides"};
my $compare_against = uc $FORM{"compare_against"};
my $entered_sequence = uc $FORM{"sequence"};
my $ticstring = $FORM{"tics"};
my $showallrows = (defined $FORM{"hiderows"}) ? 0 : 1;
my $showpeptides = (defined $FORM{"hidepeplist"}) ? 0 : 1;
my $is_nucleo = $FORM{"isnuc"};											# should evaluate true if this is nucleotide, false otherwise
my $selected_frame = $FORM{"frame"};
my $dir = $FORM{"directory"};
my $sample = $FORM{"sample"};
my $comments = $FORM{"comments"};
my $seqcomments = $FORM{"seqcomments"};
my $seqstartpos = $FORM{"startposition"};
my $usehtml = (exists $FORM{"usehtml"}) ? $FORM{"usehtml"} : "yes";		# default: use html for settings box
my $savereport = lc $FORM{"savereport"};								# can be 'html' or 'data'
my $load_filename = $FORM{"loadfile"};
#$savereport = "data";
my @label_list = ();
for (1..8) {
	$label_list[$_] = $FORM{"m${_}Label"} || "";
}

#######################################
## load data from file, if requested
if ($load_filename) {
	use XML::Dumper;
	use XML::Parser;
	my $dumper = new XML::Dumper;
	my $parser = new XML::Parser(Style => 'Tree');

	open XMLFILE, "$load_filename" or &error("Error! Could not load $load_filename.");
	my @input_lines = <XMLFILE>;
	close XMLFILE;

	my $xml_data = join "", @input_lines;
	my $xml_tree = $parser->parse($xml_data);
	my $data = $dumper->xml2pl($xml_tree);

	$db = $data->{db};
	$ref = $data->{ref};
	$dir = $data->{dir};
	$compare_against = $data->{compare_against};
	$entered_sequence = $data->{entered_sequence};
	$showallrows = $data->{showallrows};
	$showpeptides = $data->{showpeptides};
	$is_nucleo = $data->{is_nucleo};
	$sample = $data->{sample};
	$comments = $data->{comments};
	$seqcomments = $data->{seqcomments};
	$usehtml = $data->{usehtml};
	$pepstring = $data->{pepstring};
	$seqstartpos = $data->{startposition};
	my $labelref = $data->{labels};
	@label_list = $labelref ? @{$labelref} : ();

	$savereport = "";				# don't want to load and save a file at the same time
}
## end file load
######################################

#my $showallrows = 1;					# sets whether all rows are shown
$entered_sequence =~ s/[^A-Z]//g;		# remove non-letters

&output_form unless ($compare_against eq 'REF' || $compare_against eq 'SEQ');
&output_form if ($compare_against eq 'REF' && (! $ref || ! $db));
&output_form if ($compare_against eq 'SEQ' && ! $entered_sequence);

######################################
# Global parameters

my $space_after = 10;
my $space_char = ' ';
my $space_length = length $space_char;
my $wrap_after = 80;						# note: this must be an integer multiple of $space_after
my $character_width = 8;					# note: this MUST be correct for the fixed-width font used for sequence display on this page
my $masstype = "average";
my @frames = ("+1", "+2", "+3", "-1", "-2", "-3");

my %modchars = ('*' => 1, '#' => 2, '@' => 3, '^' => 4, '~' => 5, '$' => 6, ']' => 7, '[' => 8);	# these are the mod site characters 
my $modregexp = "\\*\\#\\@\\^\\~\\\$\\\]\\\[";														# update $modregexp when changing %modchars

######################################
# Main action
#

my %dir_info = &get_dir_attribs($dir) if $dir;

$seqstartpos = 1 if ($seqstartpos !~ /^\-?\d+$/);			# This must be a number.  The default is 1.

my ($savefile_location, $savefile_weblocation, $saveimg_location, $saveimg_weblocation) = ("", "", "", "");
my $xml_file = "";
if ($dir && $savereport eq "html") {		# this is for saving a copy of the report in html form, with images, in the sequest directory
	my $imgdirname = "img" . time;
	$savefile_location = "$seqdir/$dir/reports";
	$savefile_weblocation = "$server/$webseqdir/$dir/reports";

	$saveimg_location = "$seqdir/$dir/reports/$imgdirname";
	$saveimg_weblocation = "$imgdirname";
	unless (-e $savefile_location) {
		mkdir $savefile_location, 0777 or &error("Error! Could not create directory $savefile_location to save this report.");
	}
	unless (-e $saveimg_location) {
		mkdir $saveimg_location, 0777 or &error("Error! Could not create directory $saveimg_location to save images for this report.");
	}
} elsif ($dir && $savereport eq "data") {		# this is used to just save the parameters so that a report can be regenerated later
	my $xml_location = "$seqdir/$dir";
	&error("Error! Unable to save file to $xml_location") unless (-e $xml_location);
	$xml_file = "$xml_location/report" . time . ".xml";
} elsif ($savereport eq "data") {
	&error("You can not save this report because no directory has been defined.<br><br>Try opening your directory in Sequest Summary and running Protein Report from there.");
}

$pepstring =~ s/[^A-Z$modregexp]/ /g;		# turn non-peptide characters into spaces for splitting into @peps
$pepstring =~ s/\s+/ /g;					# consolidate spaces
$pepstring =~ s/^\s//;
$pepstring =~ s/\s$//;

my @peps = split ' ', $pepstring;
#@peps = keys %{{map {$_, 1} @peps}};		# remove duplicates from @peps

$ticstring =~ s/\s+/ /g;					# consolidate spaces
$ticstring =~ s/^\s//;
$ticstring =~ s/\s$//;

my @tics = split ' ', $ticstring;
if (@tics != @peps && $ticstring) {
	&error("<span class=smallheading>The number of TIC values submitted must equal the number of peptides submitted." .
		   "  This may be caused by having an older \"+\" modification site in one of the sequences.  If this is true," .
		   " Sequest must be rerun on the directory.</span>");
}

my ($i, $w);
my @widths = ();
for ($i = 0; $i < @tics; $i++) {
	$w = $tics[$i];
	$w = &sci_notation($w) unless $w =~ /e/i;		# assume it is in sci notation if it contains an 'e'
	$w =~ s/.+?e(\d+)$/\1/i;						# get the exponent from the scientific notation
	if ($w >= 5) {
		$w -= 4;
	} else {
		$w = 0;
	}
	$widths[$i] = $w;								# this will indicate the thickness of the arrow under this peptide
}

if ($selected_frame) {
	my $found = grep { $selected_frame eq $_ } @frames;
	my $framescalar = join ', ', @frames;
	if (!$found) {
		&error(qq(<span class=smallheading>The value <tt>$selected_frame</tt> is not a valid frame.  Please choose from these: $framescalar.</span>));
	}
}



my @badpeps = ();
foreach (@peps) {
	push @badpeps, $_ if (/^[$modregexp]/ || /[$modregexp]{2,}/);
}
if (@badpeps > 0) {
	my $err = qq(<span class=smallheading>The following peptide sequences have incorrect syntax:</span><br><br><span class=smalltext>\n);
	foreach (@badpeps) {
		$err .= "$_<br>\n";
	}
	$err .= qq(</span><br><br><span class=smallheading>Please try again.</span>\n);
	&error($err);
}

my ($header, $sequence);
	
if ($compare_against eq "REF") {
	# Check to see if the database is nucleotide.  This should be passed in through the cgi value isnuc.
	#	$is_nucleo = &IsNucleotideDb("$dbdir/$db");
	
	($header, $sequence) = &get_header_and_sequence($ref, $db);

	unless ($header && $sequence) {
		&error("<span class=smalltext><b>Sorry, no entry found for reference </b><tt>$ref</tt><b> in database </b><tt>$db</tt><b> .</b></span>");
	}
} elsif ($compare_against eq "SEQ") {
	$sequence = $entered_sequence;
}

#############################
## handle sequence comments:

my @sequence_comments = ();
my %cominfo = ();
my %comindex = ();
if ($seqcomments) {
	$seqcomments =~ s/\n//g;										# remove newlines
	my @scs = split ":,,:", $seqcomments;
	my %badcomments = ();
	my %commentoverlap = ();
	my $minpos = $seqstartpos;
	my $maxpos = $minpos + length($sequence) - 1;
	my ($s, $e, $col, $com, $i);
	foreach (@scs) {
		next if /^\s*$/;										# ignore spaces-only comments
		if (m/^(\-?\d+)\-(\-?\d+)::([^:]+)::(.+?)(::::)?$/) {		# parse to find the number, color, and comment fields
			($s, $e, $col, $com) = ($1, $2, $3, $4);
			push @{$badcomments{$_}}, qq(The start position ($s) must be a valid position in the sequence (between $minpos and $maxpos).) if $s < $minpos;
			push @{$badcomments{$_}}, qq(The end position ($e) must be a valid position in the sequence (between $minpos and $maxpos).) if $e > $maxpos;
			push @{$badcomments{$_}}, qq(The end position ($e) must be greater than the start position ($s).) if $e <= $s;
			if ($col !~ /^\#[0-9a-f]{6}$/i && $col !~ /^[a-z\-]+$/i) {
				push @{$badcomments{$_}}, qq(The color <tt>$col</tt> is not a valid color.  Use an HTML color triplet (like ' <tt>#99ccff</tt> ') or an HTML color code (like ' <tt>blue</tt> ').);
			}
			for ($i = $s; $i <= $e; $i++) {						# make sure there are no overlapping comments
				if ($commentoverlap{$i}) {
					push @{$badcomments{$_}}, qq(This comment overlaps with the comment at $commentoverlap{$i}.  Overlapping comments are not allowed because they are ambiguous.);
					last;
				} else {
					$commentoverlap{$i} = "$s-$e";
				}
			}
			if (!exists $badcomments{$_}) {						# store information about this comment if it passed all validation tests
				
				$s -= $seqstartpos;		# here the start and end are modified to work with the zero-based indexing of the sequence that this program uses
				$e -= $seqstartpos;		#
				$cominfo{$s}{color} = $col;
				$cominfo{$s}{comment} = $com;
				$comindex{$s} = $e+1-$s if ($e+1-$s > $comindex{$s});
			}
		} else {
			push @{$badcomments{$_}}, qq(This comment line is formatted incorrectly.  The correct syntax is <tt>::[start position]-[end position]:[color]:[comment]</tt>);
		}
	}
	if (%badcomments > 0) {									# error if there are badly formatted comments
		my $err = qq(<span class=smallheading>The following sequence comment lines have incorrect syntax:</span><br><br><span class=smalltext><ul>\n);
		foreach (keys %badcomments) {
			$err .= qq(<li><tt>$_</tt></li>\n<ul>\n);
			foreach (@{$badcomments{$_}}) {
				$err .= qq(<li>$_</li>\n);
			}
			$err .= qq(</ul><br><br>\n);
		}
		$err .= qq(</ul></span><br><br>\n<span class=smallheading>Please try again.</span>\n);
		&error($err);
	}
}

#############################
## find peptide locations:

my %pepinfo = ();		# keys are peptides, values are hashes that contain properties (for example, 'start' and 'len')
my %seqindex = ();		# a hash pairing indexes in the sequence with the length of the longest peptide that begins there
my %modsites = ();		# a hash pairing indexes in the sequence with the mod site character located there (if any)

my %framesactive = ();	# this hash indicates which frames have peptide coverage

if ($is_nucleo) {		# All of this is done for nucleotide mode only
	my %nucFrames;
	my %sequences;

	## Calculate the best sequence by calculating them all, inefficient yes
	#my @frms = ("+1", "+2", "+3", "-1", "-2", "-3");
	my $bestscore = 0;
	my $bestframe = "+1";		# default, in case all scores are zero
	foreach (@frames) {
		#$sequences{$_} = &translate_seq ($sequence, $_);
		$nucFrames{$_}{seq} = &translate_seq ($sequence, $_);
		($nucFrames{$_}{score}, $nucFrames{$_}{seqindex}, $nucFrames{$_}{modsites}, $nucFrames{$_}{pepinfo}) = &find_pep_locations ($nucFrames{$_}{seq}, \@peps, \@widths);
		if ($nucFrames{$_}{score} > $bestscore) {
			$bestscore = $nucFrames{$_}{score};
			$bestframe = $_;
		}
		$framesactive{$_} = ($nucFrames{$_}{score} > 0) ? 1 : 0;
	}
	
	$selected_frame = $bestframe unless $selected_frame;	# if the user has specified a frame, use it instead of the calculated best

	$sequence = $nucFrames{$selected_frame}{seq};
	%seqindex = %{$nucFrames{$selected_frame}{seqindex}};
	%modsites = %{$nucFrames{$selected_frame}{modsites}};
	%pepinfo  = %{$nucFrames{$selected_frame}{pepinfo}};

} else {
	my ($totalLength, $seqindexR, $modsitesR, $pepinfoR);
	($totalLength, $seqindexR, $modsitesR, $pepinfoR) = find_pep_locations($sequence, \@peps, \@widths);

	# Set the hashs from the return
	%seqindex = %$seqindexR;
	%modsites = %$modsitesR;
	%pepinfo = %$pepinfoR;
}

my @pp = sort {$a <=> $b} keys %seqindex;
my $firstposition = $pp[0];
my $lastposition = 0;
foreach (@pp) {
	$lastposition = $_ + $seqindex{$_} if ($_ + $seqindex{$_} > $lastposition);
}
my ($seqimagefilename, $seqimagewidth, $seqimageheight) = &sequence_image(sequence => $sequence, pepinfo => \%pepinfo, firstAApos => $firstposition, lastAApos => $lastposition, masstype => $masstype, location => $saveimg_location, weblocation => $saveimg_weblocation);
undef @pp;

my ($img_names, $img_width, $img_heights) = &arrow_boxes(peps => \@peps, pepinfo => \%pepinfo, sequence => $sequence, location => $saveimg_location, weblocation => $saveimg_weblocation);

my ($highlighted_aas, @seq_rows) = &format_rows($sequence, \%pepinfo, \%seqindex, \%cominfo, \%comindex);

#my $highlighted_mass = &precision(&mw($masstype, 0, $highlighted_aas), 1);
my $total_mass = &precision(&mw($masstype, 0, $sequence), 1);
my $highlighted_length = length $highlighted_aas;
my $total_length = length $sequence;
my $coverage_by_count = &precision(100*$highlighted_length/$total_length, 0);		# rounded to nearest integer
#my $coverage_by_mass = &precision(100*$highlighted_mass/$total_mass, 1);

$showallrows = 1 if (join '', @seq_rows) !~ /</;		# manually show all rows if no peptides are highlighted anywhere in the sequence


#############################
## generate HTML report content:

my $report_content = "";
my ($sample_cells, $dir_cells);
if ($dir) {
	$dir_cells = <<DIR;
	<td class="smallheading bgc" width=65>Directory:</td>
	<td class=smalltext width=310>$dir</td>
DIR
} else {
	$dir_cells = qq(<td></td><td></td>);
}
if ($dir_info{LastName} && $dir_info{Initial} && $dir_info{Sample} && $dir_info{SampleID} != "") {
	$sample_cells = <<DIR;
	<td class="smallheading bgc" width=65>Sample:</td>
	<td class=smalltext width=310>$dir_info{LastName} $dir_info{Initial}. &nbsp;&nbsp;&nbsp; $dir_info{Sample} &nbsp;&nbsp;&nbsp; $dir_info{SampleID}</td>
DIR
} else {
	$sample_cells = qq(<td></td><td></td>);
}

$report_content .= qq(<table cellspacing=0 cellpadding=3 border=0 width=750 style="border:solid #e4e4e4 1px">);
$report_content .= <<TOP if $header;
<tr>
	<td class="smallheading bgc" width=65>Reference:</td>
	<td class=smalltext width=310>$ref</td>
	$sample_cells
</tr>
<tr>
	<td class="smallheading bgc" width=65>Database:</td>
	<td class=smalltext width=310>$db</td>
	$dir_cells
</tr>
<tr height=10><td class=bgc></td><td></td></tr>
<tr valign=top>
	<td class="smallheading bgc">Header:</td>
	<td class=smalltext width=685 bgcolor="#ececec" colspan=3>@{[substr $header, 1]}</td>
</tr>
<tr height=10><td class=bgc></td><td></td></tr>
TOP

$report_content .= <<STATS;
<tr><td width=65 class="smallheading bgc">Avg Mass:</td>
<td width=685 class=smalltext colspan=3>
<table cellspacing=0 cellpadding=3 border=0><tr>
<td width=294 class=smalltext>$total_mass</td>
<td width=65 class="smallheading bgc">Coverage:</td>
<td class=smalltext>
$highlighted_length/$total_length = $coverage_by_count% by amino acid count
</td></tr></table>
</td></tr></table>
<br style="font-size:10">
STATS


$report_content .= <<SEQIMG;
<img src="$seqimagefilename" width=$seqimagewidth height=$seqimageheight>
<br><br>
SEQIMG


#my $position = 1;
my $position = $seqstartpos;
my $i = 0;
my ($row_empty, $row_name, $display_property, $cur_table);
my (@row_names, @seq_tables);
foreach (@seq_rows) {				# Create a table for each row. These tables contain the position at which the row starts, the actual characters in the row, and the image containing peptide lines for the row
	$cur_table = "";
	$row_empty = (/</) ? 0 : 1;		# look for html tags to determine whether there are peptides in this row
	$row_name = "sequence_row_$i";
	push @row_names, $row_name if $row_empty;		# @row_names contains the html IDs of empty rows
	$display_property = $showallrows ? '' : 'none';
	$cur_table .= qq(<div id="$row_name" style="display:'$display_property'">\n) if $row_empty;
	$cur_table .= qq(<table cellspacing=0 cellpadding=0 border=0>\n);
	$cur_table .= qq(<tr><td width=35 align=left class=smallheading>$position</td><td width=15></td>\n<td><pre>$_</pre></td></tr>\n);
	$cur_table .= qq(<tr height=@{[$img_heights->[$i]+3]} valign=top><td></td><td></td><td><img src="$img_names->[$i]" width=$img_width height=$img_heights->[$i]></td></tr>\n);
	$cur_table .= qq(</table>);
	$cur_table .= qq(\n</div>) if $row_empty;
	push @seq_tables, $cur_table;

	$position += $wrap_after;
	$i++;
}
$report_content .= qq(<table cellspacing=0 cellpadding=0 border=0 width=770><tr><td>\n);
foreach (@seq_tables) {
	$report_content .= "$_\n\n";
}
$report_content .= qq(</td></tr></table>\n);

########## legend #####################
my @label_styles = ();
for (1..8) {
	$label_styles[$_] = $label_list[$_] ? "" : qq(style="display:none");
}
$report_content .= <<LEGEND;
<br>
<table cellspacing=0 cellpadding=3 border=0 width=730>
<tr><td class=smallheading colspan=4>Legend:</td></tr>
<tr>
	<td width=180><span class=pep><tt>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</tt></span>&nbsp;&nbsp;<span class=smalltext>Protein coverage</span></td>
	<td width=45 valign=middle>
		<table cellspacing=0 cellpadding=0 border=0 width=40><tr height=3><td bgcolor="#1e821e"></td></tr></table>
	</td><td width=505>
		<span class=smalltext>Peptide spectra</span>
	</td>
</tr>
<tr>
	<td colspan=4>
LEGEND
for (1..8) {
	$report_content .= qq(<span class=savestate id="m${_}Legend" $label_styles[$_]><span class="m$_"><tt>&nbsp;</tt></span>&nbsp;&nbsp;<span id="m${_}Label" class=smalltext>$label_list[$_]</span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>);
}
#$report_content .= <<LEGEND;
#
#	</td>
#</tr>
#<tr>
#	<td colspan=4>
#LEGEND
for (keys %cominfo) {
	my $col = $cominfo{$_}{color};
	my $com = $cominfo{$_}{comment};
	$report_content .= qq(<tt style="background-color:$col">&nbsp;</tt>&nbsp;&nbsp;<span class=smalltext>$com</span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;);
}
$report_content .= <<LEGEND;
	</td>
</tr>
</table>
LEGEND
########## end legend #################

########## comments area ##############
my $comstyle = ($comments) ? "" : qq(style="display:none");
$report_content .= <<COMMENTS;
<div class=savestate id="commentsarea" $comstyle>
<br>
<table cellspacing=0 cellpadding=0 border=0>
<tr><td class=smallheading>Comments:</td></tr>
<tr><td class=smalltext style="border:solid #999999 1px; padding:5px">
<span id="comments">$comments</span>
<input type=hidden id="usehtml" value="$usehtml">
</td></tr>
</table>
</div>
COMMENTS

########## end comments area ##########

########## peptide list ###############
my @peplist = keys %{{map {$_, 1} @peps}};			# remove duplicates from peptide list
@peplist = sort by_position @peplist;
my $peplist_rows_cutoff = 10;
$display_property = $showpeptides ? '' : 'none';
$report_content .= qq(<div class="savestate smalltext" id="peptidelist" style="display:'$display_property'"><br><br>\n);
$report_content .= qq(<table cellspacing=0 cellpadding=0 border=0 style="padding-right:20px;">);
if (@peplist < $peplist_rows_cutoff) {
	$report_content .= qq(<tr><td class=smallheading>Peptide</td><td class=smallheading>Position</td><td width=25></td><td></td><td></td></tr>\n);
} else {
	$report_content .= qq(<tr><td class=smallheading>Peptide</td><td class=smallheading>Position</td><td width=25></td><td class=smallheading>Peptide</td><td class=smallheading>Position</td></tr>\n);
}
$report_content .= qq(<tr height=5><td></td><td></td></tr>\n);
my $poslist;
my $peplen;

if (@peplist < $peplist_rows_cutoff) {
	# one column
	foreach (@peplist) {
		$report_content .= qq(<tr><td class=smalltext>$_</td><td class=smalltext>);
		$peplen = $pepinfo{$_}{len};
		$poslist = join ', ', map {($_+1) . '-' . ($_+$peplen)} @{$pepinfo{$_}{start}};
		$poslist = "Not found" if !$poslist;
		$report_content .= $poslist;
		$report_content .= qq(</td></tr>\n);
	}
} else {
	# two columns
	my $halfpeps = int(.5 + (@peplist / 2));
	my @firsthalfpeps = splice @peplist, 0, $halfpeps;
	my @secondhalfpeps = @peplist;
	my $i = 0;
	@peplist = map {$_, $secondhalfpeps[$i++]} @firsthalfpeps;
	my @poslists;
	
	foreach (@peplist) {
		if ($_ eq '') {
			push @poslists, '';
			next;
		}
		$peplen = $pepinfo{$_}{len};
		$poslist = join ', ', map {($_+1) . '-' . ($_+$peplen)} @{$pepinfo{$_}{start}};
		$poslist = "Not found" if !$poslist;
		push @poslists, $poslist;
	}

	for ($i = 0; $i < @peplist; $i+=2) {
		$report_content .= qq(<tr><td class=smalltext>$peplist[$i]</td><td class=smalltext>$poslists[$i]</td><td></td>\n);
		$report_content .= qq(<td class=smalltext>$peplist[$i+1]</td><td class=smalltext>$poslists[$i+1]</td></tr>\n);
	}
}

$report_content .= qq(</table>\n);
$report_content .= qq(</div>\n\n);
########## end peptide list ###########

$report_content .= <<JS;
<script language="JavaScript" type="text/javascript"><!--
var rowNames = new Array();
JS

$i = 0;
foreach (@row_names) {
	$report_content .= qq(rowNames[$i] = "$_";\n);
	$i++;
}

$report_content .= <<JS;
function toggleEmptyRows(hide) {
	if (hide) {
		for (var i=0; i < rowNames.length; i++) {
			document.all(rowNames[i]).style.display = 'none';
		}
	} else {
		for (var i=0; i < rowNames.length; i++) {
			document.all(rowNames[i]).style.display = '';
		}
	}
}
function togglePeptideList(hide) {
	if (hide) {
		document.all('peptidelist').style.display = 'none';
	} else {
		document.all('peptidelist').style.display = '';
	}
}

//-->
</script>
JS

my $head_content = &create_head_content(seq => $entered_sequence, compmode => $compare_against, reference => $ref, isnuc => $is_nucleo);
my $peplist_textarea = &create_peplist_textarea([sort @peps], $head_style);


my $head_frame = &generate_head_frame($head_content, $head_style);
my $report_frame = &generate_report_frame(content => $report_content, style => $report_style, location => $savefile_location, weblocation => $savefile_weblocation);
my $peplist_frame = &generate_peplist_frame($peplist_textarea, $head_style);


#######################################
## save all data, if requested

if ($xml_file) {
	use XML::Dumper;
	my $dump = new XML::Dumper;

	my $xml_data = $dump->pl2xml({db => $db, ref => $ref, dir => $dir, compare_against => $compare_against,
								  entered_sequence => $entered_sequence, showallrows => $showallrows, showpeptides => $showpeptides,
								  is_nucleo => $is_nucleo, sample => $sample, comments => $comments, seqcomments => $seqcomments,
								  usehtml => $usehtml, pepstring => $pepstring, startposition => $seqstartpos, labels => \@label_list});

	open XMLFILE, ">$xml_file" or &error("Could not create $xml_file to save this report!");
	print XMLFILE $xml_data;
	close XMLFILE;
}



#############################
## finally, the output:

print <<OUTPUT;

Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN">
<html>
<head>
<title>Protein Report</title>
</head>
<script language="JavaScript" type="text/javascript"><!--
function startUp() {
	window.frames["head"].startUp();
}
//-->
</script>
<frameset onload="startUp();" rows="186,*" frameborder=no><!--190-->
	<frame name="head" src="$head_frame" noresize>
	<frameset cols="200,*">
		<frame name="peplist" src="$peplist_frame" noresize>
		<frame name="report" src="$report_frame" noresize frameborder=yes>
	</frameset>
</frameset>
</html>
OUTPUT


exit 0;



#######################################
# subroutines


##PERLDOC##
# Function : error
# Argument : an error message
# Globals  : none
# Returns  : nothing, but exits this script
# Descript : Used for fatal errors, this function prints out an error message on a formatted HTML page then exits the script
# Notes    : The error message can contain HTML tags - if none are included, the text is formatted in the standard smallheading style
##ENDPERLDOC##
sub error {
	my $message = shift;
	my $default_format = 0;
	$| = 1;
	&MS_pages_header("$title","$title_color");
	$default_format = 1 if ($message !~ /<.+?>/);		# apply standard formatting if there are no tags in the message

	print qq(<hr><br><br>\n);
	print qq(<span class=smallheading>\n) if $default_format;
	print $message;
	print qq(</span>) if $default_format;
	print qq(</body></html>);
	exit 0;
}


##PERLDOC##
# Function : find_pep_locations
# Argument : $sequence - The protein sequence to query each peptide sequence against.
# Argument : \@pepsR - The reference to the array of peptide sequences.
# Argument : \@widths - The array of widths that corresponds to @pepsR
# Globals  : $modregexp - The list of characters used as mods
# Globals  : $modchars - The hash list of characters used as mods
# Returns  : $totalLength - The number of characters that were matched in the sequence from the peptides
# Returns  : \%seqindex - Pairs indexes of longest peptide sequence with where they begin
# Returns  : \%modsites - The location of each of the modsites
# Returns  : \%pepinfo - The starting position of each of the peptide sequences matched
# Descript : This routine matches arrays of peptides within a sequence, and returns hashes containing
#		   : useful information that can be used to put together the protein report.
# Notes    :
##ENDPERLDOC##
sub find_pep_locations {
	my $sequence = shift;
	my $pepsR = shift;
	my @widths = @{shift()};

	my ($peplen, $curpos, $esc, $mod, $ind, $nomods, $totalLength);
	my $pepcount = -1;

	my %pepinfo = ();		# keys are peptides, values are hashes that contain properties (for example, 'start' and 'len')
	my %seqindex = ();		# a hash pairing indexes in the sequence with the length of the longest peptide that begins there
	my %modsites = ();		# a hash pairing indexes in the sequence with the mod site character located there (if any)
	
	foreach (@peps) {					# find out where peptides occur in the sequence
		$pepcount++;


		$ind = 0;
		my %modinpep = ();				# indicates where the mod sites are relative to the start of the peptide
		foreach (split '', $_) {		# determine where the mod sites in this peptide are relative to the first character
			if (m/([$modregexp])/) {
				$modinpep{$ind-1} = $modchars{$1};
				next;
			}
			$ind++;
		}
		push @{$pepinfo{$_}{modinpep}}, \%modinpep;
		push @{$pepinfo{$_}{thickness}}, ($widths[$pepcount] || 0);
		next if (exists $pepinfo{$_}{len});			# don't want to redo the work for multiple identical sequences


		($nomods = $_) =~ s/[$modregexp]//g;		# remove mod site characters so search against sequence works correctly (here, this should be equivalent to s/[^A-Z]//gi)
		$peplen = length $nomods;
		$pepinfo{$_}{len} = $peplen;

		while ($sequence =~ m/$nomods/gi) {
			$curpos = pos($sequence) - $peplen;
			push @{$pepinfo{$_}{start}}, $curpos;		# the start property here is an array of all the positions in the sequence at which this peptide begins
			$seqindex{$curpos} = $peplen if $peplen > $seqindex{$curpos};		# for the sake of %seqindex, we are only worried about the longest peptide that starts at this position
			pos($sequence) = $curpos + 1;
			foreach (keys %modinpep) {
				$modsites{$curpos + $_} = $modinpep{$_};		# store information about where mod sites are relative to the beginning of the sequence
			}
			$totalLength += $peplen;		# this is a sort of score that can be used to compare this against other frames in $is_nucleo mode
		}
	}
	return ($totalLength, \%seqindex, \%modsites, \%pepinfo);
}



##PERLDOC##
# Function : by_position
# Argument : $a - the first element
# Argument : $b - the second element
# Globals  : uses %pepinfo, doesn't modify any globals
# Returns  : an integer: positve, negative or zero depending on how $a compares to $b
# Descript : This is a sort routine, meant to be passed to perl's sort function.  It provides an ordering primarily based on where the peptide begins in the sequence.
# Notes    :
##ENDPERLDOC##
## use this with the sort function to sort peptides by position in sequence
sub by_position {
	@{$pepinfo{$a}{start}} > 0 && ! @{$pepinfo{$b}{start}} > 0 ? -1 : 0
		or
	@{$pepinfo{$b}{start}} > 0 && ! @{$pepinfo{$a}{start}} > 0 ? 1 : 0
		or
	$pepinfo{$a}{start}[0] <=> $pepinfo{$b}{start}[0]
		or
	$pepinfo{$a}{len} <=> $pepinfo{$b}{len}
		or
	$b cmp $a;
}

##PERLDOC##
# Function : create_peplist_textarea
# Argument : a list of peptides
# Globals  : none
# Returns  : HTML code for a textarea containing the list of peptides
# Descript : I don't think further description would be necessary or prudent here.
# Notes    : This generates html code that expects particular styles to be defined on the page, if they aren't, it won't look like it is intended to look.
##ENDPERLDOC##
sub create_peplist_textarea {
	my $peplist = shift;
	my $output = qq(\n<textarea class="savestate outline" id="peptides" rows=25 cols=20 wrap=off>\n);
	foreach (@$peplist) {
		$output .= "$_\n";
	}
	$output .= qq(</textarea>\n);
	return $output;
}

##PERLDOC##
# Function : create_head_content
# Argument : seq - the entered sequence against which peptides are being compared
# Argument : compmode - either "REF" or "SEQ", depending on which comparison mode is currently selected
# Argument : noreport - extant and true if no report will be present (for example, on the initial setup page before a report has been created).
# Argument : reference - the database reference being looked up, if in "REF" mode
# Argument : isnuc - true if this is a nuc database, false otherwise
# Globals  : uses some, doesn't modify any
# Returns  : HTML content for the head frame of this report
# Descript : Generates the HTML and JavaScript necessary to make the page work.  This is the code for the top frame of the document
# Notes    :
##ENDPERLDOC##
sub create_head_content {
	my %p = @_;
	my $entered_sequence = $p{seq};
	my $compare_mode = $p{compmode};
	my $noreport = $p{noreport};
	my $ref = $p{reference};
	my $noreport_msg = "This feature is not available until you have created a report.";

	my $copyname = "$dir_info{LastName} $dir_info{Initial} $dir_info{Sample} $dir_info{SampleID}";

	my $ncbi_ref = "";
	if ($ref =~ /gi\|/) {
		$ncbi_ref = ($ref =~ /^gi\|(\d*)/)[0];
	}
	my $ncbi_type = $p{isnuc} ? 'n' : 'p';
	my $nuc = $p{isnuc} ? 1 : "";
	my $framescode = "";
	if ($nuc) {
		my $fnum = "";
		$framescode = qq(<span class=link style="cursor:default" helptext="Click on one of these numbers to view a different frame">Frames:</span>&nbsp;);
		foreach (@frames) {
			($fnum = $_) =~ s/\-/&ndash;/;		# convert '-' to an en dash for output
			if ($_ eq $selected_frame && $framesactive{$_}) {
				$framescode .= qq(&nbsp;<span class=smalltext style="cursor:default; color:red; background-color:#f2f2f2; border:solid #9999ff 1px" helptext="You are viewing the $_ frame">$fnum</span>);
			} elsif ($_ eq $selected_frame) {
				$framescode .= qq(&nbsp;<span class=smalltext style="cursor:default; background-color:#f2f2f2; border:solid #9999ff 1px" helptext="You are viewing the $_ frame">$fnum</span>);
			} elsif ($framesactive{$_}) {
				$framescode .= qq(&nbsp;<span class=smalltext style="cursor:hand; color:red" onclick="changeFrames('$_')" helptext="Some of the selected peptides appear in the $_ frame">$fnum</span>);
			} else {
				$framescode .= qq(&nbsp;<span class=smalltext style="cursor:hand" onclick="changeFrames('$_')" helptext="None of the selected peptides appear in the $_ frame">$fnum</span>);
			}
		}
	}

	my $dropbox = &get_db_dropbox;
	$dropbox =~ s/<select /<select helppos="50 25" helptext="Choose a fasta database from this dropbox" /i;		# insert helptext in the dropbox code

	my ($refchecked, $seqchecked) = ("", "");
	if ($compare_mode eq "SEQ") {
		$seqchecked = "checked";
	} else {
		$refchecked = "checked";
	}
	my $hiderowsvalue = $showallrows ? "" : "true";
	my $hidepepsvalue = $showpeptides ? "" : "true";
	my $showrowstext = "Show All Rows";
	my $hiderowstext = "Hide Empty Rows";
	my $showpepstext = "Show Peptides";
	my $hidepepstext = "Hide Peptides";
	
	my $initrowstext = $showallrows ? $hiderowstext : $showrowstext;
	my $initpepstext = $showpeptides ? $hidepepstext : $showpepstext;

	$entered_sequence =~ s/(.{10})/\1 /g;		# reinsert a space every 10 characters for display

	my $head_content = <<FORM;
<div id="helpballoon" class="helpballoon smalltext" onmouseover="window.event.cancelBubble = true;"></div>
<form name="mainform" action="$ourname" method="POST" target="_parent" style="margin-top:0; margin-bottom:0" onsubmit="doFormSubmit(); return true;">
<table cellspacing=0 cellpadding=0 border=0 width=975>
<tr valign=top>

<td width=202>
	<table cellspacing=0 cellpadding=0 border=0 width=180><tr><td>
	<br style="font-size:6">

	<div style="width:175; background-color:#ddddf4; position:relative; height:15;" class=smalltext>
	<span class=link style="cursor:default; position:absolute; padding:2px; height:15; left:10" onmouseover="showProteinMenu('filemenu')" onmouseout="hideProteinMenu()">File <font face="marlett" onmouseover="event.cancelBubble=true">6</font></span>
	<span class=link style="cursor:default; position:absolute; padding:2px; height:15; left:58" onmouseover="showProteinMenu('editmenu')" onmouseout="hideProteinMenu()">Edit <font face="marlett" onmouseover="event.cancelBubble=true">6</font></span>
	<span class=link style="cursor:default; position:absolute; padding:2px; height:15; left:110" onmouseover="showProteinMenu('sendtomenu')" onmouseout="hideProteinMenu()">Send To <font face="marlett" onmouseover="event.cancelBubble=true">6</font></span>
	</div>

	<span style="position:absolute; width:175; height:1; overflow:hidden; border:solid #0000cc 1px;"></span>
	<div id="filemenu" onmouseout="hideProteinMenu()" onclick="hideProteinMenu()" maxheight=50 style="position:absolute; width:52; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="saveReport()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Save</span><br>
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="loadReport()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Load...</span><br>
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="printReport()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Print</span>
	</div>
	<div id="editmenu" onmouseout="hideProteinMenu()" onclick="hideProteinMenu()" maxheight=50 style="position:absolute; width:107; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span id="hiderowsbutton" class=actbutton style="width:105; text-align:left; padding-left:3px" onclick="toggleEmptyRows()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">$initrowstext</span><br>
		<span id="hidepepsbutton" class=actbutton style="width:105; text-align:left; padding-left:3px" onclick="togglePeptideList()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">$initpepstext</span><br>
		<span class=actbutton style="width:105; text-align:left; padding-left:3px" onclick="settingsDialog()" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Comments...</span>
	</div>
	<div id="sendtomenu" onmouseout="hideProteinMenu()" onclick="hideProteinMenu()" maxheight=@{[$ncbi_ref ? '98' : '66']} style="position:absolute; width:67; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('pepcut')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Pepcut</span>
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('pepstat')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Pepstat</span>
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('gap')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Gap</span>
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('muquest')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">MuQuest</span>
		@{[$ncbi_ref ? qq(
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('sequence')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Sequence</span>
		<span class=actbutton style="width:65; text-align:left; padding-left:3px" onClick="sendTo('abstract')" onmouseover="this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Abstract</span>
		) : ""]}
	</div>
	<br><br style="font-size:6">
	<center>
	<input type=submit class="outlinebutton button" value="Refresh Report" helptext="When finished editing the peptide list and report parameters, click this to create a new report">
	<br>
	<span class=link onclick="startHelp();" helptext="Help - click anywhere to turn off">Help</span>
	<br><br style="font-size:8">
	</center>
	$framescode
	</td></tr></table>
</td>
<td width=5></td>
<td width=783>
	<input type=hidden name="peptides">
	<input type=hidden name="comments">
	<input type=hidden name="directory" value="$dir">
	<input type=hidden name="isnuc" value="$nuc">
	<input type=hidden name="frame" value="$selected_frame">
	<input type=hidden name="hiderows" value="$hiderowsvalue">
	<input type=hidden name="hidepeplist" value="$hidepepsvalue">
	<input type=hidden name="usehtml">
	<input type=hidden name="startposition" value="$seqstartpos">
	<input type=hidden name="seqcomments" value="$seqcomments">
	<input type=hidden name="m1Label">
	<input type=hidden name="m2Label">
	<input type=hidden name="m3Label">
	<input type=hidden name="m4Label">
	<input type=hidden name="m5Label">
	<input type=hidden name="m6Label">
	<input type=hidden name="savereport">
	<fieldset style="padding:5px; border: solid #0000cc 1px"><legend class=smallheading style="color:#0000cc">Compare selected peptides against:</legend>
	<br style="font-size:5">
	<table cellspacing=0 cellpadding=3 border=0>
		<tr id="refcel" bgcolor="$darkhighlight">
			<td><input name="compare_against" type=radio value="ref" onclick="changeEnabled();" $refchecked helptext="Choose this option to compare the selected peptides against a database entry"></td>
			<td class=smallheading align=right>Reference:</td>
			<td><input name="ref" type=text size=30 value="$ref" class="outline dropbox" onfocus="changeEnabled('ref');" helppos="50 4" helptext="Enter a reference to look up in the selected database"></td>
			<td class=smallheading align=right nowrap>in database</td><td>$dropbox</td>
		</tr>
		<tr height=10><td></td></tr>
		<tr id="seqcel" bgcolor="$lighthighlight">
			<td><input name="compare_against" type=radio value="seq" onclick="changeEnabled();" $seqchecked helptext="Choose this option to compare the selected peptides against a specific sequence"></td>
			<td class=smallheading align=right>Sequence:</td>
			<td colspan=3><textarea class=outline name="sequence" cols=81 rows=2 onfocus="changeEnabled('seq');" helptext="To compare the selected peptides against an arbitrary sequence, enter the sequence here. Any non-alphabetic characters will be ignored.">$entered_sequence</textarea></td>
		</tr>
	</table>
	</fieldset>
</td>
</tr>
</table>
</form>
<br style="font-size:6">
<table cellspacing=0 cellpadding=0 border=0 width=975><tr>
	<td width=190><span class=link style="cursor:default">Edit Peptides:</span></td>
	<td width=775><span class=link style="cursor:default">Report:</span></td>
</tr></table>
<form name="pepcutform" action="$pepcut" method=POST style="margin:0" target="_blank">
<input type="hidden" name="mode" value="backlink_run">
<input type="hidden" name="type_of_query">
<input type="hidden" name="database">
<input type="hidden" name="query">
<input type="hidden" name="searchseq">
<input type="hidden" name="Dir">
<input type="hidden" name="MassType">
<input type="hidden" name="disp_sequence" value="yes">
</form>
<form name="pepstatform" action="$pepstat" method=POST style="margin:0" target="_blank">
<input type=hidden name="type_of_query">
<input type=hidden name="database">
<input type=hidden name="peptide">
<input type=hidden name="Dir">
<input type=hidden name="running" value=1>
</form>
<form name="gapform" action="$gap" method=POST style="margin:0" target="_blank">
<input type=hidden name="type_of_query1">
<input type=hidden name="database1">
<input type=hidden name="peptide1">
<input type=hidden name="Dir">
</form>
<form name="muquestform" action="$webmuquest" method=POST style="margin:0" target="_blank">
<input type=hidden name="directory">
<input type=hidden name="sequences">
<input type=hidden name="goto_dta_select_page" value="yes">
</form>
<textarea id="popupcode" style="display:none">@{[&settings_dialog()]}</textarea>
<script language="JavaScript" type="text/javascript"><!--
var noreport = @{[$noreport ? 1 : 0]};
function changeEnabled(mode) {
	if (mode == 'ref') {
		document.mainform.compare_against[0].checked = true;
	} else if (mode == 'seq') {
		document.mainform.compare_against[1].checked = true;
	}
	if (document.mainform.compare_against[0].checked) {
		document.all.refcel.bgColor = '$darkhighlight';
		document.all.seqcel.bgColor = '$lighthighlight';
	} else if (document.mainform.compare_against[1].checked) {
		document.all.refcel.bgColor = '$lighthighlight';
		document.all.seqcel.bgColor = '$darkhighlight';
	}
}
var pageLoaded = false;
function startUp() {
	pageLoaded = true;
	changeEnabled();
	if (parent.report) {
		parent.report.toggleEmptyRows(document.mainform.hiderows.value=='true' ? true : false);
		parent.report.togglePeptideList(document.mainform.hidepeplist.value=='true' ? true : false);
	}

}

function toggleEmptyRows() {
	if (!parent.report || noreport) {
		alert('$noreport_msg');
		return;
	}
	if (document.mainform.hiderows.value == 'true') {
		document.mainform.hiderows.value = '';
		document.all.hiderowsbutton.innerText = '$hiderowstext';
		parent.report.toggleEmptyRows(false);
	} else {
		document.mainform.hiderows.value = 'true';
		document.all.hiderowsbutton.innerText = '$showrowstext';
		parent.report.toggleEmptyRows(true);
	}
}
function togglePeptideList() {
	if (!parent.report || noreport) {
		alert('$noreport_msg');
		return;
	}
	if (document.mainform.hidepeplist.value == 'true') {
		document.mainform.hidepeplist.value = '';
		document.all.hidepepsbutton.innerText = '$hidepepstext';
		parent.report.togglePeptideList(false);
	} else {
		document.mainform.hidepeplist.value = 'true';
		document.all.hidepepsbutton.innerText = '$showpepstext';
		parent.report.togglePeptideList(true);
	}
}

function saveReport() {
	if (noreport) {
		alert('$noreport_msg');
		return;
	}
	document.mainform.savereport.value = "data";
	doFormSubmit();
	document.mainform.submit();
}
function changeFrames(newFrame) {
	document.mainform.frame.value = newFrame;
	doFormSubmit();
	document.mainform.submit();
}

var loadwindow = null;
function loadReport() {
	if (loadwindow && !loadwindow.closed) {
		loadwindow.focus();
		return;
	}
	var width = 390;
	var height = 400;
	var left = screen.availWidth/2 - width/2;
	var top = screen.availHeight/2 - height/2;
	var properties = "width="+width+",height="+height+",left="+left+",top="+top;
	loadwindow = window.open("$ourname?loadwindow=true&loaddir=$dir", "loadwindow", properties);
}

function printReport() {
	if (noreport) {
		alert('$noreport_msg');
		return;
	}
	// copy name to clipboard
	window.clipboardData.setData('Text', '$copyname')

	// print report
	parent.report.focus();
	parent.report.print();
}

function doFormSubmit() {
	document.mainform.peptides.value = parent.peplist.document.all.peptides.value;
	if (!parent.report) return;
	document.mainform.usehtml.value = parent.report.document.all.usehtml.value;
	document.mainform.comments.value = parent.report.document.all.comments.innerHTML;
	var i;
	var name;
	var labelList = "";
	for (i = 1; i <= 6; i++) {
		name = "m"+i+"Label";
		document.mainform(name).value = parent.report.document.all(name).innerText;
	}
}
function sendTo(mode) {
	if (noreport) {
		alert('$noreport_msg');
		return;
	}
	mode = mode.toLowerCase();
	var dir = "$dir";
	if (mode=="muquest") {
		if (dir) document.muquestform.directory.value = dir;
		var pepstr = getPepString();

		document.muquestform.sequences.value = pepstr;
		document.muquestform.submit();
		return;
	} else {
		var type = document.mainform('compare_against')[0].checked ? 1 : 0;
		var db = "$db";
		var refs = document.mainform.ref.value;
		var seqs = document.mainform.sequence.value;

		if (mode=="pepstat") {
			document.pepstatform('type_of_query').value = type;
			if (type == 1) {
				document.pepstatform.database.value = db;
				document.pepstatform.peptide.value = refs;
				document.pepstatform.Dir.value = dir;
			} else {
				document.pepstatform.peptide.value = seqs;
			}
			document.pepstatform.submit();
			return;
		} else if (mode=="gap") {
			document.gapform('type_of_query1').value = type;
			if (type == 1) {
				document.gapform.database1.value = db;
				document.gapform.peptide1.value = refs;
				document.gapform.Dir.value = dir;
			} else {
				document.gapform.peptide1.value = seqs;
			}
			document.gapform.submit();
			return;
		} else if (mode=="pepcut") {
			document.pepcutform('type_of_query').value = type;
			document.pepcutform.MassType.value = '$masstype';
			var pepstr = getPepString();
			document.pepcutform.searchseq.value = pepstr;
			if (type == 1) {
				document.pepcutform.database.value = db;
				document.pepcutform.query.value = refs;
				document.pepcutform.Dir.value = dir;
			} else {
				document.pepcutform.query.value = seqs;
			}
			document.pepcutform.submit();
			return;
		} else if (mode=="sequence" || mode=="abstract") {
			var ncbi = "$NCBI/htbin-post/Entrez/query?uid=$ncbi_ref&form=6&db=$ncbi_type&Dopt=";
			if (mode=="sequence") {
				ncbi += "f";
			} else {
				ncbi += "m";
			}
			open(ncbi);
		} else {
			alert("Unknown sendTo mode!");
		}
	}
}

function getPepString() {
	var pepstr = parent.peplist.document.all.peptides.value;
	pepstr = pepstr.replace(/[^a-z \\s]/gi, '');			//# get rid of non-alphabetic characters

	//# remove duplicates
	var pepArr = pepstr.split(/\\s+/);
	var tempArr = new Array();
	for (i=0; i<pepArr.length; i++) {
		tempArr[pepArr[i]] = 1;
	}
	pepArr = new Array();
	i = 0;
	for (x in tempArr) {
		pepArr[i++] = x;
	}
	pepstr = pepArr.join(' ');
	//# end duplicate removal
	return pepstr;
}

var settings = null;
function settingsDialog() {
	if (!parent.report || noreport) {
		alert('$noreport_msg');
		return;
	}
	if (settings && !settings.closed) {
		settings.focus();
		return;
	}

	var width = 605;
	var height = 380;
	var left = screen.availWidth/2 - width/2;
	var top = screen.availHeight/2 - height/2;
	var properties = "width="+width+",height="+height+",left="+left+",top="+top;
	//settings = window.open("$ourname?settings=true", "settings", properties);

	settings = window.open("", "settings", properties);
	var pc = document.all.popupcode.value;

	pc = pc.replace(/txtarea/gi, 'textarea');
	settings.document.write(pc);
	settings.document.close();
	settings.doStartUp();
}

///////////////// menu code //////////////////////////
var showProteinMenuInterval;
var ProteinMenuSizeChange = 10;
var ProteinMenuTimeChange = 20;
var ProteinMenuShowWait = 4;
var ProteinMenuShowWaited;
var ProtMenuObj = null;

function showProteinMenu(menuname) {
	if (ProtMenuObj) {					// if a menu was already visible, get rid of it
		ProtMenuObj.style.height = 1;
		ProtMenuObj.style.visibility = 'hidden';
		ProtMenuObj = null;
	}
	ProtMenuObj = document.all(menuname);
	if (!ProtMenuObj) return;
	
	if (!ProtMenuObj.style.left) {		// if we haven't calculated the menu position yet, do it now
		var activator = event.srcElement;
		var par = activator;
		var leftpos = 0;
		while (par) {
			leftpos += par.offsetLeft;
			par = par.offsetParent;
		}
		ProtMenuObj.style.left = leftpos;
	}

	clearInterval(showProteinMenuInterval);
	ProteinMenuShowWaited = 0;
	showProteinMenuInterval = setInterval("incProteinMenuHeight()", ProteinMenuTimeChange);
}
function hideProteinMenu() {
	if (!ProtMenuObj) return;
	if (ProtMenuObj == event.toElement || ProtMenuObj.contains(event.toElement)) return;
	clearInterval(showProteinMenuInterval);
	showProteinMenuInterval = setInterval("decProteinMenuHeight()", ProteinMenuTimeChange);
}
function incProteinMenuHeight() {
	ProteinMenuShowWaited++;
	if (ProteinMenuShowWaited < ProteinMenuShowWait) return;
	if (ProteinMenuShowWaited == ProteinMenuShowWait) ProtMenuObj.style.visibility = 'visible';
	var h = parseInt(ProtMenuObj.style.height);
	if (h + ProteinMenuSizeChange > ProtMenuObj.maxheight) {
		h = ProtMenuObj.maxheight;
		clearInterval(showProteinMenuInterval);
	} else {
		h += ProteinMenuSizeChange;
	}
	ProtMenuObj.style.height = h;
}
function decProteinMenuHeight() {
	var h = parseInt(ProtMenuObj.style.height);
	if (h - ProteinMenuSizeChange < 1) {
		h = 1;
		ProtMenuObj.style.visibility = 'hidden';
		clearInterval(showProteinMenuInterval);
	} else {
		h -= ProteinMenuSizeChange;
	}
	ProtMenuObj.style.height = h;
}

///////////////// end menu code //////////////////////


@{[&help_javascript]}
//-->
</script>
FORM
	return $head_content;
}

##PERLDOC##
# Function : help_javascript
# Argument : none
# Globals  : none
# Returns  : JavaScript code to make the mouseover help system work
# Descript : Generates JavaScript
# Notes    : this will probably be improved and moved to a JS file sometime
##ENDPERLDOC##
sub help_javascript {
	my $output = <<JAVASCRIPT;
var helping = false;
var helpOverObj = null;
function startHelp() {
	helping = true;
	document.body.style.cursor='help';
	window.event.cancelBubble = true;
}
function endHelp() {
	helping=false;
	document.body.style.cursor='auto';
	hideBalloon();
}
function doMouseOverHelp() {
	if (helping == false) return;
	if (!document.all.helpballoon) return;
	var e = window.event;
	var obj = e.srcElement;

	var helpPos = obj.helppos;
	var helpText = "";
	if (obj.helptext) {
		helpText = obj.helptext;
	} else {
		var objName = "";
		if (e.srcElement.name) {
			objName = e.srcElement.name;
		} else {
			return;
		}

		var objWithText = document.getElementsByName(objName);
		if (!objWithText) return;
		for (i=0; i<objWithText.length; i++) {
			if (objWithText[i].helptext) {
				helpText = objWithText[i].helptext;
				break;
			}
		}
	}
	if (!helpText) return;
	var balloonWidth = Math.min(6.5*helpText.length, 200);
	document.all('helpballoon').style.width=balloonWidth;
	document.all('helpballoon').innerHTML=helpText;
	var balloonHeight = document.all('helpballoon').offsetHeight;

	var left = obj.offsetLeft;
	var top = obj.offsetTop;
	var width = obj.offsetWidth;
	var height = obj.offsetHeight;
	
	var parObj = e.srcElement;
	while (parObj.offsetParent) {
		parObj = parObj.offsetParent;
		left += parObj.offsetLeft;
		top += parObj.offsetTop;
	}
	helpOverObj = new Object();
	helpOverObj.left = left;
	helpOverObj.top = top;
	helpOverObj.right = left + width;
	helpOverObj.bottom = top + height;

	var boxleft = left;
	var boxtop = top;
	if (helpPos) {
		var posArr = helpPos.split(' ');
		boxleft += parseInt(posArr[0]);
		boxtop += parseInt(posArr[1]);
	} else {
		boxleft += obj.offsetWidth + 10;
		if (boxleft + balloonWidth > document.body.scrollLeft + document.body.scrollWidth) {
			boxleft = document.body.scrollLeft + document.body.scrollWidth - balloonWidth - 5;
		}
		if (boxtop + balloonHeight > document.body.scrollTop + document.body.scrollHeight) {
			boxtop = document.body.scrollTop + document.body.scrollHeight - balloonHeight - 5;
		}
	}

	document.all('helpballoon').style.left=boxleft;
	document.all('helpballoon').style.top=boxtop;
	document.all('helpballoon').style.visibility='visible';

}
function doMouseOutHelp() {
	if (!helping) return;
	if (helpOverObj == null) return;

	if (event.x < helpOverObj.left || event.x > helpOverObj.right || event.y < helpOverObj.top || event.y > helpOverObj.bottom) {
		hideBalloon();
		helpOverObj = null;
	}
}
function hideBalloon() {
	if (!document.all.helpballoon) return;
	document.all('helpballoon').style.visibility='hidden';
	document.all('helpballoon').style.left=0;
	document.all('helpballoon').style.top=0;
}


document.onmouseover = doMouseOverHelp;
document.onmouseout = doMouseOutHelp;
document.onclick = endHelp;

JAVASCRIPT

	return $output;
}

##PERLDOC##
# Function : generate_head_frame
# Argument : first - the page content
# Argument : second - code for any <style> elements necessary
# Globals  : none
# Returns  : a path and filename for the location of the head frame on the server
# Descript : creates an HTML document on the server, and returns the path to the document
# Notes    :
##ENDPERLDOC##
sub generate_head_frame {
	my $content = shift;
	my $style = shift;
	my $output = "";
	my $filename;
	my $MS_pages_header = &return_MS_pages_header("$title","$title_color");
	$MS_pages_header =~ s/^content-type.+$//im;										# remove the content-type statement since this document will not be returned as part of a script
	$MS_pages_header =~ s/<br.+?>//i;
	$MS_pages_header =~ s!</head!$style</head!i;									# insert style before the </head> tag

	$output = <<OUTPUT;
$MS_pages_header
<hr class=donotprint>
$content
</body>
</html>
OUTPUT

	($filename = $ourshortname) =~ s/\..+$//;
	$filename .= "_" . time . "_$$\_head.html";
	open HEADFILE, ">$tempdir/$filename";
	print HEADFILE $output;
	close HEADFILE;
	return "$server/tmp/$filename";
}


sub generate_report_frame {
	my %arguments = @_;
	#my $content = shift;
	#my $style = shift;
	my $content = $arguments{content};
	my $style = $arguments{style};
	my $location = $arguments{location};
	my $weblocation = $arguments{weblocation};
	if (! ($location && $weblocation)) {
		$location = $tempdir;
		$weblocation = "$server/tmp";
	}
	my $output = "";
	my $filename;

	#removed: $stylesheet_html
	$output = <<OUTPUT;
<html>
<head>
<title>Protein Report Frame</title>
<link rel="stylesheet" type="text/css" href="$server/$stylesheet_IE">
<link rel="stylesheet" type="text/css" href="$server/$stylesheet">
<meta name="save" content="history">
$style
</head>
<body>
$content
</body>
</html>
OUTPUT

	($filename = $ourshortname) =~ s/\..+$//;
	$filename .= "_" . time . "_$$\_report.html";
	#open REPORTFILE, ">$tempdir/$filename";
	open REPORTFILE, ">$location/$filename";
	print REPORTFILE $output;
	close REPORTFILE;
	#return "$server/tmp/$filename";
	return "$weblocation/$filename";
}

##PERLDOC##
# Function : generate_peplist_frame
# Argument : first - the html code for the peplist <textarea>
# Argument : second - code for any <style> elements necessary
# Globals  : none
# Returns  : a path and filename for the location of the peptide list frame on the server
# Descript : creates an HTML document on the server, and returns the path to the document
# Notes    :
##ENDPERLDOC##
sub generate_peplist_frame {
	my $peplist = shift;
	my $style = shift;
	my $output = "";
	my $filename;
	$output = <<OUTPUT;
<html>
<head>
<title>Protein Report Peptide List Frame</title>
$stylesheet_html
$style
</head>
<body leftmargin=9 topmargin=0>
<!--<span class=smallheading>Edit Peptides Here:</span><br>-->
$peplist
<script language="JavaScript" type="text/javascript"><!--
function handleResize() {
	var pep = document.all.peptides;
	var pepBottom = pep.offsetTop + pep.offsetHeight;
	var pepRight = pep.offsetLeft + pep.offsetWidth;
	var winHeight = document.body.offsetHeight;
	var winWidth = document.body.offsetWidth;
	while (pepBottom + 5 > winHeight && pep.rows > 2) {
		pep.rows--;
		pepBottom = pep.offsetTop + pep.offsetHeight;
	}
	while (pepBottom + 21 < winHeight) {
		pep.rows++;
		pepBottom = pep.offsetTop + pep.offsetHeight;
	}

	while (pepRight + 8 > winWidth && pep.cols > 8) {
		pep.cols--;
		pepRight = pep.offsetLeft + pep.offsetWidth;
	}
	while (pepRight + 16 < winWidth) {
		pep.cols++;
		pepRight = pep.offsetLeft + pep.offsetWidth;
	}
}
onresize=handleResize;
onload=handleResize;
//-->
</script>
</body>
</html>
OUTPUT

	($filename = $ourshortname) =~ s/\..+$//;
	$filename .= "_" . time . "_$$\_peplist.html";
	open REPORTFILE, ">$tempdir/$filename";
	print REPORTFILE $output;
	close REPORTFILE;
	return "$server/tmp/$filename";
}


##PERLDOC##
# Function : sequence_image
# Argument : sequence - the sequence against which peptides are being matched
# Argument : pepinfo - a reference to the %pepinfo hash
# Argument : firstAApos - the position of the first amino acid in the first matched peptide
# Argument : lastAApos - the position of the last amino acid in the last matched peptide
# Argument : masstype - the selected masstype, used for calculating mw
# Argument : location - where on the server to store the file
# Argument : weblocation - an html reference to the location directory
# Globals  : uses some, doesn't modify any
# Returns  : the path to a sequence image, its width, and its height
# Descript : creates an image that represents the peptide coverage of the entire protein
# Notes    : The fundamentals of the image-generating code came from flicka.  Uses GD.
##ENDPERLDOC##
sub sequence_image {
	my %p = @_;
	my $seq = $p{sequence};
	my $pepinfo = $p{pepinfo};
	my $begin_array = $p{firstAApos};
	my $end_array = $p{lastAApos};
	my $masstype = $p{masstype};
	my $location = $p{location};
	my $weblocation = $p{weblocation};
	if (! ($location && $weblocation)) {
		$location = $tempdir;
		$weblocation = $webtempdir;
	}

	my @peps = keys %{$pepinfo};
	my $mass = &precision(&mw ($masstype, 0, $seq), 1);

	##### most of this image code is from flicka #####

	my $seq_length = length($seq);
	my $FONT = gdTinyFont;
	my $WIDTH = 750;
	my $space_on_left = ($FONT->width) * length("1") + 2;
	my $space_on_right = ($FONT->width) * length("$seq_length") + 2;
	
	my $seq_line_begin_x = $space_on_left;
	my $seq_line_end_x = $WIDTH - $space_on_right;
	
	my $seq_line_begin_y = 0;
	my $seq_line_height = $FONT->height;
	my $seq_line_end_y = $seq_line_begin_y + $seq_line_height;

	my $matched_seq_line_begin_x = $space_on_left;
	my $matched_seq_line_end_x = $WIDTH - $space_on_right;
	my $matched_seq_line_begin_y = $seq_line_end_y;
	my $matched_seq_line_height = $FONT->height;
	my $matched_seq_line_end_y = $matched_seq_line_begin_y + $matched_seq_line_height;
	
	my $seq_bar_begin_x = $space_on_left;
	my $seq_bar_end_x = $WIDTH - $space_on_right;
	my $seq_bar_begin_y = $matched_seq_line_end_y + $FONT->height/2;
	my $seq_bar_height = 20;
	my $seq_bar_end_y = $seq_bar_begin_y + $seq_bar_height;
	my $HEIGHT = $seq_bar_end_y;
	my $seq_bar_width = $seq_bar_end_x-$seq_bar_begin_x;

	# create a new image
	my $im = new GD::Image($WIDTH,$HEIGHT);
	my $white = $im->colorAllocate(255,255,255);
	my $black = $im->colorAllocate(0,0,0);       
	my $yellow = $im->colorAllocate(255,255,0);
	$im->transparent($white);
	$im->interlaced('true');
	# Draw a black rectangle outline for the sequence bar
	$im->rectangle($seq_bar_begin_x,$seq_bar_begin_y,$seq_bar_end_x-1,$seq_bar_end_y-1,$black);

	# Draw the delineated peptides within the sequence
	# IMPORTANT: Semantics of a vertical line
	# A vertical line points to the space (or cutting area) between two amino acids, NOT an amino acid itself.
	
	my $num_cut_spots = $seq_length + 1;
	my ($begin, $end, $pep, $m);
	foreach $pep (@peps) {
		foreach $m (@{$pepinfo->{$pep}{start}}) {		# draw a rectangle at every place this peptide starts
		   $begin = $seq_bar_begin_x + ($m / $num_cut_spots) * $seq_bar_width;
		   $end = $seq_bar_begin_x + (($m + 1 + $pepinfo->{$pep}{len}) / $num_cut_spots) * $seq_bar_width;
		   $im->filledRectangle($begin, $seq_bar_begin_y, $end-1, $seq_bar_end_y-1, $yellow);
		   $im->rectangle($begin, $seq_bar_begin_y, $end-1, $seq_bar_end_y-1, $black);
	    }
	}

	# Draw the sequence line
	# The two numbers on the right and left
	# Number on left
	my $num_width = $FONT->width * length("1");
	my $num_height = $FONT->height;
	my $num_begin_x = 0;
	my $num_begin_y = (($seq_line_end_y+$seq_line_begin_y) - $num_height) / 2;
	my $num_end_x = $num_begin_x + $num_width;
	my $num_end_y = $num_begin_y + $num_height;
	# Write the number
	$im->string($FONT, $num_begin_x, $num_begin_y, "1", $black);
	# Number on right
	$num_width = $FONT->width * length("$seq_length");
	$num_height = $FONT->height;
	$num_begin_x = $WIDTH - $num_width;
	$num_begin_y = (($seq_line_end_y+$seq_line_begin_y) - $num_height) / 2;
	$num_end_x = $num_begin_x + $num_width;
	$num_end_y = $num_begin_y + $num_height;
	# Write the number
	$im->string($FONT, $num_begin_x, $num_begin_y, "$seq_length", $black);
	
	# Then, the two headed line
	$im->line($seq_line_begin_x, $seq_line_begin_y + $seq_line_height/2-1, $seq_line_end_x-1, $seq_line_begin_y + $seq_line_height/2-1, $black);
	# The left head
	$im->line($seq_line_begin_x, $seq_line_begin_y, $seq_line_begin_x, $seq_line_end_y-1, $black);
	# The right head
	$im->line($seq_line_end_x-1, $seq_line_begin_y, $seq_line_end_x-1, $seq_line_end_y-1, $black);
	
	# The text: molecular mass
	my $text_width = $FONT->width * length($mass);
	my $text_height = $FONT->height;
	my $text_begin_x = (($seq_line_end_x+$seq_line_begin_x) - $text_width) / 2;
	my $text_begin_y = (($seq_line_end_y+$seq_line_begin_y) - $text_height) / 2;
	my $text_end_x = $text_begin_x + $text_width;
	my $text_end_y = $text_begin_y + $text_height;
	# First make a white rectangle under it
	$im->filledRectangle($text_begin_x, $text_begin_y, $text_end_x-1, $text_end_y-1, $white);
	# Write the string
	$im->string($FONT, $text_begin_x, $text_begin_y, "$mass", $black);


	# Draw line, unless there are no matches
	unless (! defined $begin_array) {
		my $sub_seq = substr ($seq, $begin_array, $end_array - $begin_array);
		my $sub_seq_weight = &precision(&mw ($masstype, 0, $sub_seq), 1);

		# Draw the matched sequence line
		my $begin_line = $matched_seq_line_begin_x + ($begin_array / $num_cut_spots) * ($matched_seq_line_end_x-$matched_seq_line_begin_x);
		my $end_line = $matched_seq_line_begin_x + (($end_array+1) / $num_cut_spots) * ($matched_seq_line_end_x-$matched_seq_line_begin_x);

		# The two numbers on the right and left
		# Number on left
		$num_width = $FONT->width * length("$begin_array"+1);
		$num_height = $FONT->height;
		$num_begin_x = $begin_line - $num_width - 2;
		$num_begin_y = (($matched_seq_line_end_y+$matched_seq_line_begin_y) - $num_height) / 2;
		$num_end_x = $num_begin_x + $num_width;
		$num_end_y = $num_begin_y + $num_height;
		# Write the number
	    $im->string($FONT, $num_begin_x, $num_begin_y, "$begin_array"+1, $black);
		# Number on right
		$num_width = $FONT->width * length("$end_array");
		$num_height = $FONT->height;
		$num_begin_x = $end_line + 2;
		$num_begin_y = (($matched_seq_line_end_y+$matched_seq_line_begin_y) - $num_height) / 2;
		$num_end_x = $num_begin_x + $num_width;
		$num_end_y = $num_begin_y + $num_height;
		# Write the number
		$im->string($FONT, $num_begin_x, $num_begin_y, "$end_array", $black);
		
		# First the two headed line
		$im->line($begin_line, $matched_seq_line_begin_y + $matched_seq_line_height/2, $end_line-1, $matched_seq_line_begin_y + $matched_seq_line_height/2, $black);
		# The left head
		$im->line($begin_line, $matched_seq_line_begin_y, $begin_line, $matched_seq_line_end_y-1, $black);
		# The right head
		$im->line($end_line-1, $matched_seq_line_begin_y, $end_line-1, $matched_seq_line_end_y-1, $black);
		# The text: molecular mass
		# Print this only if it is smaller than the line's length
		my $text_width = $FONT->width * length($sub_seq_weight);
		unless ($text_width >= $end_line-$begin_line) {
			my $text_height = $FONT->height;
			my $text_begin_x = (($begin_line+$end_line) - $text_width) / 2;
			my $text_begin_y = (($matched_seq_line_end_y+$matched_seq_line_begin_y) - $text_height) / 2;
			my $text_end_x = $text_begin_x + $text_width;
			my $text_end_y = $text_begin_y + $text_height;
			# First make a white rectangle under it
			$im->filledRectangle($text_begin_x, $text_begin_y, $text_end_x-1, $text_end_y-1, $white);
			# Write the string
			$im->string($FONT, $text_begin_x, $text_begin_y, $sub_seq_weight, $black);
		}
	}

	my $filename;
	($filename = $ourshortname) =~ s/\..+$//;
	$filename .= "_" . time . "_$$\_seq.png";

	open (PNG, ">$location/$filename") || die ("Could not write to $location/$filename");		# create the image file
	binmode PNG;
	print PNG $im->png;
	close PNG;

	return "$weblocation/$filename", $WIDTH, $HEIGHT;

}


##PERLDOC##
# Function : format_rows
# Argument : first, the sequence (a string of only uppercase letters)
# Argument : second, a reference to the %pepinfo hash
# Argument : third, a reference to the %seqindex hash
# Globals  : uses some predefined variables, but doesn't modify any
# Returns  : a string containing all of the highlighted peptides and an array of strings, each of which is formatted with spaces, highlighting, etc
# Descript : Divides a sequence string into multiple rows containing formatting to display peptide and mod site positions
# Notes    : inserts a $space_char after every $space_after characters, and creates a new row every $wrap_after characters
##ENDPERLDOC##
sub format_rows {
	my $sequence = shift;
	my $pepinfo = shift;
	my $seqindex = shift;

	my $cominfo = shift;
	my $comindex = shift;

	my @seq_rows = ();
	my $cur_seq_row = "";
	my $highlighted_aas = "";

	my $openhighlight = qq(<span class=pep>);
	my $closehighlight = qq(</span>);
	my $closecomment = qq(</span>);
	my ($curpep, $endpos);
	my $curpos = 0;
	my $closeat = -1;		# This variable indicates the position at which the current peptide span tag should be closed.  If -1, there is no open peptide span tag
	my $comcloseat = -1;
	my $comment_tag;
	foreach (split '', $sequence) {
		if ($closeat == $curpos) {
			$cur_seq_row .= $closehighlight unless $comcloseat > 0;
			$closeat = -1;
		}
		if ($comcloseat == $curpos) {
			$cur_seq_row .= $closecomment;
			$comcloseat = -1;
			$cur_seq_row .= $openhighlight if $closeat > 0;
		}

		# add a space character after every $space_after characters, but not if we're at the end of the row:
		$cur_seq_row .= $space_char if (($curpos % $space_after == 0) && $curpos != 0 && !($curpos % $wrap_after == 0 && $curpos != 0));

		if ($curpos % $wrap_after == 0 && $curpos != 0) {	# This position is the end of the current row!
			$cur_seq_row .= $closecomment unless $comcloseat < 0;						# Close the comment span for this row, even though the comment may not end here
			$cur_seq_row .= $closehighlight unless ($closeat < 0 || $comcloseat > 0);	# Close the peptide span tag for this row, even though the peptide may not end here (but not necessary 
			push @seq_rows, $cur_seq_row;												# This row is complete, add it to the results array and start a new row
			$cur_seq_row = ($closeat < 0 || $comcloseat > 0) ? "" : $openhighlight;		# If the peptide span was closed due to row wrapping, open it again on the next row (but not if this is in the middle of a comment)
			$cur_seq_row .= ($comcloseat < 0) ? "" : $comment_tag;						# If the comment span was closed due to row wrapping, open it again
		}
		

		if (exists $comindex->{$curpos}) {			# if a comment begins at this position, open a span tag
			my $c = $cominfo->{$curpos}{color};
			$comment_tag = qq(<span style="background-color:$c">);
			$cur_seq_row .= $closehighlight if $closeat > 0;
			$cur_seq_row .= $comment_tag if $comcloseat < 0;
			my $comend = $curpos + $comindex->{$curpos};
			$comcloseat = $comend if $comend > $comcloseat;

		} 
		if (exists $seqindex->{$curpos}) {			# if a peptide begins at this position, open a span tag (but only if no comment spanis open)
			$cur_seq_row .= $openhighlight if ($closeat < 0 && $comcloseat < 0);
			$endpos = $curpos + $seqindex->{$curpos};
			$closeat = $endpos if $endpos > $closeat;
		}

		if (exists $modsites{$curpos} && $comcloseat < 0) {			# if this position is a mod site, highlight it appropriately (but only if no comment span is open)
			$cur_seq_row .= qq(<span class=m$modsites{$curpos}>$_</span>);
		} else {
			$cur_seq_row .= $_;
		}
		$highlighted_aas .= $_ if $closeat > -1;
		$curpos++;
	}

	my $notags;
	($notags = $cur_seq_row) =~ s/<.+?>//g;
	my $spaces_to_add = ($wrap_after + (($wrap_after - 1) / $space_after) * $space_length) - length $notags;

	$cur_seq_row .= $closehighlight unless $closeat < 0;	# Close up the final row ...
	$cur_seq_row .= $closecomment unless $comcloseat < 0;	# ...
	$cur_seq_row .= ' ' x $spaces_to_add;					# ... fill the remainder with spaces (if this isn't done for the last row, it may appear misaligned when printed) ...
	push @seq_rows, $cur_seq_row;							# ... and add it to the results list.

	return $highlighted_aas, @seq_rows;
}

##PERLDOC##
# Function : arrow_boxes
# Argument : first, a reference to an array of peptides
# Argument : second, a reference to the %pepinfo hash
# Argument : third, the sequence (a string of only uppercase letters)
# Globals  : uses some, doesn't modify any
# Returns  : a list of three elements: a reference to an array of image names, the width of the images, and a reference to a parallel array containing the heights of the images
# Descript : Creates images containing lines that line up with peptides in the sequence
# Notes    : The alignment of the character strings with lines in the images depends heavily
#			 on $character_width - this value will need to be changed if the font changes
##ENDPERLDOC##
sub arrow_boxes {
	my %arguments = @_;
	my $peps = $arguments{peps};
	my $pepinfo = $arguments{pepinfo};
	my $sequence = $arguments{sequence};
	my $location = $arguments{location};
	my $weblocation = $arguments{weblocation};
	if (! ($location && $weblocation)) {
		$location = $tempdir;
		$weblocation = $webtempdir;
	}

	my $base_filename;
	($base_filename = $ourshortname) =~ s/\..+$//;
	$base_filename .= "_" . time . "_$$";

	my $do_tic_thickness = 0;

	my ($img, $img_width, $img_height, $max_img_height, $pepcolor, $white);
	my %widest = ();

	my $seq_length = length $sequence;
	$img_width = ($seq_length + int ($seq_length / $space_after) * $space_length) * $character_width;
	$img_height = 15;
	$max_img_height = 200;

	$img = new GD::Image($img_width, $max_img_height);		# first create one long image that will later be divided into smaller chunks for each row
	$img->interlaced('true');
	$pepcolor = $img->colorAllocate(30,130,30);			# the old green color was (30,130,30)
	$white = $img->colorAllocate(255,255,255);

	my @modcolors = ($img->colorAllocate(0,255,0),
					 $img->colorAllocate(0,255,255),
					 $img->colorAllocate(255,0,255),
					 $img->colorAllocate(255,136,0),
					 $img->colorAllocate(255,80,80),
					 $img->colorAllocate(153,102,255),
					 $img->colorAllocate(204,204,204),
					 $img->colorAllocate(238,238,238));
	
	$img->filledRectangle(0, 0, $img_width, $max_img_height, $white);		# set background color to white

	my ($start, $length, $left, $width, $y, $pep, $offset, $i, $startrownum, $endrownum, $bottom);
	my (@thickness, @modinpep, %modlocs, $posinseq, $modcoord, $modcolor, $beginadjust, $endadjust);
	my $beginmargin = 1;		# this indicates how many pixels to cut off of the start of the peptide bar in order to leave a margin between peptides
	my $endmargin = 2;			# this indicates how many pixels to cut off the end of the bar
	my @peparr = keys %{$pepinfo};
	#@peparr = sort { length $b <=> length $a } @peparr;
	@peparr = sort { $pepinfo->{$b}{len} <=> $pepinfo->{$a}{len} } @peparr;		# sorting by length here will tend to make the longer peptide bars show up closer to the top
	foreach $pep (@peparr) {													# draw a line under each peptide
		next unless $pepinfo->{$pep}{start};
		for ($i = 0; $i < @{$pepinfo->{$pep}{start}}; $i++) {
			$start = $pepinfo->{$pep}{start}[$i];
			$length = $pepinfo->{$pep}{len};
			$startrownum = int ($start / $wrap_after);
			$endrownum = int (($start + $length - 1) / $wrap_after);		# the " - 1" here is necessary because a wrap does not occur unless the end character is one AFTER than $wrap_after

			$left = ($start + int ($start / $space_after) * $space_length) * $character_width;
			$width = ($length + (int (($start + $length - 1) / $space_after) - int ($start / $space_after)) * $space_length) * $character_width;

			@thickness = @{$pepinfo->{$pep}{thickness}};
			@modinpep = @{$pepinfo->{$pep}{modinpep}};
			&error("Malformed \$pepinfo: thickness and modinpep arrays are different sizes for $pep") if @thickness != @modinpep;


			foreach (0..$#thickness) {
				$y = &topmost_available_space($img, $left, $width, $white);
				$bottom = $y + 1;
				$bottom += $thickness[$_] if $do_tic_thickness;
				$img->filledRectangle($left+$beginmargin, $y, $left+$width-$endmargin, $bottom, $pepcolor);
				%modlocs = %{$modinpep[$_]};

				foreach (keys %modlocs) {		# color the locations under mods
					$beginadjust = ($_ == 0) ? $beginmargin : 0;
					$endadjust =  ($_ == $length-1) ? $endmargin : 1;
					$posinseq = $start + $_;
					$modcoord = ($posinseq + int ($posinseq / $space_after) * $space_length) * $character_width;
					$modcolor = $modcolors[$modlocs{$_}-1];
					$img->filledRectangle($modcoord+$beginadjust, $y, $modcoord+$character_width-$endadjust, $bottom, $modcolor);
				}
			}


			# store the height of the image
			$widest{$startrownum} = $bottom if $bottom > $widest{$startrownum};
			if ($startrownum != $endrownum && $bottom > $widest{$endrownum}) {
				$widest{$endrownum} = $bottom;
			}
		}
	}

	my ($box_width, $box_height, $box_img, $pngfile, $webpngfile, $start_pixel);
	my @img_filenames = ();
	my @img_heights = ();
	$box_width = ($wrap_after + int (($wrap_after-1) / $space_after) * $space_length) * $character_width;
	my $box_max = $seq_length / $wrap_after;
	my $j = 0;
	
	my $blank_img = new GD::Image($box_width, $img_height);		# create one common blank image to use when there are no peptide lines in a given box
	$blank_img->interlaced('true');
	$blank_img->filledRectangle(0, 0, $box_width, $img_height, $blank_img->colorAllocate(255,255,255));
	my $blankfilename = "$base_filename\_blank.png";

	open (PNG, ">$location/$blankfilename");
	binmode PNG;
	print PNG $blank_img->png;
	close PNG;

	$blankfilename = "$weblocation/$blankfilename";

	for ($i = 0; $i < $box_max; $i++) {							# now divide the single long image into smaller chunks for display under the rows of letters
		
		unless (exists $widest{$i}) {							# If this image is blank, don't write it to a new file.  Instead, use the already existing blank image.
			push @img_filenames, $blankfilename;
			push @img_heights, $img_height;
			next;
		}
		$box_height = &max($widest{$i} + 2, $img_height);
		
		$box_img = new GD::Image($box_width, $box_height);
		$box_img->interlaced('true');
		$start_pixel = $i * ($box_width + $character_width * $space_length);
		unless ($i+1 >= $box_max) {
			# normal case
			$box_img->copy($img, 0, 0, $start_pixel, 0, $box_width, $box_height);
		} else {
			# last image, source image might not be long enough to fill a new box
			my $remaining_width = $img_width - $start_pixel;
			$box_img->copy($img, 0, 0, $start_pixel, 0, $remaining_width, $box_height);
		}
		
		$pngfile = "$base_filename\_$i.png";
		$webpngfile = "$weblocation/$pngfile";
		$pngfile = "$location/$pngfile";
		
		open (PNG, ">$pngfile") || die ("Could not write to $pngfile");		# create the image file
		binmode PNG;
		print PNG $box_img->png;
		close PNG;

		push @img_filenames, $webpngfile;		# store the web filename for the image
		push @img_heights, $box_height;
	}


	return (\@img_filenames, $box_width, \@img_heights);
}


##PERLDOC##
# Function : topmost_available_space
# Argument : first, the image object
# Argument : second, the x position in the image at which to start looking for space
# Argument : third, the amount of horizontal space needed, in pixels
# Argument : fourth, the color index in this image that is considered "unoccupied" and therefore available
# Globals  : none
# Returns  : a number corresponding y-coordinate of the topmost available space in the image
# Descript : Starts at the top of an image and proceeds downward, returning the first available
#			 place in which a line of the given width will fit
# Notes    : will not accurately find space for lines thicker than one pixel, unless all lines in the image are the same thickness
##ENDPERLDOC##
sub topmost_available_space {
	my $img = shift;
	my $xpos = shift;
	my $width = shift;
	my $unoccupied_color = shift;

	my ($i, $j, $img_width, $img_height);
	my $empty_rows = 0;
	($img_width, $img_height) = $img->getBounds();
	VERT: for ($i = 0; $i < $img_height; $i++) {
		HORZ: for ($j = $xpos; $j < $xpos+$width; $j+=3) {
			if ($img->getPixel($j, $i) != $unoccupied_color) {
				$empty_rows = 0;
				next VERT;
			}
		}

		$empty_rows++;
		return $i if ($empty_rows == 2);
	}
	return -1;
}


##PERLDOC##
# Function : get_header_and_sequence
# Argument : first, the reference
# Globals  : second, the database
# Returns  : otherwise a two element list containing the header and sequence for this reference in database
# Descript : looks for reference in database and returns information contained there
# Notes    : 
##ENDPERLDOC##
sub get_header_and_sequence {
	my $ref = shift;
	my $db = shift;
	my $entry = &get_fasta_entry($ref, "$dbdir/$db");
	my $header = shift @$entry;
	my $sequence = join '', @$entry;
	return ($header, $sequence);
}


##PERLDOC##
# Function : get_fasta_entry
# Argument : First - reference to look up
# Argument : Second - database in which to look
# Globals  : none
# Returns  : a reference to an array containing the fasta entry (first element is the header, the rest are the sequence)
# Descript : Looks up a reference in a database and returns the result in array form
# Notes    : 
##ENDPERLDOC##
sub get_fasta_entry {
	my $ref = shift;
	my $db = shift;
	my @entry = ();
	$ref = &parseentryid($ref);
	if (&openidx($db)) {
		@entry = &lookupseq($ref);
	} else {
		@entry = &search_unindexed_db($db,$ref);
	}
	return \@entry;
}


##PERLDOC##
# Function : get_db_dropbox
# Argument : none
# Globals  : uses the @dbases array that is created globally instead of returned (why? why? why...?) when microchem_include.pl's &get_dbases is called.
# Returns  : HTML code for a <select> database chooser
# Descript : gets a list of databases, and formats them into a <select> element
# Notes    : a similar function exists in microchem_include, but it prints code instead of returning it, and doesn't allow the flexibility to change the HTML tags easily
##ENDPERLDOC##
sub get_db_dropbox {
	&get_dbases;
	my $dropbox = qq(<span class="dropbox"><SELECT name="db" onfocus="changeEnabled('ref');">\n);
	if (@dbases == 0) {
		$dropbox .= qq(<OPTION VALUE = "">(none)\n);
	} else {
		foreach (@dbases) {
			$dropbox .= qq(<OPTION VALUE = "$_");
			$dropbox .= " SELECTED" if ($_ eq ($db || "nr.fasta"));
			$dropbox .= (">$_\n");
		}
	}
	$dropbox .= qq(</SELECT></span>\n);
	return $dropbox;
}

sub load_dialog {
	my $loaddir = $FORM{loaddir};

	opendir DIR, "$seqdir/$loaddir";
	my @reportfiles = grep /^report\d+\.xml$/, readdir(DIR);
	closedir DIR;

	my (@reportnames, $date, $timestamp);
	foreach (@reportfiles) {
		$timestamp = (/^report(\d+)\.xml/)[0];
		$date = localtime $timestamp;
		push @reportnames, [$date, $_, "$seqdir/$loaddir/$_", $timestamp];
	}
	@reportnames = sort {$b->[3] <=> $a->[3]} @reportnames;

	my $reportlist = "";
	my $defcheck = "checked";
	my $looktext = "";
	if (@reportnames > 0) {
		$reportlist .= <<REPORT;
<span class=smallheading><nobr>The following Protein Report files were<br>found in $loaddir:</nobr></span><br><br><br>
<table cellspacing=0 cellpadding=0 border=0 width=350><tr>
	<td width=175 class=smallheading align=center>File Name</td>
	<td width=175 class=smallheading align=center>Date</td>
</tr></table>
<div style="width:370; height:100; overflow:auto"><table cellspacing=0 cellpadding=0 border=0 width=350>
REPORT
		foreach (@reportnames) {
			$reportlist .= <<RL;
<tr>
	<td><input type=radio name="loadfile" value="$_->[2]" $defcheck></td>
	<td class=smalltext>$_->[1]</td>
	<td width=15></td>
	<td class=smalltext>($_->[0])</td>
</tr>
RL
			$defcheck = "";
		}
		$reportlist .= qq(</table></div>\n);
		$reportlist .= qq(<br><center><button class="outlinebutton button" onclick="loadReport()">Load Selected Report</button></center>\n);
		$looktext = "or look for reports in another directory:";
	} else {
		if ($loaddir) {
			$reportlist .= qq(<span class=smallheading style="color:#ff0000">No reports found in $loaddir!</span>);
			$looktext = "Look for reports in another directory:";
		} else {
			$looktext = "Select the directory from which you would like to load a report:"
		}
	}


	my $reports = join '<br>', @reportnames;
	my $dropbox = &make_sequestdropbox("loaddir");

	print <<OUTPUT;

Content-type: text/html

<html>
<head>
<title>Load a Protein Report</title>
$stylesheet_html
$head_style
</head>
<body>
<form name="mainform" action="$ourname" method="POST">
<input type=hidden name="loadwindow">
$reportlist
<br><br>
<span class=smallheading>
$looktext
</span>
<br><br>
$dropbox
&nbsp;&nbsp;&nbsp;&nbsp;
<button class="outlinebutton button" onclick="changeDir()">Go</button>

<script language="JavaScript" type="text/javascript">
function changeDir() {
	document.mainform.loadwindow.value="true";
	document.mainform.target="_self";
	document.mainform.submit();
}
//document.mainform.loaddir.onchange=changeDir;

function loadReport() {
	var windowID = "mainwindow" + parseInt(Math.random() * 10000);		//# create a unique ID for the window where the report will be loaded
	opener.parent.name = windowID;
	document.mainform.target = windowID;
	document.mainform.submit();
	opener.parent.focus();
	close();
}

</script>

</form>
</body>
</html>
OUTPUT

	exit 0;
}



##PERLDOC##
# Function : translate_seq
# Argument : $nucref - The nucleotide reference to translate into protein
# Argument : $frame - The frame to use for the translation (+1, +2, -1, ...)
# Globals  : none
# Returns  : $seq - The protein sequence that was translated from the nucleotide sequence in the given frame.
# Descript : Translates a nucleotide sequence into a protein sequence using the given frame.
# Notes    :
##ENDPERLDOC##
sub translate_seq {
	## prepare translation apparatus:

	my $transl_table = 1;
	my $transl_name = &calculateTranslationTable($transl_table);
	
	my $nucref = shift;
	my $frame = shift;

	my $seq;
	my $dummy;
	($seq) = &translate ($nucref, $frame);
	$seq =~ s/<.*?>|\s//g;  # Strip HTML tags
	
	return $seq;
}



##PERLDOC##
# Function : settings_dialog
# Argument : none
# Globals  : uses some, doesn't modify any
# Returns  : HTML code for the popup description/label editor window
# Descript : creates HTML and javascript
# Notes    :
##ENDPERLDOC##
sub settings_dialog {

	# Note: This html code is placed in <textarea> tags and then copied into a popup window. As such,
	#		if <textarea> tags are required in this code, spell them <txtarea> instead - they will be
	#		replaced with the correct spelling in javascript when the popup window is created.


	#print <<OUTPUT;
	#my $set = <<OUTPUT;

	my $set = <<OUTPUT;
<html>
<head>
<title>Protein Report Settings</title>
$stylesheet_html
$report_style
$head_style
</head>
<body>
<div id="helpballoon" class="helpballoon smalltext" onmouseover="window.event.cancelBubble = true;"></div>

<div id="newcomment" style="position:absolute; visibility:hidden; width:300; height:205; left:100; top:100; padding:5px; border:solid #0000cc 2px; background-color:#ffffff" class=smallheading>
<span id=newcommenttitle style="position:absolute; width:287; height:14; text-align:center; background-color:#dddddd">Add new sequence highlight</span>
<br><br>
Position:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Start&nbsp;<input class=outline type=text id=commentstart style="font-family:verdana; font-size:9" size=5>
&nbsp;&nbsp;&nbsp;&nbsp;End&nbsp;<input class=outline type=text id=commentend style="font-family:verdana; font-size:9" size=5>
<br><br>
Color:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<span id=colorchoices style="cursor:hand">
<tt style="background-color:#ffc0c0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#e0a0a0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#c0ffc0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#a0e0a0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#c0c0ff; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#a0a0e0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#ffffc0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#e0e0a0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#ffc0ff; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#e0a0e0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#c0ffff; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
<tt style="background-color:#a0e0e0; border:solid #ffffff 1px;" onclick="selectColor(this)">&nbsp;</tt>
</span>
<input type=hidden name=currentcolor>
<br><br>
Description:<br>
<txtarea class=outline id="seqcommentbox" rows=3 cols=33></txtarea>
<br><br style="font-size:4">
<table cellspacing=0 cellpadding=0 border=0 width=284><tr><td align=right>
<button class=outlinebutton onclick="deleteSeqComment()" style="width:135; visibility:hidden" id=delbutton>Delete this highlight</button>&nbsp;&nbsp;&nbsp;&nbsp;
<button class=outlinebutton onclick="cancelSeqComment()" style="width:50">Cancel</button>&nbsp;&nbsp;
<button class=outlinebutton onclick="submitSeqComment()" style="width:50">OK</button>
</td></tr></table>
</div>

<table cellspacing=0 cellpadding=0 border=0 width=590><tr valign=top><td width=300>
<span class=smallheading>Legend:</span><br>
OUTPUT
	$set .= qq(<table cellspacing=0 cellpadding=0 border=0>\n);
	foreach (1..8) {
		$set .= qq(<tr><td><span class="m$_"><tt>&nbsp;</tt></span>&nbsp;&nbsp;<input class=outline type=text style="font-family:verdana; font-size:9" id="m${_}Label" size=45 onkeyup="handleLegendTyping('m$_');" onchange="handleLegendTyping('m$_');" helptext="Use these fields to change the labels that are displayed in the report legend"></td></tr>\n);
	}
	$set .= qq(</table>);
	$set .= <<OUTPUT;
<br>
</td><td width=10></td><td width=280>
<span class=smallheading>First residue number:</span><br>
<input class=outline type=text size=5 id="startposition" maxlength=5 style="font-family:verdana; font-size:9" helptext="This number is the start position of the sequence (it is the number next to the first sequence row in the report). Rows are counted from this number upward. <br><b>Note:</b> Changes to this number will not take effect until you refresh the report">
<br><br><br>
<span class=smallheading>Sequence highlighting:</span>

<div style="width:270; height:84; padding:5px" class=tabarea  helptext="Click 'Add New' to add a new sequence highlight. Click on a sequence highlight to edit or remove it. <br><b>Note:</b> Sequence highlight changes will not take effect until you refresh the report">
<table cellspacing=0 cellpadding=0 border=0 width=238>
<tr><td class=smallheading style="cursor:hand" onclick="addSeqComment()" onmouseover="this.style.backgroundColor='#dddddd'" onmouseout="this.style.backgroundColor='#ffffff'">&lt;<b>Add new</b>&gt;</td></tr>
</table>
<span id=commentlist style="width:238; overflow:hidden">
</span>
</div>

</td></tr></table>
<span class=smallheading>Comments:</span>
<br>
<txtarea id="comments" class=outline cols=70 rows=7 onkeyup="storeCursor(this); handleCommentsTyping();" onclick="storeCursor(this)" onselect="storeCursor(this)" helptext="Comments entered in this box will appear on the current report. If the 'Use HTML' option is selected, you may use HTML tags to format this text"></txtarea>
<input type=checkbox id="usehtml" style="height:1em; padding:0" onclick="toggleHTML(this.checked);" checked helptext="If this option is selected, text in the comments area will be interpreted as HTML"><span class=smallheading style="font-weight:normal">Use HTML formatting</span>
<br><br style="font-size:3">
<table cellspacing=0 cellpadding=0 border=0 width=580><tr valign=middle>
<td align=left width=450>
	&nbsp;&nbsp;&nbsp;
	<span id=htmltags>
		<span class=smallheading style="font-weight:normal">Insert:</span>&nbsp;&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('br')" helptext="Line break">br</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('sp')" helptext="Non-breaking space">space</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('sup')" helptext="Superscript">sup</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('sub')" helptext="Subscript">sub</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('bold')" helptext="Bold font">bold</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('ital')" helptext="Italic font">italic</button>&nbsp;
		<button class="outlinebutton" onclick="insertHTMLTag('und')" helptext="Underline">underline</button>&nbsp;
	</span>
</td>
<td align=right width=130>
	<span align=right class=smallheading style="cursor:hand; color:#0000cc" onclick="startHelp();" helptext="Help - click anywhere to turn off">Help</span>
	&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	<button class=outlinebutton onclick="allDone()" style="width:75" helptext="Click here when you have finished making changes">Done</button>
</td></tr></table>

<script language="JavaScript" type="text/javascript"><!--
var reportAll = opener.parent.report.document.all;
var commentCount = 0;
var currentlyEditedComment = '';
var editingComment = 0;
function selectColor(obj) {
	deselectAllColors();
	document.all.currentcolor.value = obj.style.backgroundColor;	// save this color
	obj.style.borderColor = '#000000';								// set obj's border
}

function deselectAllColors() {
	var colorEl = document.all.colorchoices;
	for (var i = 0; i < colorEl.children.length; i++) {
		if (colorEl.children[i].tagName == "TT") colorEl.children[i].style.borderColor = '#ffffff';	
	}
}
function selectColorByName(c) {		// 'c' should be the name of a color
	var colorEl = document.all.colorchoices;
	for (var i = 0; i < colorEl.children.length; i++) {
		if (colorEl.children[i].style.backgroundColor.toUpperCase() == c.toUpperCase()) {
			colorEl.children[i].style.borderColor = '#000000';
			return;
		}
	}
	alert("Color not found: " + c);
}

function cancelSeqComment() {
	document.all.newcomment.style.visibility = 'hidden';
}
function submitSeqComment() {
	var posStart = document.all.commentstart.value;
	var posEnd = document.all.commentend.value;
	var color = document.all.currentcolor.value;
	var com = document.all.seqcommentbox.value;
	var pos;

	if (posStart.match(/^\\s*\\d+\\s*\$/) && posEnd.match(/^\\s*\\d+\\s*\$/)) {
		pos = posStart.replace(/\\s/g,'') + '-' + posEnd.replace(/\\s/g,'');
	} else {
		alert("The start and end positions must be integers!");
		return;
	}
	if (com.match(/::/)) {
		alert("You may not use a double colon ('::') in your description!");
		return;
	}

	if (!editingComment) {
		var newEntry = createCommentListEntry(pos, color, com);
		document.all.commentlist.innerHTML = newEntry + document.all.commentlist.innerHTML;
		document.all.newcomment.style.visibility = 'hidden';
	} else {
		editCurrentComment(pos, color, com);
	}
}
function centerCommentArea() {
	var com = document.all.newcomment;
	var bod = document.body;
	com.style.left = parseInt(bod.clientWidth / 2 - com.clientWidth / 2);
	com.style.top  = parseInt(bod.clientHeight/ 2 - com.clientHeight/ 2);
}
function addSeqComment() {
	centerCommentArea();
	deselectAllColors();
	document.all.currentcolor.value = '#ffffff';
	document.all.commentstart.value = '';
	document.all.commentend.value = '';
	document.all.seqcommentbox.value = '';
	document.all.newcommenttitle.innerText = "Add new sequence highlight";
	document.all.delbutton.style.visibility = 'hidden';
	editingComment = 0;
	document.all.newcomment.style.visibility = 'visible';
}
function createCommentListEntry(pos, color, com) {
	var newName = "comment" + commentCount++;
	var entry = "<table id='"+newName+"table' cellspacing=0 cellpadding=0 border=0 width=238>";
	entry += "<tr valign=top onclick='editSeqComment(this)' style='cursor:hand' comID='"+newName+"' onmouseover=\\"this.style.backgroundColor='#dddddd'\\" onmouseout=\\"this.style.backgroundColor='#ffffff'\\">"
	entry += "<td width=70 id=tdpos"+newName+" class=smalltext>" + pos + "</td>";
	entry += "<td width=10 id=tdcolor"+newName+" style=\\"background-color:'"+color+"'\\"></td>"
	entry += "<td width=10></td>";
	entry += "<td width=160 id=tdcom"+newName+" class=smalltext>" + com + "</td>";
	entry += "</tr></table>";
	entry += "<input type=hidden id=" + newName + " value=\\""+comInputValue(pos, color, com)+"\\">";
	return entry;
}
function comInputValue(pos, color, com) {
	return pos+"::"+color+"::"+com;
}
function editSeqComment(com) {
	centerCommentArea();
	deselectAllColors();

	currentlyEditedComment = com.comID;
	var comStr = document.all(currentlyEditedComment).value;
	comStr = comStr.split(/::/);
	var positions = comStr[0].split(/-/);
	
	document.all.commentstart.value = positions[0];
	document.all.commentend.value = positions[1];
	document.all.currentcolor.value = comStr[1];
	document.all.seqcommentbox.value = comStr[2];

	selectColorByName(comStr[1]);

	document.all.newcommenttitle.innerText = "Edit this sequence highlight";
	document.all.delbutton.style.visibility = 'inherit';
	editingComment = 1;

	document.all.newcomment.style.visibility = 'visible';

}
function editCurrentComment(pos, color, com) {
	var comInput = document.all(currentlyEditedComment);
	comInput.value = comInputValue(pos, color, com);

	document.all('tdpos'+currentlyEditedComment).innerText = pos;
	document.all('tdcolor'+currentlyEditedComment).style.backgroundColor = color;
	document.all('tdcom'+currentlyEditedComment).innerText = com;


	document.all.newcomment.style.visibility = 'hidden';
}
function getSeqCommentString() {
	var str = '';
	var comList = document.all.commentlist;
	for (var i = 0; i < comList.children.length; i++) {
		if (comList.children[i].tagName == "INPUT") {
			var t = comList.children[i].value;
			if (t.match(/::/)) str += t + ' :,,:';
		}
	}
	return str;
}
function startupSeqComments() {
	var str = opener.document.mainform.seqcomments.value;
	var coms = str.split(':,,:');
	var commentsCode = '';
	var cominfo;
	for (var i=0; i< coms.length; i++) {
		if (coms[i] == '') break;
		cominfo = coms[i].split(/::/);
		commentsCode += createCommentListEntry(cominfo[0], cominfo[1], cominfo[2]);
	}
	document.all.commentlist.innerHTML = commentsCode;
}
function deleteSeqComment() {
	document.all(currentlyEditedComment).outerHTML = '';			// delete the input element that stores the data
	document.all(currentlyEditedComment+"table").outerHTML = '';	// delete the entry in the list
	document.all.newcomment.style.visibility = 'hidden';			// hide the dialog
}




function allDone() {

	opener.document.mainform.startposition.value = document.all.startposition.value;
	opener.document.mainform.seqcomments.value = getSeqCommentString();
	window.close();
}
function handleCommentsTyping() {
	if (!opener) return;
	setComments();
	if (document.all.comments.value != '') {
		reportAll.commentsarea.style.display = '';
	} else {
		reportAll.commentsarea.style.display = 'none';
	}
}
function handleLegendTyping(mn) {
	if (!opener) return;
	var labelID = mn+"Label";
	var legendID = mn+"Legend";
	var label = document.all(labelID).value;
	reportAll(labelID).innerText = label;
	if (label != '') {
		reportAll(legendID).style.display = '';
	} else {
		reportAll(legendID).style.display = 'none';
	}
}
var usingHTML = true;
function doStartUp() {
	usingHTML = (reportAll.usehtml.value == "yes");
	document.all.usehtml.checked = usingHTML;
	var name;
	for (var i = 1; i <= 8; i++) {
		name = "m"+i+"Label";
		document.all(name).value = reportAll(name).innerText;
	}
	getComments();
	if (usingHTML) {
		document.all.htmltags.style.display="";
	}
	document.all.startposition.value = opener.document.mainform.startposition.value;
	startupSeqComments();
}
function getComments() {
	document.all.comments.value = (usingHTML) ? reportAll.comments.innerHTML : reportAll.comments.innerText;
}
function setComments() {
	if (usingHTML) {
		reportAll.comments.innerHTML = document.all.comments.value;
	} else {
		reportAll.comments.innerText = document.all.comments.value;
	}
}

function toggleHTML(useHTML) {
	if (useHTML) {
		reportAll.usehtml.value = "yes";
		usingHTML = true;
	} else {
		reportAll.usehtml.value = "no";
		usingHTML = false;
	}
	setComments();
	document.all.htmltags.style.display = document.all.htmltags.style.display == "" ? "none" : "";
}

function gotFocus() {
	if (opener) opener.focus();
	window.focus();
}


function insertHTMLTag(tagtext) {
	tagtext = tagtext.toUpperCase();
	var editor = document.all.comments;
	var beforeText = '';
	var afterText = '';

	switch (tagtext) {
		case 'BR': beforeText = '<BR>'; break;
		case 'SP': beforeText = '&nbsp;'; break;
		case 'SUP': beforeText = '<SUP>'; afterText = '</SUP>'; break;
		case 'SUB': beforeText = '<SUB>'; afterText = '</SUB>'; break;
		case 'BOLD': beforeText = '<B>'; afterText = '</B>'; break;
		case 'ITAL': beforeText = '<I>'; afterText = '</I>'; break;
		case 'UND': beforeText = '<U>'; afterText = '</U>'; break;
	}

	if (!editor.cursorPos || editor.cursorPos.text == '' || !afterText) {
		var t = beforeText + afterText;
		if (editor.createTextRange && editor.cursorPos) {
			editor.cursorPos.text = (editor.cursorPos.text.charAt(editor.cursorPos.text.length - 1)) == ' ' ? t+' ' : t;
		} else {
			editor.value += t;
		}
	} else {
		if (editor.createTextRange) {
			editor.cursorPos.text = beforeText + editor.cursorPos.text + afterText;
		} else {
			editor.value += beforeText + afterText;
		}
	}
	handleCommentsTyping();
}
function storeCursor(el) {
	if (el.createTextRange) el.cursorPos = document.selection.createRange().duplicate();
}

onfocus=gotFocus;
//onload=doStartUp;


@{[&help_javascript]}

//-->
</script>
</body>
</html>

OUTPUT

	#exit 0;
	return $set;
}



##PERLDOC##
# Function : output_form
# Argument : NONE
# Globals  : NONE
# Returns  : NONE
# Descript : This is the output form everyone sees when calling this page with no cgi values defined.
# Notes    : It creates a page header and exits with 0.
##ENDPERLDOC##
sub output_form {

	my $head_content = &create_head_content(seq => "", compmode => "REF", noreport => 1);
	my $peplist_textarea = &create_peplist_textarea([], $head_style);

	my $head_frame = &generate_head_frame($head_content, $head_style);
	my $peplist_frame = &generate_peplist_frame($peplist_textarea, $head_style);

	print <<OUTPUT;

Content-type: text/html

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN">
<html>
<head>
<title>Protein Report</title>
</head>
<script language="JavaScript" type="text/javascript"><!--
function startUp() {
	window.frames["head"].startUp();
}
//-->
</script>
<frameset onload="startUp();" rows="186,*" frameborder=no>
	<frame name="head" src="$head_frame" noresize>
	<frameset cols="200,*">
		<frame name="peplist" src="$peplist_frame" noresize>
		<frame src="about:blank" noresize>
	</frameset>
</frameset>
</html>
OUTPUT

	exit 0;
}

