#!/usr/bin/env perl

#-------------------------------------
#	Flicka
#	(C)1998 Harvard University
#
#	W. S. Lane/M. Baker/D. J. Weiner
#
#	v3.1a
#
#	licensed to Finnigan
#-------------------------------------


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
	require "interfaces_include.pl";
	require "html_include.pl";
}
################################################
require "fastaidx_lib.pl";

&cgi_receive();

# constants for Met and * colors
$MetHTML = qq(<span style="color:#8C1717"><b>);
$MetHTMLend = qq(</b></span>);

## for the values:
$runHTML = qq(<span style="color:#0099cc">);
$knownrunHTML = qq(<span style="color:#0099cc">);
$num_stopsHTML = qq(<span style="color:#0099cc">);
$num_unknownsHTML = qq(<span style="color:#0099cc">);

$HTMLend = "</span>";

## for best values (longest runs, least stops)
## when translating ALL reading frames
$bestrunHTML = qq(<span style="color:red; font-weight:bold">);
$bestknownrunHTML = qq(<span style="color:red; font-weight:bold">);
$bestnum_stopsHTML = qq(<span style="color:red; font-weight:bold">);
$bestnum_unknownsHTML = qq(<span style="color:red; font-weight:bold">);

## heading titles:
##
$headingHTML = qq(<span class=smallheading>);
$bestrunTITLE = "Longest ORF:";
$bestknownrunTITLE = "Longest ORF, no X:";
$num_stopsTITLE = "Stops:";
$num_unknownsTITLE =  "X:";

$masstype = $FORM{"MassType"} ? "mono" : "average";
$dir = $FORM{"Dir"};
$db = $FORM{"Db"};
$references = $FORM{"Ref"};
@refs = split (' ', $FORM{"Ref"});
$FORM{"Pep"} =~ tr/a-z/A-Z/;
@peps = split (' ', $FORM{"Pep"});
$is_nucleo = $FORM{"NucDb"};
$sort = $FORM{"Sort"};
$ps = $FORM{"Pep"};
$already = 0;
$globalpepcutform = ""; # Kludge to get form outside of original form.

# DJW 7/99
# functionality to allow user to select certain ORF to be displayed.
# default: only frames that contains a pep match is displayed.
# if frames are specified, those frames are displayed, regardless of match.
# if no peptide is specified, all frames are shown.
# behavior: Frames=123: frames selected: +1, +2, +3.  Frames=456: -1, -2, -3.

%numbers = ("+1" => "1", "+2" => "2", "+3" => "3", "-1" => "4", "-2" => "5", "-3" => "6");

$frm = $FORM{"Frames"};
if (!defined $frm || $frm eq "ALL") { @frms = ("+1", "+2", "+3", "-1", "-2", "-3"); }
else {
	if ($frm =~ /1/) { push (@frms, "+1"); }
	if ($frm =~ /2/) { push (@frms, "+2"); }
	if ($frm =~ /3/) { push (@frms, "+3"); }
	if ($frm =~ /4/) { push (@frms, "-1");  }
	if ($frm =~ /5/) { push (@frms, "-2");  }
	if ($frm =~ /6/) { push (@frms, "-3");  }
}

$num_frms = length @fmrs;

$db_is_indexed = &openidx($db);

%seqs = ();
foreach $ref (@refs) {
	my $myref = &parseentryid($ref);
	if ($db_is_indexed) {
		@{$seqs{$myref}} = &lookupseq($myref);
	} else {
		@{$seqs{$myref}} = &search_unindexed_db($db,$myref);
	}
}

&MS_pages_header ("Flicka", "#CFB53B");

print qq(<hr>);
print "<form name='flicka' action='$retrieve' method='post' style='margin-top:0; margin-bottom:0'>";
&javascript;

foreach $ref (@refs) {
	&ref_info_print (db => $db, "ref" => $ref, peps => \@peps, is_nucleo => $is_nucleo, masstype => $masstype);
}

#&pep_info_print (peps => \@peps);


&print_flicka_to_muquest_form();
&print_pepcut_to_muquest_form();
print "$globalpepcutform";
exit ();


sub pep_info_print {
	my (%args) = @_;
	my ($peps) = $args{"peps"};

	# if # of peps is less than five, output Blast links:
	if ((@{$peps} < 5) && (@{$peps} > 0)) {
		my ($url);

		print ("<tt><b>Perform NCBI Blast Search</b> (nr protein database) on");

		foreach $pep (@{$peps}) {
			$url = $remoteblast . "?" . join ("&amp;", "QUERY=$pep", "PROGRAM=blastp", "DATABASE=nr", $default_blast_options);

			print qq( <a href="$url">$pep</a>);

		}
		print ("</tt>");
	}
}

sub ref_info_print {
	my %args = @_;
	my ($db, $ref, $peps, $is_nucleo, $masstype) = ($args{"db"}, $args{"ref"}, $args{"peps"}, $args{"is_nucleo"},
												  $args{"masstype"});

	#added by Georgi 07/06/2000
	&print_sample_info;

	# this is horribly inefficient--need to change the structure of the whole program.
	# presently included to calculate bestrun values and colors (see translate)
	if ($is_nucleo) {
		foreach $frame (@frms) {
			&translate_seq ($ref, $frame);
		}
	}

	# DJW
	if ($is_nucleo) {
		foreach $frame (("+1", "+2", "+3", "-1", "-2", "-3")) {
			my $seq = &translate_seq ($ref, $frame);
			$seq =~ tr/A-Z*()//cd;
			$len = length ($seq);
			# display all frames if nothing is specified
			if (!$frm && !$ps) {
				print qq(<table cellpadding=3 cellspacing=0 border=0 width=710 style="border:solid #e4e4e4 1px">);
				&print_orf;
				&print_buttons;
				&print_header;

				for ($i = 0; $i < $len; $i++) {

					# put in a space after every ten, a <BR> after every 80:
					if (($i % 10 == 0) && ($i != 0)) {
						if ($i % 80 == 0) {
							print ("<br>");
						}
						print ("\n");
					}
					print substr ($seq, $i, 1); # print the AA
				}
				# should be a separate function
				$mass = &mw ($masstype, 0, $seq);
				$mass = &precision ($mass, 1);
				print qq(<tr><td class=title>Mass ($masstype):&nbsp;<td class=smalltext>$mass</td></tr>);
				print qq(</table>);
			}
			print ("<div id=\"framespan$numbers{$frame}\" class=normaltext");

			$translation = $numbers{$frame};
			if ($FORM{"Frames"} =~ /$translation/ || $FORM{"Frames"} eq "ALL") {
				print (">");
			} else {
				print (" style=\"none\">");
			}
			&highlight_peps_in_seq (seq => $seq, peps => $peps, masstype => $masstype); # skip lookup
		}
		# Added by DJW 7/99.
		# creates one single table at the end of the form that displays all specified peptides and their matching values, per frame
		&display_pos;
		#print qq(<img border=0 src="$webimagedir/blank.gif" onLoad=add_frames_to_url($frames_for_url)>);
		print "</form>";
	} else {
		&seq_print (%args);
	}
}

## this subroutine prints out the sequence for the given reference.

sub seq_print {
	my (%args) = @_;
	my ($ref, $peps, $masstype) = ($args{"ref"}, $args{"peps"}, $args{"masstype"});

	my ($myref, @seq, $fasta_hdr, $seq);

	$myref = &parseentryid($ref);
	@seq = @{$seqs{$myref}};

	if (!@seq) {
		print <<ERRORREPORT;
</table></form>
<form name="altdbform" ACTION="$ourname" method=post style="margin-top:8">
<table cellpadding=3 cellspacing=0 border=0 width=710>
<tr><td width=20><td>
<span class=smallheading style="color:red">$myref not found in $db.</span>
<li><span class=smalltext>Check to see if </span><span class=smallheading>$database</span><span class=smalltext> is present <span class=smalltext> on the webserver</span><span class=smallheading> $webserver</span> in</span><span class=smallheading> $dbdir</span></li>
<li><span class=smalltext>Check to see if </span><span class=smallheading>$database</span><span class=smalltext> has its description line indexed. See </span><span class=smallheading><a href="$fastaidx_web?selected=$database">FastaIdx Indexer</a></span></li>
<li><span class=smalltext>When searching multiple databases, </span><span class=smallheading>$myref</span><span class=smalltext> may be from an alternative database. <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;If so, select here:&nbsp;</span>
<span class="dropbox"><SELECT NAME="Db" onChange="submit()">
ERRORREPORT
		&get_dbases;
		foreach $dbname (@ordered_db_names) {
			print qq(<OPTION VALUE=\"$dbdir\/$dbname\");
			print " selected" if ($dbname eq "$database");
			print ">$dbname\n";
		}
		print <<ALTDB;
</SELECT></span>&nbsp;&nbsp;</li></tt>
<input type="hidden" name="MassType" value="$masstype">
<input type="hidden" name="Ref" value="$references">
<input type="hidden" name="NucDb" value="$is_nucleo">
<input type="hidden" name="Pep" value="$ps">
<input type="hidden" name="Dir" value="$dir">
</td></tr></table></form>
ALTDB

		return;
	}

	# print FASTA header:
	$fasta_hdr = shift @seq;
	chomp $fasta_hdr;

	$seq = join ("", @seq);
	$n = $seq;
	&print_buttons;

	print "<br style=font-size:8>";
	# $ref has bars "|" in it, so we must protect it from being interpreted:
	# also, it needs to be case-insensitive (don't ask me why)
	#print $fasta_hdr;
	if ($fasta_hdr =~ m!^>\Q$ref\E(\S*\s)(.*)!i) {
	    print qq(<tr><td class=title valign=top width=75>Header:&nbsp;</td>);
		print qq(<td class=data colspan=4 width=635>$ref$1$2</td></tr>);
		print qq(<tr height=10><td class=title></td><td></td></tr>);
	} else {
	    print qq(<tr><td class=title valign=top width=75>Header:&nbsp;</td>);
        print "<td class=data colspan=4 width=635>", &HTML_encode($fasta_hdr), "</td></tr>";
		print qq(<tr height=10><td class=title></td><td></td></tr>);

	}
	&highlight_peps_in_seq (seq => $seq, peps => $peps, masstype => $masstype);
}

sub highlight_peps_in_seq {
	my (%args) = @_;
#	my ($seq, $peps, $masstype) = ($args{"seq"}, $args{"peps"}, $args{"masstype"});
	my ($seq, $peps) = ($args{"seq"}, $args{"peps"});
	my $masstype = "Average";

	my (@matcharray, $pos, $len, $i);
	my (%starts, $url);

	LOOP:
	foreach $pep (@{$peps}) {
		$len = length ($pep);

		SEARCH:
		while ($seq =~ m!$pep!gi) {
			$pos = pos($seq);

			for ($i = $pos - $len; $i < $pos; $i++) {
				$matcharray[$i] = 1;
			}

			# reset search position to just after *beginning* of last match
			pos ($seq) = $pos - $len + 1;

			# keep track of matches:
			if ($starts{$pep}) { $starts{$pep} .= ":"; }
			$starts{$pep} .= $pos - $len + 1;

			#random hashes used to display nucleo positionings
			$huh{$pep} = $starts{$pep};
		}
		$table{$pep}{$frame} .= $starts{$pep};
	}
	# DJW 7/99
	# continue executing function only if we have a match.  else continue looping.
	if ($is_nucleo) {
		my ($num_matched, $count_percent, $mass_percent, $smallmass, $smallpep, @matched_aas);

		$num_matched = 0;
		$len = length ($seq);
		for ($i = 0; $i < $len; $i++) {
			if ($matcharray[$i]) {
				$num_matched++;
				push (@matched_aas, substr ($seq, $i, 1));
			}
		}
		unless (defined $frm) {
			if ($num_matched <= length ($pep)) {
				print <<EOF;
					<script language="Javascript">
					<!--
					document.all["framespan$translation"].style.display = "none";
					document.all["checkbox$translation"].checked = false;
					document.all["checkbox$translation"].initial = false;
					-->
					</script>
EOF
			} else {
				print <<EOF;
					<script language="Javascript">
					document.all["framespan$translation"].style.display = "";
					document.all["checkbox$translation"].checked = true;
					document.all["checkbox$translation"].initial = true;
					-->
					</script>
EOF
			}
		}
	}
	$n = $seq;
	if ($is_nucleo)
	{
		print qq(<br><table cellpadding=3 cellspacing=0 border=0 width=710 style="border:solid #e4e4e4 1px">);
		&print_orf;
		&print_buttons ($numbers{$frame});
		# display full reference
		&print_header;
	}

	my ($matchHTML) = qq(<span style="color:#FF0000; font-weight:bold">);
	my ($unmatchHTML) = "</span>";


	# print some pertinent info:
	$mass = &mw ($masstype, 0, $seq);
	$mass = &precision ($mass, 1);

	print qq(<tr height=20><td class=title nowrap width=75>&nbsp;&nbsp;Avg Mass:&nbsp;</td><td class=smalltext width=115>&nbsp;$mass</td>\n);
	# DJW
	# same chunk of code as above.  potentially unnecessary
	my ($num_matched, $count_percent, $mass_percent, $smallmass, $smallpep, @matched_aas);

	$num_matched = 0;
	$len = length ($seq);

	for ($i = 0; $i < $len; $i++) {
		if ($matcharray[$i]) {
			$num_matched++;
			push (@matched_aas, substr ($seq, $i, 1));
		}
	}

	#if ($num_matched <= length ($pep) && $is_nucleo) { print "<BR>"; next; }

	$smallpep = join ("", @matched_aas);
	$smallmass = &mw ($masstype, 0, $smallpep) if ($smallpep);
	$smallmass = &precision ($smallmass, 1);

	$count_percent = &precision (100 * $num_matched/$len, 1);
	$mass_percent = &precision (100 * $smallmass/$mass, 1);

	print ("<td class=title width=70>Coverage:&nbsp;</td><td class=smalltext nowrap colspan=2 width=450>&nbsp;$num_matched/$len = <b>$count_percent%</b> by amino acid count, ",
         "$smallmass/$mass = <b>$mass_percent%</b> by mass</td></tr>\n");
	print qq(</table>);
	# Graphical view of protein with sequences added by Ulas 11/9/98
	use GD;

	# Constants for width and height of image. Should eventually be moved to microchem_var.pl
	$seq_length = length($seq);
	$FONT = gdTinyFont;
	$WIDTH = 700;
	$space_on_left = ($FONT->width) * length("1") + 2;
	$space_on_right = ($FONT->width) * length("$seq_length") + 2;
	$seq_line_begin_x = $space_on_left;
	$seq_line_end_x = $WIDTH - $space_on_right;
	$seq_line_begin_y = 0;
	$seq_line_height = $FONT->height;
	$seq_line_end_y = $seq_line_begin_y + $seq_line_height;
	$matched_seq_line_begin_x = $space_on_left;
	$matched_seq_line_end_x = $WIDTH - $space_on_right;
	$matched_seq_line_begin_y = $seq_line_end_y;
	$matched_seq_line_height = $FONT->height;
	$matched_seq_line_end_y = $matched_seq_line_begin_y + $matched_seq_line_height;
	$seq_bar_begin_x = $space_on_left;
	$seq_bar_end_x = $WIDTH - $space_on_right;
	$seq_bar_begin_y = $matched_seq_line_end_y + $FONT->height/2;
	$seq_bar_height = 20;
	$seq_bar_end_y = $seq_bar_begin_y + $seq_bar_height;
	$HEIGHT = $seq_bar_end_y;

	# create a new image
	$im = new GD::Image($WIDTH,$HEIGHT);
	# allocate some colors
	$white = $im->colorAllocate(255,255,255);
	$black = $im->colorAllocate(0,0,0);
	$red = $im->colorAllocate(255,0,0);
	$blue = $im->colorAllocate(0,0,255);
	$yellow = $im->colorAllocate(255,255,0);
	# make the background transparent and interlaced
	$im->transparent($white);
	$im->interlaced('true');
	# Put a black frame to represent the sequence bar
	$im->rectangle($seq_bar_begin_x,$seq_bar_begin_y,$seq_bar_end_x-1,$seq_bar_end_y-1,$black);

	# Draw the delineated peptides within the sequence
	# IMPORTANT: Semantics of a vertical line
	# A vertical line points to the space (or cutting area) between two amino acids, NOT an amino acid itself.

	my $num_cut_spots = $seq_length + 1;
	foreach $pep (@{$peps}) {
		# second foreach loop eliminates buggy regions, mistakenly filled in, and handles multiple matches of one peptide in one frame
		@m = split (":", $starts{$pep});
		foreach $m (@m) {
			my $begin = $seq_bar_begin_x + (($m-1) / $num_cut_spots) * ($seq_bar_end_x-$seq_bar_begin_x);
			my $end = $seq_bar_begin_x + ((($m) + length ($pep)) / $num_cut_spots) * ($seq_bar_end_x-$seq_bar_begin_x);
			$im->filledRectangle($begin, $seq_bar_begin_y, $end-1, $seq_bar_end_y-1, $yellow);
			# Delineate it
			$im->rectangle($begin, $seq_bar_begin_y, $end-1, $seq_bar_end_y-1, $black);
	    }
	}

	# Draw the sequence line
	# The two numbers on the right and left
	# Number on left
	$num_width = $FONT->width * length("1");
	$num_height = $FONT->height;
	$num_begin_x = 0;
	$num_begin_y = (($seq_line_end_y+$seq_line_begin_y) - $num_height) / 2;
	$num_end_x = $num_begin_x + $num_width;
	$num_end_y = $num_begin_y + $num_height;
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
	# Now we draw a line for the portion of the sequence that contains matched aa's
	# First calculate the first point at which we have a matched aa

	my ($begin_array, $end_array);
	for($i = 0; $i < $seq_length; $i++) {
		if($matcharray[$i]) {
			# $i is the position of first
			$begin_array = $i;
			last;
		}
	}

	# Then, calculate the last point at which we have a matched aa
	for($i = $seq_length - 1; $i >= 0; $i--) {
		if($matcharray[$i]) {
			#$i is the position of the last aa
			$end_array = $i;
			last;
		}
	}

    $end_array++;   # We need the position of the one just following it

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

	# Convert the image to PNG and print it on standard output
	$now = &get_unique_timeID();
	# DJW
	# handles multiple images (more than one frame)
	if ($is_nucleo) { $now .= "_$frame"; }

	#output the image
	$pngfile = "$tempdir/$ourshortname" . "_$now.png";
	$webpngfile = "$webtempdir/$ourshortname" . "_$now.png";
	open (PNG, ">$webpngfile") || die ("Could not write to $webpngfile");
	binmode PNG;
	print PNG $im->png;
	close PNG;

	print "<br style=font-size:10><img height=$HEIGHT width=$WIDTH src = \"$webpngfile\"><br><br>";


	print qq(<nobr><tt class=small>);
	$len = length ($seq);
	for ($i = 0; $i < $len; $i++) {

		# put in a space after every ten, a <BR> after every 80:
		if (($i % 10 == 0) && ($i != 0)) {
			if ($i % 90 == 0) {
				print ("<br>");
			}
			print ("\n");
		}

		# if we start a matching area, put in the match HTML:
		print $matchHTML if ($matcharray[$i] && (($i == 0) || !$matcharray[$i - 1]) );
		if ($is_nucleo && (!$matcharray[$i] && (($i == 0) || !$matcharray[$i - 1]))) { print $MetHTML if ( substr ($seq, $i, 1) eq "M" || substr ($seq, $i, 1) eq "*" || substr ($seq, $i, 1) eq "X" ); }

		print substr ($seq, $i, 1); # print the AA

		if ($is_nucleo && (!$matcharray[$i] && (($i == 0) || !$matcharray[$i - 1]))) { print $MetHTMLend if ( substr ($seq, $i, 1) eq "M" || substr ($seq, $i, 1) eq "*" || substr ($seq, $i, 1) eq "X"); }

		# if we are leaving, put in the end of the match HTML:
		print $unmatchHTML if ($matcharray[$i] && !$matcharray[$i + 1]);
	}
	#
	print ("</tt><nobr><br>\n"); # we need to finish with a CR
	#onLoad=frame_selected($numbers{$frame})

	# End of PNG Image
    # skip normal button, sequence display.  display all seqs at end
    if ($is_nucleo) { print "</div>"; next; }

	# DJW changed the protein display to match that of nucleotide display.  following code is now obsolete (and short circuited), but will keep
	# just in case.
	else { &display_pos; print "</form>"; &print_flicka_to_muquest_form(); print $globalpepcutform; exit; }

	# Begin table of seqs
    my ($s) = "&nbsp;";

	# start of uselessness ---------------------------------------------------------------------------------------
	# Changed by Ulas to table to accomodate pepstat buttons
	print "\n<table border=0>\n";

	print "<tr><td>";
    print ($s x 2 , "<span class=smallheading>Position", $s x 13, "Sequence");
    print ("</span><br><tt>", "-" x 9,    $s x 2, "-" x 12, "</tt><br>");
	print "</td></tr>\n";
	print "<tr valign=top><td><tt>\n";

	my ($start, @starts);

	foreach $pep (@{$peps}) {
		$url = $remoteblast . "?" . join ("&amp;", "QUERY=$pep", "PROGRAM=blastp", "DATABASE=nr", $default_blast_options);

		if (!defined $starts{$pep}) {
			print ($s x 2, "???", $s x 5, qq(<a href="$url">$pep</a><br>\n));

		} else {
			@starts = split (":", $starts{$pep});
			$len = length ($pep);
			my ($first) = 1;

			foreach $start (@starts) {
				print (&precision ($start, 0, 4, $s), "-", &precision ($start + $len - 1, 0, 4, $s), $s x 2);
				if ($first) {
					print (qq(<a href="$url">$pep</a>));
					$first = 0;

				} else {
					print $pep;
				}

				$first = 0;
				print ("<br>\n");
			}
		}
	}

	# DJW--some of this html code is useless.
	print "</tt></td>\n";

	# Now print the row of pepstat buttons, links to their respective $pep's
	print "<td valign=top><tt>\n";
	foreach $pep (@{$peps}) {
		print <<EOM;
	$s<span class=actbuttonover style="width=55" onclick="window.location='$pepstat?peptide=$pep';">pepStat</span><br>
EOM
	}
	print "</tt></td>\n";

	# Changed by Ulas 11/19/98 to accomodate new sendto buttons and design
	print "<td valign=top align=right colspan=50>\n";

 	print ("</span>");

	print "</td></tr></table>\n";
}
# end of uselessness --------------------------------------------------------------

sub translate_seq {
	## prepare translation apparatus:
	##
	$transl_table = 1;
	$transl_name = &calculateTranslationTable($transl_table);

	my $ref = shift;
	my $frame = shift;

	my $myref = &parseentryid($ref);
	my @nuc = @{$seqs{$myref}};
	if ($nuc[0] =~ /^>/) {
		$fasta_hdr = $nuc[0];
		# strip fasta
		shift @nuc;
	}

	my $nuc = join "", @nuc;

	my $seq;
	($seq, $bestrun{$frame}, $bestknownrun{$frame}, $num_stops{$frame}, $num_unknowns{$frame}) = &translate ($nuc, $frame);
	$seq =~ s/<.*?>|\s//g;  # Strip HTML tags

	$bestrun{"best"} = &max ($bestrun{"best"}, $bestrun{$frame});
	$bestknownrun{"best"} = &max ($bestknownrun{"best"}, $bestknownrun{$frame});
	$num_stops{"best"} = &min ($num_stops{"best"}, $num_stops{$frame});
	$num_unknowns{"best"} = &min ($num_unknowns{"best"}, $num_unknowns{$frame});


	return $seq;
}

sub display_pos {
	my ($s) = "&nbsp;";
	if ($FORM{"CheckedBox"} eq "position") {
		$checkedpos = "checked";
	}
	elsif ($FORM{"CheckedBox"} eq "sequence"){
		$checkedseq = "checked";
	}
	print qq(<br><table border=0 cellpadding=0 cellspacing=0 width=500><tr><td class=smallheading>Sort by:</td>);
	print qq(<td class=smallheading>Sequence<input type=checkbox name="sequence" onClick=sorting(0) $checkedseq></td>);
	print qq(<td class=smallheading>Position<input type=checkbox name="position" onClick=sorting(1) $checkedpos></td>);
  print <<EOF;
<input type="hidden" name="MassType" value="$masstype">
<input type="hidden" name="Db" value="$db">
<input type="hidden" name="Ref" value="$references">
<input type="hidden" name="NucDb" value="$is_nucleo">
<input type="hidden" name="Pep" value="$ps">
<input type="hidden" name="Dir" value="$dir">
<input type="hidden" name="CheckedBox">
<input type="hidden" name="Sort">
EOF
	if ($is_nucleo) {
		print qq(<td class=smallheading>Frame</td></tr>);
	} else { print "</tr>"; }

	print qq(<tr><td style=font-size:3>&nbsp;</td></tr>);
	# sorts by peptide or position (or frame, if applicable)
	if ($sort eq "p-pos") {
		@{peps} = sort {$huh{$a} <=> $huh{$b}} (keys %huh);
	} elsif ($sort eq "p-pep") {
		@{peps} = sort @{peps};
	} elsif ($sort eq "n-pos") {
		#@{peps} = sort {keys %{$table{$a}} <=> keys %{$table{$b}}} (keys %table);
	} elsif ($sort eq "n-pep") {
		@{peps} = sort @{peps};
	} elsif ($sort eq "n-frame") {
	} else {
		#default: sort by peptide.
		@{peps} = sort @{peps};
	}

	# @{peps};
	foreach $pep (@{peps}) {
		$len = length ($pep);
		print "<tr height=18>";
		print "<td align=left>";
		$url = $remoteblast . "?" . join ("&amp;", "QUERY=$pep", "PROGRAM=tblastn", "DATABASE=dbest", $default_blast_options);

		# print pepstat button
		print <<EOM;
<span class=actbuttonover style="width=55" onclick="window.location='$pepstat?peptide=$pep';" onLoad="checksort()">PepStat</span>
EOM
		my $peplink = &create_link(text=>$pep, link=>$url, class=>smalltext);
		print qq(<td>$peplink</td>);
		print qq(<td>);
		if ($is_nucleo) {
			foreach $frame (@frms) {
				my ($first) = 1;
				unless ($table{$pep}{$frame}) { next; }
				@f = split (":", $table{$pep}{$frame});
				foreach $st (@f) {
		    	    $end = $st + $len - 1;
					print "<span class=smalltext>&nbsp;";
					print (&precision ($st, 0, 4, $s), $s, "-", &precision ($end, 0, 4, $s));
					print "</span></td>";
					#print "<tt>&nbsp;$fm - $end</tt>";
					if ($first) { print (qq(<td class=smalltext>), $s x 2, qq($frame</td>)); $first = 0; }
					print "</tr>";
				}
			}
		} else {
			@stt = split (":", $huh{$pep});
			foreach $stt (@stt) {
				$end = $stt + $len - 1;
				print "<span class=smalltext>";
				print (&precision ($stt, 0, 4, $s), $s, "-", &precision ($end, 0, 4, $s));
				print "</span>";
				#print "<tt>&nbsp;$stt-$end</tt>";
				print "</tr>";
            }
		}
	}
	print "</table>";
}

sub print_buttons {
	my $formvalue = shift;
	$ncbi_type = "p";
    $type = 1;
	$temp = $ref;
	my $dir_query = "&Dir=$FORM{'Dir'}" if (defined $FORM{'Dir'});
	my $frame_query = "";
	my $frame1_query = "";
	# n: translated protein sequence
    if ($is_nucleo) {
		$ncbi_type = "n";
		$frame_query = "&frame=$frame";
		$frame1_query = "&frame1=$frame";
	}

	$ref =~ s/\*//g;
	# DJW moved sendto buttons 7/22.
	$searchstrings = $FORM{"Pep"};
    #$searchstrings =~ tr/ /\+/; # Commented out when this was moved to a form instead of a URL
    $globalpepcutform.=<<EOM;
	<form name=pepcutform$formvalue action="$pepcut" method=post>
	<input type="hidden" name="mode" value="backlink_run">
	<input type="hidden" name="type_of_query" value="$type">
	<input type="hidden" name="database" value="$db">
	<input type="hidden" name="query" value="$ref">
	<input type="hidden" name="searchseq" value="$searchstrings">
	<input type="hidden" name="frame" value="$frame">
	<input type="hidden" name="Dir" value="$FORM{'Dir'}">
	<input type="hidden" name="MassType" value="$FORM{'MassType'}">
	<input type="hidden" name="disp_sequence" value="yes">
	</form>
EOM
	print <<EOM;
	<tr height=30><td class=title>&nbsp;&nbsp;Send To:&nbsp;</td>
		<td colspan=4 class=smalltext>&nbsp;<span class=actbuttonover style="width=55" onclick="document.pepcutform$formvalue.submit()">PepCut</span>
EOM
	# print link to pepstat
	print <<EOM;
	<span class=actbuttonover style="width=55" onclick="window.location='$pepstat?type_of_query=$type&database=$db&peptide=$ref$frame_query$dir_query&running=1';">PepStat</span>
EOM

	# print link to GAP
	print <<EOM;
	<span class=actbuttonover style='width=55' onclick="window.location='$gap?type_of_query1=$type&database1=$db&peptide1=$ref$frame1_query$dir_query';">Gap</span>
    <!--<form action="$remoteblast" name=blast method=post>-->
	<span class='actbuttonover' style='width=55' onClick="document.forms['muquest_form'].submit()">MuQuest</span>
EOM


	$ref = $temp;

	# if reference is from ncbi then show links to Entrez
	if ($ref =~/gi\|/) {

		$ref =~ /^gi\|(\d*)/;
		my $myref = $1;

		print <<EOM;
		&nbsp;&nbsp;&nbsp;
		<span class=actbuttonover style='width=58' onclick="window.location='http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=f';">Sequence</span>
		<span class=actbuttonover style='width=55' onclick="window.location='http://www.ncbi.nlm.nih.gov/htbin-post/Entrez/query?uid=$myref&form=6&db=$ncbi_type&Dopt=m';">Abstract</span>
EOM

		#print blast link
		$d = $db;
		$d =~ s!\.fasta!!;

		$ncbi = "$remoteblast?$sequence_param=$n&";

		if (($d =~ m!dbEST!i) || ($d eq "est")) { $ncbi .= "$db_prg_aa_nuc_dbest"; }
		elsif ($d eq "nt") { $ncbi .= "$db_prg_aa_nuc_nr"; }
		elsif ($d =~ m!yeast!i) { $ncbi .= "$db_prg_aa_aa_yeast"; }
		else { $ncbi .= "$db_prg_aa_aa_nr"; }

		$ncbi.= ($ncbi_type eq "p") ? "&$word_size_aa" : "&$word_size_nuc" if (defined $ncbi_type);

		$ncbi .= "&$expect&$defaultblastoptions";

		print qq(<span class=actbuttonover style='width=55' onclick="window.location='$ncbi';">Blast</span>);

	}

	print "</td></tr>";

}

#added by Georgi for displaying source sample info variables for sample info
sub print_sample_info
{
	print qq(<table cellpadding=0 cellspacing=0 border=0 width=710 style="border:solid #e4e4e4 1px">);
	$database = $2 if $db =~ m/^(.*?\/)+(.*)$/;
	if (defined $FORM{'Dir'})
	{
		my %dir_info = &get_dir_attribs($FORM{'Dir'});

		print <<INFO;
	<tr height=20>
		<td class=title width=75 nowrap>&nbspReference:&nbsp;</td>
		<td class=smalltext colspan=2  width=185 nowrap>&nbsp;$ref</td>
		<td class=title width=70 nowrap>Sample:&nbsp;</td>
		<td class=smalltext  width=380 nowrap>&nbsp;$dir_info{'LastName'},&nbsp;$dir_info{'Initial'}.&nbsp;&nbsp;$dir_info{'Sample'}&nbsp;&nbsp;$dir_info{'SampleID'}&nbsp;&nbsp;</td></tr>

	<tr height=20>
		<td class=title width=75 nowrap>&nbsp;Database:&nbsp;</td>
		<td class=smalltext colspan=2 width=185 nowrap>&nbsp;$database</td>
		<td class=title width=70 nowrap>&nbsp&nbsp;Directory:&nbsp;</td>
		<td class=smalltext  width=380 nowrap>&nbsp;$FORM{'Dir'}</td></tr>
INFO
	if ($is_nucleo) {

		print qq(<tr height=22><td class=title width=75>Frames:&nbsp;</td>);
		# there must be an easier way...

		print qq(<td colspan=4 class=smalltext><input type=checkbox name="default" onClick="defaulting(0)");
		if (!$FORM{"Frames"}) { print qq(checked>Default &nbsp); } else { print qq(>Default &nbsp); }
		print qq(<input type=checkbox name="ALL" onClick="frame_all_selected(this)");
		if ($FORM{"Frames"} eq "ALL") { print  qq(checked>All &nbsp); } else { print qq(>All &nbsp); }

		print qq(<input type=checkbox name="checkbox1" onClick="frame_selected(this, 1)" );
		if ($FORM{"Frames"} =~ /1/ || $FORM{"Frames"} eq "ALL") { print qq(checked>+1 &nbsp); } else { print qq(>+1 &nbsp); }
		print qq(<input type=checkbox name="checkbox2" onClick="frame_selected(this, 2)" );
		if ($FORM{"Frames"} =~ /2/ || $FORM{"Frames"} eq "ALL") { print qq(checked>+2 &nbsp); } else { print qq(>+2 &nbsp); }
		print qq(<input type=checkbox name="checkbox3" onClick="frame_selected(this, 3)" );
		if ($FORM{"Frames"} =~ /3/ || $FORM{"Frames"} eq "ALL") { print qq(checked>+3 &nbsp); } else { print qq(>+3 &nbsp); }
		print qq(<input type=checkbox name="checkbox4" onClick="frame_selected(this, 4)" );
		if ($FORM{"Frames"} =~ /4/ || $FORM{"Frames"} eq "ALL") { print qq(checked>-1 &nbsp); } else { print qq(>-1 &nbsp); }
		print qq(<input type=checkbox name="checkbox5" onClick="frame_selected(this, 5)" );
		if ($FORM{"Frames"} =~ /5/ || $FORM{"Frames"} eq "ALL") { print qq(checked>-2 &nbsp); } else { print qq(>-2 &nbsp); }
		print qq(<input type=checkbox name="checkbox6" onClick="frame_selected(this,6)" );
		if ($FORM{"Frames"} =~ /6/ || $FORM{"Frames"} eq "ALL") { print qq(checked>-3 &nbsp); } else { print qq(>-3 &nbsp); }
		print qq(</td></tr></table>);
	}
	}
}


sub print_header {
	# ?
	$frames_for_url .= $numbers{$frame};

	## SDR: Added as a kludge to prevent the Chris Martin reference header from coming up 01/12/18
	if ($fasta_hdr =~ m!^>gi\|5986\|emb\|Z14321\.1\|Z14321 CEL11A10 Chris Martin!) {
		print qq(Invalid header<BR><BR>);
		return;
	}

	if ($fasta_hdr =~ m!^>\Q$ref\E(\S*\s)(.*)!i) {
		#    if ($is_nucleo) { print qq(<span class=smallheading><b>Frame $frame:&nbsp;&nbsp;</b></span>); }
		print qq(<tr><td valign=top class=title width=75>Header:&nbsp;</td><td class=data colspan=4 width=635>&nbsp;$ref$1$2</td></tr>\n);
	} else {
        print ("<tr><td valign=top class=title width=75>Header:&nbsp;</td><td class=data colspan=4 width=635>", &HTML_encode ($fasta_hdr), "</td></tr>\n");
	}
	print qq(<tr><td style=font-size:2 class=title>&nbsp;</td><td style=font-size:2 colspan=4>&nbsp;</td></tr>);

}

sub print_orf {
	$sep = "&nbsp;" x 10;
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

	print qq(<tr height=20><td class=title width=75>Frame:&nbsp;</td><td class=smalltext colspan=4 width=665>&nbsp;$frame$sep);
	print qq($h1&nbsp;&nbsp;$t1$sep);
	print qq($h2&nbsp;&nbsp;$t2$sep);
	print qq($h3</span>&nbsp;&nbsp;$t3$sep);
	print qq($h4</span>&nbsp;&nbsp;$t4$sep);
}

sub javascript {
	print <<EOF;
<script language="Javascript">

	<!--

	function frame_all_selected (checkbox) {
		var frames = new Array ("framespan1", "framespan2", "framespan3",
								"framespan4", "framespan5", "framespan6");

		var index;
		var box;

		if (checkbox.checked == false) {
			defaulting();
			return;
		}
		for (index = 0; index < frames.length; index++) {
			document.all[frames[index]].style.display = "";

			box = "checkbox" + (index + 1);
			document.all[box].checked = true;
		}
		document.all["default"].checked = false;
	}

	// Returns 1 if no checkboxes are selected, 0 otherwise
	function all_empty () {
		var index;
		var frames = new Array ("framespan1", "framespan2", "framespan3",
								"framespan4", "framespan5", "framespan6");
		var box;

		for (index = 0; index < frames.length; index++) {
			box = "checkbox" + (index + 1);
			if (document.all[box].checked == true)
				return 0;
		}
		return 1;
	}


	function frame_selected (check, value) {
		var span = "framespan";

		if (all_empty()) {
			defaulting();
			return;
		}

		span += value;
		if (check.checked == true) {
			document.all[span].style.display = "";
		} else {
			document.all[span].style.display = "none";
		}
		document.all["ALL"].checked = false;
		document.all["default"].checked = false;
	}

	function defaulting() {
		var index;

		var checkbox;
		var framespan;
		var defaultvalue;

		for (index = 1; index <= 6; index++) {
			checkbox = "checkbox" + index;
			framespan = "framespan" + index;
			document.all[checkbox].checked = document.all[checkbox].initial;
			if (document.all[checkbox].initial == false) {
				document.all[framespan].style.display = "none";
			} else {
				document.all[framespan].style.display = "";
			}
		}
		document.all["default"].checked = true;
		document.all["ALL"].checked = false;
	}

	// how do you change url without updating it?
	// not used
	function add_frames_to_url(frames) {
		var new_url = location.href;
		var re = /Frames/;
		if (re.test(new_url)) {
			return;
		} else {
			new_url += "&Frames=";
			new_url += frames;
			location.href = new_url;
		}
	}


	function sorting(type) {
		var sort_type = type;
		var is_nucleo = "$is_nucleo";

		if (is_nucleo) { var kind = "n"; } else { var kind = "p"; }

		if (!sort_type) {
			document.flicka.CheckedBox.value = "sequence";
			kind += "-pep";
		} else {
			if (is_nucleo) { return; }
			document.flicka.CheckedBox.value = "position";
			kind += "-pos";
		}
		document.flicka.Sort.value=kind;
		document.flicka.submit();
	}

	function checksort() {
		var re1 = /pep/;
		var re2 = /pos/;

		if (re1.test(location.href)) {
			document.forms[0].elements["sequence"].checked = true;
		} else if (re2.test(location.href)) {
			document.forms[0].elements["position"].checked = true;
		}
	}
	//-->
</script>
EOF

}
