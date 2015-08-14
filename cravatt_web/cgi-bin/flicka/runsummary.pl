#!/usr/local/bin/perl

#-------------------------------------
#	Run Summary,
#	(C)1997-2001 Harvard University
#	
#	W.S.Lane/M. A. Baker
#       C.M. Wendl/T. Kim
#		Tim Vasil
#	v3.1a
#	
#	Licensed to Finnigan
#
#	Based on Original Concept by J.Yates/J.Eng	
#
#-------------------------------------


################################################
# find and read in standard include file
{
	$0 =~ m!(.*)\\([^\\]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, $path);
	#unshift (@INC, $path . '/runsummary');  # getting rid of etc/runsummary/ directory
	require "microchem_include.pl";
	require "html_include.pl";
}
################################################

require "fastaidx_lib.pl";
require "fasta_include.pl";
require "goodbadugly_include.pl";

$progname = "Sequest Summary";

# variables for table:
$table_heading_color = "bgcolor=#e8e8fa";  # dark: #c0c0c0
$table_contents_color = "bgcolor=#f2f2f2";
$table_heading_align = "align=right";
$table_horz_spacing = "20";
$table_horz_spacing2 = "340";
$table_vert_spacing = "19";
$dropbox_style = "style=\"font-family:verdana; font-size:9\"";

# variables for buttons:
$button_table_border="bordercolorlight=#f2f2f2 bordercolordark=#999999";   #options: "bordercolor=#999999"
$button_table_height=18;
$button_background_color = "#0099cc";
$button_font_color = "#ffffff";
$button_selected_font_color = "#000000";
$button_selected_background_color = "#e8e8fa";
$button_mouseover_background_color = "#e8e8fa";
$button_mouseover_font_color = "#000000";
$filter_background_color = "#cc0000";
$go_button_color = "#ffff00";

# other variables:
$pull_to_top_manual = 1;  # set -1 to function as normal, 0 to turn off, 1 to turn on
							# note: to make it function as normal, the checkbox needs to be added to the output pages again

$popupmenudelay = 150;  # in milliseconds
$popupmenucolor = "#e8e8fa";
$popupmenuselectedcolor = "#0099cc";
$popupfontcolor = "#000000";
$popupfontselectedcolor = "#ffffff";

$deemphasized_grey = "#666666";
$emphasized_purple = "#800080";

#$SF_BOLD_IF_GREATER_THAN = .6;   # bold the mean and median SF values if they are >= this value
#$NUMFILES_GREATER_THAN = 2;      # bold the number of files if it is >= this value

%colorsandvalues = ();
%outs_js = ();
%hidden_outs_js = ();

# We don't believe that there are any scores until we see one.
$reallynocombinedscores = 1;

# we rather explicitly do want the page to be cached, so we can navigate away and
# retain checkbox states
$docache = <<EOF;
<META HTTP-EQUIV="Expires" CONTENT="Wed, 26 Feb 2020 08:21:57 GMT">
EOF

# number of no-consensus outfiles that get descriptor lines in output
$NUMDESCRIPS = 30;

## threshold values for some of the columns displayed:
$XCORR_THRESH = $DEFS_RUNSUMMARY{"XCorr threshold"};           # lower bound for bolding
$DELTACN_THRESH = $DEFS_RUNSUMMARY{"DeltaCN threshold"};         # lower bound for bolding
$SP_THRESH = $DEFS_RUNSUMMARY{"Sp threshold"};              # lower bound for bolding
$RSP_THRESH = $DEFS_RUNSUMMARY{"RSp threshold"};               # UPPER bound for bolding
$SC_THRESH = $DEFS_RUNSUMMARY{"Sf threshold"};			   # lower bound for bolding
$SF_BOLD_IF_GREATER_THAN = $DEFS_RUNSUMMARY{"Consensus SF bold threshold"};		# bold the SF values in consensus titles if >= this value

$DEF_IMG_ALIGN = "TOP";	 # default alignment for images

# must be in "#AABBCC" form:
@rank_colour = ("#E00020", "#009CBC", "#008243", "#FFFF00", "#C87800", "#800000", "#000080", 
			"#800080", "#C0C0C0", "#8C1717");
# cmw 27.9.98: a very crude way to create 42 new colors automatically (and none of them too bright)
$colournum = 100000;
for ($i = $#rank_colour + 1; $i < 252; $i++) {
	$rank_colour[$i] = "#$colournum";
	$colournum += 16667;
}

$num_ranks_to_colour = $#rank_colour + 1;

# letters for labeling consensi
$consensi_letterstr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

$MAX_NUM_CONSENSI = length ($consensi_letterstr);

# charge stat colors: dark blue for +1, dark green for +2, dark red for higher
@zcolors = qw(#000080 #008000 #640000);

$use_buttonmaker = 0; # if 1, we dynamically create the images for sorting buttons
                      # if 0, we link to images in the $webimagedir directory

##
## a note on the internals:
##
## Some associative arrays, like %selected, are indexed by the truncated
## file name. Most of the linear arrays are indexed by the index of the
## file in @outs. This is given by $number{<truncated filename>}
##
## Most of the associative arrays have an entry for each poss. peptide
## hit in each .out file. These are indexed by "a:b", where a is the
## index of the file in @outs, and b is the rank of the hit in the .out.
##
## thus, the most significant hit from $file has its deltaCn value
## in $deltaCn{ "$number{$file}:1" }
##

##
## some of the assoc arrays:
## $number{$file} is the number given to the file named "$file". $file is
##                is the name of the file, minus the ".out" suffix.
## $outs[$i]      is the file name for the file number $i, so %number and @outs are inverse
##
## $level_in_file{"$i:$ref"} is the highest ranking, within a .out file, of the
##                reference "$ref" in the file with file number $i.
## $ref_long_form{$ref} is the longest reference whose shortened version is $ref


# the points given to each member of each category:
@scorearr = (10, 8, 6, 4, 2, 1);

# colours with which to colour the scoring categories:
@scorecolours = ("#FF0000", "#0000FF", "#C87800", "#008000", "#FF00FF", "#000000");

# the number of separate scoring categories we keep
# if this is 6, we have categories for 1st, 2nd, 3rd, 4th, and 5th hits, and one for all others
$numscores = $#scorearr + 1;

# the minimum size (in bytes) of the databases that are printed in consensus form
$DB_BREAK_VAL = 2500;

&cgi_receive();

# added by cmw, 9/18/99: parameter to make loading of DTA VCR-related code conditional (for the sake of speed)
if (defined $FORM{"load_dta_vcr"}) {
  $load_dta_vcr = $FORM{"load_dta_vcr"}
} else {
  $load_dta_vcr = 1;   # make true by default
}

# added by cmw, 4/30/99
$dir = $FORM{"directory"};
$checkbox_state = "$seqdir/$dir/checkbox_state.txt";
if ($FORM{"save_state"}) {
	&save_checkbox_state($checkbox_state);
	&no_content;
	exit;
}

## I don't think this code does anything: ##
#$expstate = $FORM{"expandstate"};
#if ($expstate) {
#	my ($expandID, $expandstate) = split /val/, $expstate;
#	&save_expand_state($expandID, $expandstate);
#}
#
## want to save state of tree expansion
#sub save_expand_state {
#	my $expandID = shift;
#	my $expandstate = shift;
#	open(EXPAND, ">$tempdir/expand_state_file$expandID");
#		print $expandstate;		
#	close EXPAND;
#}
## load tree expansion state



sub save_checkbox_state {
	my $checkbox_state_file = shift;
	my @dtas = sort {$a cmp $b} split /,\s*/, $FORM{"selected"};
	open(STATEFILE, ">$checkbox_state_file");
	foreach (@dtas) {
		print STATEFILE "$_.dta\n";
	}
	close STATEFILE;
}

# load checkbox state if such a file exists (and has nonzero size)
# enhanced by cmw (1/16/00) to accomodate Bericht checkbox states as well
opendir(DIR, "$seqdir/$dir");
@cb_statefiles = grep /^checkbox_state/, readdir(DIR);
closedir DIR;
foreach $checkbox_state_file (@cb_statefiles) {

	open(STATEFILE, "<$seqdir/$dir/$checkbox_state_file");
	@files = <STATEFILE>;
	close STATEFILE;
	foreach (@files) {
		chomp;
		s/\.dta$//;
	}

	if ($checkbox_state_file =~ /bericht_(.*)\.txt/) {
		($berichtdate = $1) =~ s/\-/_/g;
		$checked_dtas_bericht{$berichtdate} = [ ];
		@{$checked_dtas_bericht{$berichtdate}} = sort {$a cmp $b} @files;
	} else {
		@checked_dtas = sort {$a cmp $b} @files;
	}
}


## added by dmitry 990925 (dls)
# load selected_dtas for checkbox state if such a file exists (and has nonzero size)
$selected_dtas = "selected_dtas.txt";
if (-s "$seqdir/$dir/$selected_dtas") {
	open(SELFILE, "<$seqdir/$dir/$selected_dtas");
	@selected_dtas = <SELFILE>;
	close SELFILE;
	foreach (@selected_dtas) {
		chomp;
		s/\.dta$//;
	}
	@selected_dtas = sort {$a cmp $b} @selected_dtas;
}
## end (990925)

$directory = $FORM{"directory"};

if ($FORM{"execute.x"} && ($FORM{"DTA_action"} eq "report")) {
  $do_report = 1;

  # prevent output to screen for Folgesuchebericht
  select(NULL);
} elsif ($FORM{"execute.x"} && ($FORM{"DTA_action"} eq "xmlreport")) {
  $do_xml_report = 1;
  select(NULL);
}

$is_image = $FORM{"image"} || (defined $FORM{"image.x"}) || $FORM{"sort"} =~ m!chrom!i;

$score_threshold = defined $FORM{"score_threshold"} ? $FORM{"score_threshold"} : $DEFS_RUNSUMMARY{"Consensus group score threshold"}; # <= this (sf) score, group not displayed
$consensus_view_mode = defined $FORM{"consensus_view_mode"} ? $FORM{"consensus_view_mode"} : $DEFS_RUNSUMMARY{"Consensus group view mode"};
$consensus_filter_mode = defined $FORM{"consensus_filter_mode"} ? $FORM{"consensus_filter_mode"} : $DEFS_RUNSUMMARY{"Filter consensus groups using thresholds"};
$NUMFILES_GREATER_THAN = defined $FORM{"sequences_threshold"} ? $FORM{"sequences_threshold"} : $DEFS_RUNSUMMARY{"Number of sequences bold threshold"};	# bold the number of files if it is >= this value

$consensus_filter_mode =~ s/yes/on/ unless ($consense_filter_mode =~ s/no/off/);

if ($is_image) {
  &MS_pages_header("Consensus Chromatogram", 0, "heading=" . <<EOM , $docache );
<span style="color:#0080C0">Consensus</span> <span style="color:#0000FF">Chromatogram</span>
EOM
} else {
  if (!defined $directory) {
	$docache = $nocache;
    &normal_header("Cache-Control: no-cache");
  } else {
    &small_header();
  }
}

if (!defined $directory) {
  &output_form();
  print qq(</body></html>);
  exit;
}

if (defined $FORM{"wait_for_sf"}) {				#11/13/01
	&wait_for_sf;
}



chdir "$seqdir/$directory" || &chdir_error("$seqdir/$directory");

$pull_to_top = 1;
## make the pull to top button work correctly
if ($FORM{"PULL_TO_TOP.x"}) {
  $pull_to_top = 1;
  $FORM{"sort"} = $FORM{"prevsort"} if $FORM{"prevsort"}; # keep the sorting behavior (if defined)
}
$pull_to_top = 1 if ($FORM{"PULL_TO_TOP"});

if ($FORM{"PULL_TO_TOP_OFF.x"}) {
  $pull_to_top = 0;
  $FORM{"sort"} = $FORM{"prevsort"}; # keep the sorting behavior
}
$pull_to_top = ($pull_to_top_manual = -1) ? $pull_to_top : $pull_to_top_manual; 


if ($FORM{"BP_mode"} ne $FORM{"prev_BP_mode"}) {
	$FORM{"sort"} = $FORM{"prevsort"};	# keep sorting behavior
	if (grep /^$FORM{"sort"}$/, ("maxbp","fbp","zbp","tic")) {
		$FORM{"sort"} = $FORM{"BP_mode"};
	}
}
$notnew = $FORM{"notnew"};

$MAX_RANK = (defined $FORM{"max_rank"}) ? $FORM{"max_rank"} : $DEFS_RUNSUMMARY{"Max rank"};
$MAX_LIST = (defined $FORM{"max_list"}) ? $FORM{"max_list"} : $DEFS_RUNSUMMARY{"Max list"};

#make this better
$new_algo = $FORM{"new_algorithm"} || !$notnew;
$new_algo = ($new_algo) ? 1 : 0;

##
## $boxtype is "HIDDEN" or "CHECKBOX", and specifies whether the selection
## checkboxes are shown. By default, they are HIDDEN, but we have a pushbutton
## that toggles that status.

if ($notnew) {
  foreach $f (split (", ", $FORM{"selected"})) {
    $selected{$f} = "CHECKED";
  }
  $boxtype = $FORM{"boxtype"};
}

## check if the toggle pushbutton has been pressed:
if ((defined $FORM{"clone_HIDDEN.x"}) || (defined $FORM{"clone_CHECKBOX.x"})) {
  $boxtype = ($boxtype eq "HIDDEN") ? "CHECKBOX" : "HIDDEN";
  $FORM{"sort"} = $FORM{"prevsort"}; # keep the sorting behavior
}

opendir (DIR, ".");
@outs = grep { (! -z ) && s!\.out$!!i } readdir(DIR);
closedir DIR;

# make a global hash of good,bad,ugly scores, indexed by dta filename
@dtas = map { $_ . ".dta" } @outs;
open GBUFILE, "$seqdir/$dir/goodbadugly.txt" or $NO_GBU_FILE = 1;
my($gbukey,$gbuvalue,$gbucolor,$gburating,$score);
while( <GBUFILE>){
		($gbukey,$gbuvalue) = split / /;
		$gbuvalue =~ s/\s//;			#chop off any whitespace
		$gbuscores{$gbukey} = $gbuvalue;
}
close GBUFILE;


# do the same for probabilities
&readSigcalcFile();


# ... and also combined scores....
# (edward 10/8/01)
open SCOREFILE, "$seqdir/$dir/seq_score_combiner.txt";
my($scorekey,$value1,$value2);
while( <SCOREFILE>){
		($scorekey,$value1,$value2) = split / /;
		$scorevalue =~ s/\s//;			#chop off any whitespace
		$combinedscores{$scorekey} =  ($value1 + $value2) ? $value2 / ($value1 + $value2) : 0;
}
close SCOREFILE;


@ionquest_base_names = ();
%ionquest_pairs = ();
open (IONQUESTLOG, "<./$ionquestlog");
# First 2 lines give directory information
$line = <IONQUESTLOG>;
($ionquest_dir) = ($line =~ /Sample Dir:\s*(\S+)\s*$/);
$line = <IONQUESTLOG>;
($ionquest_refdir) = ($line =~ /Ref Dir:\s*(\S+)\s*$/);
while ($line = <IONQUESTLOG>) {
	# Added to give ionquest up/down arrows depending on if the dta has a higher/lower intensity than the ref dta.
	my ($ionquest_dta, $ionquest_refdta, $intendta, $intenrefdta) = split /\s+/, $line;
	$ionquest_pairs{$ionquest_dta} = $ionquest_refdta;

	# Maintain compatibility with ionquest not run with ShowIntensity=1, else do it with it.
	my $marker;
	if ($intendta == 0) {
		$marker = "i";
	} else {
		if ($intendta > $intenrefdta) {
			$marker = "<img border=0 src=\"$webimagedir/summaryuparrow.gif\">";
		} else {
			$marker = "<img border=0 src=\"$webimagedir/summarydownarrow.gif\">";
		}
	}
	$ionquest_pairs_reference{$ionquest_dta} = $marker;

	$ionquest_dta =~ s/\.dta//;
	push @ionquest_base_names, $ionquest_dta;
}
close IONQUESTLOG;

# make all selected if this is the first time around:
if (!$notnew) {
  foreach $f (@outs) {
    $selected{$f} = "CHECKED";
  }
  $boxtype = "HIDDEN";
}

$boxtype = "CHECKBOX";   # turn checkboxes on permanently - 2/26/02

# this is the value displayed on the toggle pushbutton
$toggle = ($boxtype eq "HIDDEN") ? "Show" : "Hide";

chdir "$seqdir/$dir" or print "Cannot change CWD to $seqdir/$dir!!!\n";
 
opendir (DIR, ".") or print "Cannot open $dir!!!\n";
@current_outs = grep { (! -z ) && s!\.out$!!i && ($current_mtime{$_}=(stat("$_.out"))[9])} readdir(DIR);
closedir DIR;
	

if (-e "$RUNSUMMARY_DATA_CACHE_FILE") {
	if ($FORM{"clearcache"}) {
		&process_outfiles;
	} elsif (&update_dumpfile == 0) {
		&load_data;
	}
} else {
		&process_outfiles;
}

&do_execution() if ($FORM{"execute.x"}) && !&UserSelectedCancel();

&read_profile();

&read_seqparams();

# the following analyzes data but does not print anything; &print_consensi
# does that.
&group_and_score();

if ($is_image) {
  require "runsummary_javascript.pl";
  print qq(<script language="JavaScript" src="$webjsdir/runsummary.js"></script>\n);
  print qq(<INPUT TYPE=HIDDEN NAME="execute.x" VALUE="">\n);
  print <<EOF;
<script language="JavaScript">
popupfontselectedcolor="$popupfontselectedcolor";
popupmenuselectedcolor='$popupmenuselectedcolor';
popupmenudelay='$popupmenudelay';
</script>
<div style="position:absolute; left:100; top:100; visibility:hidden;" id="RefMenu" onmouseout="HideChoices('RefMenu', event.x, event.y);">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=4></td><td>
<table cellspacing=0 cellpadding=0 border=1>
<tr><td id="RefMenu_default" style="cursor:hand; color:#ffffff" width=70 align=left class=smallheading onclick="refGoTo('Retrieve');" bgcolor="$popupmenuselectedcolor" onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor';" onmouseout="this.bgColor='$popupmenucolor'; this.style.color='$popupfontcolor';">&nbsp;Flicka&nbsp;</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="refGoTo('Sequence');" bgcolor="$popupmenucolor" onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor'; document.all('RefMenu_default').bgColor='$popupmenucolor'; document.all('RefMenu_default').style.color='$popupfontcolor';" onmouseout="this.bgColor='$popupmenucolor'; this.style.color='$popupfontcolor';">&nbsp;Sequence&nbsp;</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="refGoTo('Abstract');" bgcolor="$popupmenucolor" onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor'; document.all('RefMenu_default').bgColor='$popupmenucolor'; document.all('RefMenu_default').style.color='$popupfontcolor';" onmouseout="this.bgColor='$popupmenucolor'; this.style.color='$popupfontcolor';">&nbsp;Abstract&nbsp;</td></tr>
</table></td></tr></table></div>
EOF

  &output_image();
#  &closeidx();
  print qq(<div align=right><span style="color:#63968e" class="smalltext"><i>);
  &GD_notice();
  print qq(</i></span></div>);
  exit 0;
}

if (!&openidx("$dbdir/$database[0]")) {
	$dbavail=0;
} else {
	$dbavail=1;
	$IsNucleotideDb = &IsNucleotideDb("$dbdir/$database[0]");
}

if ($do_report) {
	$operator = $FORM{"operator"};
	$operator =~ tr/A-Z/a-z/;
	&print_bericht();
	exit ();
} elsif ($do_xml_report) {
	$operator = $FORM{"operator"};
	$operator =~ tr/A-Z/a-z/;
	&print_xml();
	exit ();
}

if (!$notnew) {
	$dbsize = -s "$dbdir/$database[0]";
	if (($dbsize < $DB_BREAK_VAL) && ($FORM{"sort"} eq "consensus") && ("$database[0]" ne "est.fasta") && ("$database[0]" ne "est.fasta.bin")) {
		$FORM{"sort"} = "xc";
		$MAX_RANK = 1;
	}
}

@orderedouts = &do_sort_outs (@outs);

$reflen = 10; # the maximum length of the reference field

## calculate reflen so that all references have enough space:
##
foreach $file (@orderedouts) {
  $i = $number{$file};
  $index = "$i:1";
  my $len;
  if ($is_cons_sort) {
	my $rank = $ranking[$i];
	if (defined $rank) {
		$len = length($consensus_groupings[ $rank ]);
	} 
	else {
		$len = length($ref{$index});
	}
  }
  else {
	$len = length ($ref{$index});
  }
  if (defined $ref_more{$index}) {
    $len += length ($ref_more{$index}) + 1;
  }
  $reflen = $len if ($len > $reflen);
}


## These two forms are now opened later in the html (just before "Intensity: ...") to eliminate the leading space that they create
## when no visible elements are in them.
### Added 9/1/00 by P. McDonald
##&print_clonest_form();
### the following does the normal print routine:
##&open_main_form();


# for more space between header and page content:
print "<table border=0 cellspacing=0 cellpadding=0><tr><td width=10 height=7></td></tr></table>";



# changed by cmw, 11/15/98
# &print_simple_info ("Dir", "Files", "Db", "Mass", "Enzyme");

  if ($boxtype ne "HIDDEN") {
	# new filtering controls added by cmw (2/13/00)
	$use_filter = $FORM{"use_filter"};
	$filter_action = $FORM{"filter_action"};
	$filterandor = ($FORM{"filterandor"} || "or");	# "or" by default
	$filterstring = $FORM{"filterstring"};
	$filterseq = $FORM{"filterseq"};
	$filterz1 = $FORM{"filterz1"};
	$filterz2 = $FORM{"filterz2"};
	$filterz3 = $FORM{"filterz3"};
	$filterz4 = $FORM{"filterz4"};
	$filterz5 = $FORM{"filterz5"};	# filterz5 actually means "charge >4+" not "5+"
	$filtergbu1 = $FORM{"filtergbu1"};
	$filtergbu0 = $FORM{"filtergbu0"};
	$filtergbuminus1 = $FORM{"filtergbuminus1"};
	$filterScoresgtlt = ($FORM{"filterScoresgtlt"} || "gt");	# ">" by default
	$gtltvalue = ($filterScoresgtlt  eq "gt") ? ">" : "<";
	$filterXCorr = $FORM{"filterXCorr"};
	$filterdCn = $FORM{"filterdCn"};
	$filterSp = $FORM{"filterSp"};
	$filterRSp = $FORM{"filterRSp"};
	$filterMHplus = $FORM{"filterMHplus"};
	$filterIons = $FORM{"filterIons"};
	$filterSf = $FORM{"filterSf"};
	$filterP = $FORM{"filterP"};
	# remove any non-numerical characters from numerical filter parameters
	foreach ($filterXCorr,$filterdCn,$filterSp,$filterRSp,$filterMHplus,$filterIons,$filterSf,$filterP) {
		s/[^\d\.e]//g;
	}
  }
require "runsummary_javascript.pl";

# to create breaks between cell title and contents:
$table_breaks = "</td><td $table_contents_color nowrap>";


$lcq_avail=0;
$lcq_tracker_link = "";
$bericht_checkbox_code = "";
$bericht_menu = "mFile_2";
$file_menu_width = "";

######## variable definitions for use in menus #########

#$is_b_c = ($bericht_checkbox_code ne "") ? 1 : 0;
if ($bericht_checkbox_code eq "") { $bericht_checkbox_code = "$bericht_menu = 0;"; }

$chromatogram_link = "javascript:do_chromatogram()";
if ($NO_GBU_FILE) {
	$gbuURL = "goodbadugly2.pl?directory=$dir";
} else {
	$gbuURL = "view_gbu_stats.pl?directory=$dir";
}

$sigcalc_link = qq($webcgi/sigcalc.pl?directory=$dir);
$sf_link = qq($webcgi/scorefinal.pl?directory=$dir);
$muquest_link = qq($webcgi/muquest.pl?directory=$dir);

$showhidename = "clone_" . $boxtype . ".x";
$selecttoggle_link = qq(javascript:adjustSortValue(\\\\'$showhidename\\\\'););
$selecttoggle_name = uc($toggle) . " CONTROLS&nbsp;";

$maxlist_warning_js = "alert('This functionality is not available because the number of OUT files exceeds the current setting of MAX LIST ($MAX_LIST)');";
if ($#outs + 1 > $MAX_LIST) {
  $savestate_link = "javascript:$maxlist_warning_js";
  $savestate_link =~ s!\'!\\\\\'!g;
  $restorestate_link = "javascript:$maxlist_warning_js";
  $restorestate_link =~ s!\'!\\\\\'!g;
  $invertsets_link = "javascript:$maxlist_warning_js";
  $invertsets_link =~ s!\'!\\\\\'!g;
} else {
  $savestate_link = "javascript:save_state()";
  $restorestate_link = "javascript:restore_state(checked_dtas)";
  $invertsets_link = "javascript:invert_sets()";
}
$checkstategreyed = ($boxtype ne "HIDDEN") ? 0 : 1;

$checkbox_menu_code = "";
$ckboxelts_num = 0;
if ($boxtype ne "HIDDEN") {
	$ckboxelts_num = 5;
	$checkbox_menu_code .= qq(mSelect_1=new Array("ALL", "javascript:checkAll()")\n);
	$checkbox_menu_code .= qq(mSelect_2=new Array("NONE", "javascript:uncheckAll()")\n);
	$checkbox_menu_code .= qq(mSelect_3=new Array("INVERT", "javascript:invert()")\n);
	$checkbox_menu_code .= qq(mSelect_4=new Array("INVERT SETS", "$invertsets_link")\n);
	$checkbox_menu_code .= qq(mSelect_5=new Array("FILTER", "javascript:checkbox_control()")\n);

}


######## 


print <<EOF;
<script language="JavaScript" src="$webjsdir/menus.js"></script>
<script language="JavaScript" type="text/javascript"><!--
function highlightChoice(obj, menuDefault) {
	obj.bgColor='$popupmenuselectedcolor';
	obj.style.color='$popupfontselectedcolor';
	document.all(menuDefault).bgColor='$popupmenucolor';
	document.all(menuDefault).style.color='$popupfontcolor';
}
function unhighlightChoice(obj) {
	obj.bgColor='$popupmenucolor';
	obj.style.color='$popupfontcolor';
}
//-->
</script>

<div style="position:absolute; left:279; top:14" id="loading_indicator">
<table cellspacing=0 cellpadding=0 border=1><tr height=$button_table_height>
<td bgcolor=$filter_background_color><span class=smallheading style="color:'#ffffff'">&nbsp;Loading...&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:100; top:100; visibility:hidden;" id="IonsMenu" onmouseout="HideChoices('IonsMenu', event.x, event.y);">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=4></td><td>
<table cellspacing=0 cellpadding=0 border=1>
<tr><td id="IonsMenu_default" style="cursor:hand; color:#ffffff" width=70 align=left class=smallheading onclick="IonsGoTo('DisplayIons');" bgcolor=$popupmenuselectedcolor onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor';" onmouseout="unhighlightChoice(this);">&nbsp;DisplayIons&nbsp;</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="IonsGoTo('FuzzyIons');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'IonsMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;FuzzyIons</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="IonsGoTo('DeNovoX');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'IonsMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;DeNovoX</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="link_launch_muquest();" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'IonsMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;MuQuest</td></tr>
EOF
print <<EOF;
</table></td></tr></table></div>

<div style="position:absolute; left:100; top:100; visibility:hidden;" id="SeqMenu" onmouseout="HideChoices('SeqMenu', event.x, event.y);">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=4></td><td>
<table cellspacing=0 cellpadding=0 border=1>
<tr><td id="SeqMenu_default" style="cursor:hand; color:#ffffff" width=70 align=left class=smallheading onclick="blastGoTo('dpaanr');" bgcolor=$popupmenuselectedcolor onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor';" onmouseout="unhighlightChoice(this);">&nbsp;Blast NR&nbsp;</td></tr>
<tr><td style="cursor:hand;" width=70 align=left class=smallheading onclick="blastGoTo('dpanucdb');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'SeqMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Blast EST&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="seqCopyToClipboard(); HideChoices('SeqMenu', 0, 0);" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'SeqMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Copy&nbsp;</td></tr>
</table></td></tr></table></div>

<div style="position:absolute; left:100; top:100; visibility:hidden;" id="RefMenu" onmouseout="HideChoices('RefMenu', event.x, event.y);">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=4></td><td>
<table cellspacing=0 cellpadding=0 border=1>
<tr><td id="RefMenu_default" style="cursor:hand; color:#ffffff" width=70 align=left class=smallheading onclick="refGoTo('Retrieve');" bgcolor=$popupmenuselectedcolor onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor';" onmouseout="unhighlightChoice(this);">&nbsp;Flicka&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Report');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Report&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Sequence');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Sequence&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Abstract');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Abstract&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Gap', '$gap');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Gap&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refCopyToClipboard(); HideChoices('RefMenu', 0, 0);" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Copy&nbsp;</td></tr>
</table></td></tr></table></div>

<div style="position:absolute; left:100; top:100; visibility:hidden;" id="RefGroupMenu" onmouseout="HideChoices('RefGroupMenu', event.x, event.y);">
<table cellspacing=0 cellpadding=0 border=0>
<tr><td width=4></td><td>
<table cellspacing=0 cellpadding=0 border=1>
<tr><td id="RefGroupMenu_default" style="cursor:hand; color:#ffffff" width=70 align=left class=smallheading onclick="refGoTo('RetrieveSel');" bgcolor=$popupmenuselectedcolor onmouseover="this.bgColor='$popupmenuselectedcolor'; this.style.color='$popupfontselectedcolor';" onmouseout="unhighlightChoice(this);">&nbsp;Flicka&nbsp;</td></tr>
<!--<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('RetrieveSel');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Flicka on Selected&nbsp;</td></tr>-->
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('ReportSel');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Report&nbsp;</td></tr>
<!--<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('ReportSel');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Report on Selected&nbsp;</td></tr>-->
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Pepcut', '$pepcut');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Pepcut&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Sequence');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Sequence&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Abstract');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Abstract&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refGoTo('Gap', '$gap');" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Gap&nbsp;</td></tr>
<tr><td style="cursor:hand;" class=smallheading onclick="refCopyToClipboard(); HideChoices('RefGroupMenu', 0, 0);" bgcolor="$popupmenucolor" onmouseover="highlightChoice(this, 'RefGroupMenu_default');" onmouseout="unhighlightChoice(this);">&nbsp;Copy&nbsp;</td></tr>
</table></td></tr></table></div>



<div style="position:absolute; left:460; top:13;" id="mFile_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="mFile_activator" style="cursor:default; color:#808080;" onmouseover="ShowMenu('mFile');" onmouseout="MenuWait('mFile');"><span class=smallheading>&nbsp;File&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:520; top:13;" id="mSelect_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="mSelect_activator" style="cursor:default; color:#808080;" onmouseover="ShowMenu('mSelect');" onmouseout="MenuWait('mSelect');"><span class=smallheading>&nbsp;Select&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:600; top:13;" id="Menu2_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="Menu2_activator" style="cursor:default; color:#808080;" onmouseover="ShowMenu('Menu2');" onmouseout="MenuWait('Menu2');"><span class=smallheading>&nbsp;Sequest&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:690; top:13;" id="Menu3_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="Menu3_activator" style="cursor:default; color:#808080;" onmouseover="ShowMenu('Menu3');" onmouseout="MenuWait('Menu3');"><span class=smallheading>&nbsp;Protein&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:780; top:13;" id="Menu1_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="Menu1_activator" style="cursor:default; color:#808080;" onmouseover="ShowMenu('Menu1');" onmouseout="MenuWait('Menu1');"><span class=smallheading>&nbsp;Utilities&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:860; top:13;" id="Help_parent">
<table cellspacing=0 cellpadding=2 border=0 align=center><tr>
<td id="Help_activator" style="cursor:hand; color:#808080;" onclick="LinkTo('$webhelpdir/help_$ourshortname.html',1);"><span class=smallheading>&nbsp;Help&nbsp;</span></td>
</tr></table>
</div>

<div style="position:absolute; left:900; top:15;">
<table cellspacing=0 cellpadding=0 border=0><tr>
<td align=center width=90 nowrap><a href= "$HOMEPAGE"  target="_blank" class=smallheading style="color:#808080; text-decoration:none">Home</a></td>
</tr></table>
</div>

EOF
$mFileItems = 4;
$utilityMenuItem = 6;

print <<EOF;
<script language="javascript">
//ElementsToHide = new Array("DTA_action");   //# assign "" to this variable if no elements are to be hidden when menus pop up
//# format: menuname, number of subelements
MenuNames = new Array("Menu1", $utilityMenuItem, "Menu2", 6, "Menu3", 7, "mSelect", 1+$ckboxelts_num, "mFile", $mFileItems);
//# menu element arguments: 1=title, 2=link, 3= open in new window (1 if yes, unused for javascript commands), 4= grayed (1 yes, 0 no)
//# if argument 2 is "submenu", then argument 3 is number of subelements
//# if a menu item is set to 0 rather than an array (eg Menu1_2=0 rather than Menu1_2=new Array(...)) then the element is skipped and
//#    will not be included in the menu
mFile_1=new Array("CHECKBOXES", "submenu", 2);
$bericht_checkbox_code
mFile_3=new Array("CLEAR CACHE", "javascript:clear_cache()");
mFile_4=new Array("SETTINGS", "javascript:launch_advanced_settings()");
EOF


print <<EOF;
$file_menu_width
mFile_1_1=new Array("SAVE", "$savestate_link",0,$checkstategreyed);
mFile_1_2=new Array("RESTORE", "$restorestate_link",0,$checkstategreyed);
//mSelect_1=new Array("$selecttoggle_name", "$selecttoggle_link");
$checkbox_menu_code    // uses mSelect_1 through mSelect_5
mSelect_6=new Array("DTA VCR", "javascript:openDTA_VCR();");	//# no longer needed since controls are always shown
Menu1_width = 95;
Menu1_1=new Array("CHROM","$chromatogram_link");
Menu1_2=new Array("GBU","$gbuURL",1);
Menu1_3=new Array("MUQUEST","$muquest_link",1);
Menu1_4=new Array("POST-OP", "$postop?dir=$dir&gbu=1&sf=1&sc=1", 1);
Menu1_5=new Array("SF","$sf_link",1);
Menu1_6=new Array("SIG CALC","$sigcalc_link",1);

Menu2_1=new Array("SETUP","$setupdirs",1);
Menu2_2=new Array("CREATE DTA","$create_dta",1);
Menu2_3=new Array("IONQUEST","$webionquest",1);
Menu2_4=new Array("RUN SEQUEST","$seqlaunch",1);
Menu2_5=new Array("STATUS","$seqstatus",1);
Menu2_6=new Array("SUMMARY","$createsummary",1);
Menu3_1=new Array("PEPCUT","$pepcut",1);
Menu3_2=new Array("PEPSTAT","$pepstat",1);
Menu3_3=new Array("TRANSLATE","$translate",1);
Menu3_4=new Array("GAP","$gap",1);
Menu3_5=new Array("NCBI","http://www.ncbi.nlm.nih.gov/",1);
Menu3_6=new Array("BLAST","$blastpage",1);
Menu3_7=new Array("ENTREZ","http://www.ncbi.nlm.nih.gov/Entrez/",1);
InitializeMenus();
</script>

<style type="text/css"><!--
input.check { height:1em; padding:0 }
div.scrolldiv {
	scrollbar-3dlight-color:#333366;
	scrollbar-arrow-color:#000000;
	scrollbar-base-color:#e8e8fa;
	scrollbar-darkshadow-color:#333366;
	scrollbar-face-color:#e8e8fa;
	scrollbar-highlight-color:#e8e8fa;
	scrollbar-shadow-color:#e8e8fa
}
--></style>

EOF

if ($consensus_view_mode eq "simple") {
	$advconstuffstyle = "display:none";
	$advconstufftoostyle = "visibility:hidden";
} else {
	$advconstuffstyle = "";
	$advconstufftoostyle = "";
}

print <<EOF;
<style type="text/css" id="advconstyle">
<!--
.advconstuff { $advconstuffstyle }
.advconstufftoo { $advconstufftoostyle }
-->
</style>
EOF

print qq(<script language="JavaScript" src="$webjsdir/runsummary.js"></script>\n);
print qq(<script language="JavaScript" src="$webjsdir/IELaunch.js"></script>\n);
######## begin table ########
print qq(<table cellpadding=0 cellspacing=0 border=0 width=975>\n);
#### row 1
print qq(<tr><td rowspan=6 width=0></td>\n);
print qq(<td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>\n);
&print_simple_info ("Extd Sample");
print ("&nbsp;" x 1);
&print_clonest_form();
&open_main_form();
print qq(\n</td><td width=$table_horz_spacing></td><td $table_heading_color $table_heading_align nowrap>\n);

  my ($num_spectra, $num_important, $BPTot);
  $num_spectra = $#orderedouts + 1; # number of all files, with duplications
  my (%prefie, $temp);
  foreach $file (@orderedouts) {
    ($temp = $file) =~ s!\.\d$!!;
    next if $prefie{$temp};  # don't count 2+/3+ pairs twice
    $num_important++;        # number of files, without duplications
    $BPTot += $BP{$file};
    $prefie{$temp} = 1;
  }
  $BPTot = &sci_notation ($BPTot);
# Simple routine to get $progress_ind 
# added 3/2/99 by piotr dollar
	opendir(DIR,"$seqdir/$directory");
	my(@allfiles) = readdir(DIR);
	closedir(DIR);
#	$num_o = grep /\.out$/, @allfiles;
#   sometimes dta-files are size 0 (WHY?) the above method would count these
	$num_d = grep /\.dta$/, @allfiles;
	my($progress_ind) = ($num_spectra < $num_d) ? "<span style=\"color:#FF0000\"><blink><b>$num_spectra of $num_d</b></blink></span>" : "$num_spectra";
# end of routine to get $progress_ind
my($progress_inicator) = 
  print <<BILLS_HEAD;
<span class="smallheading">OutFiles:&nbsp;&nbsp;</span></td><td $table_contents_color width=100 nowrap>
<a href="$inspector?directory=$directory" target="_blank"><span class=smalltext>$progress_ind|$num_important</span></a>
BILLS_HEAD
print qq(<INPUT TYPE=hidden NAME="image.x" VALUE="">);
print qq(<INPUT TYPE=HIDDEN VALUE=$new_algo NAME="new_algorithm">);
print qq(<input type=hidden name="clearcache" value=0>);

print qq(\n</td><td width=$table_horz_spacing></td>);
#print qq(<td width=$table_horz_spacing2>);
print qq(<td width=100 rowspan=5>);
print qq(<span id="PieChart">&nbsp;);
#print qq(<img src="$webimagedir/piechart90.gif" width=90 height=90>);
print qq(</span>);

print qq(</td><td width=$table_horz_spacing></td><td width=$table_horz_spacing2></td></tr>\n);

#### row 2
print qq(<tr><td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>&nbsp;\n);
&print_simple_info ("Files");
#print ("&nbsp;" x 1);
print qq(\n</td><td width=$table_horz_spacing></td><td $table_heading_color $table_heading_align nowrap>\n);
&print_simple_info ("Enzyme");
print ("&nbsp;" x 1);
print qq(\n</td><td></td><td nowrap>);

print qq(</td><td></td>\n);

print qq(</tr>\n);

#### row 3
print qq(<tr><td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>\n);
&print_simple_info ("Db");
print ("&nbsp;" x 5);
print qq(\n</td><td width=$table_horz_spacing></td><td $table_heading_color $table_heading_align nowrap>&nbsp;\n);
&print_simple_info ("Mass");
print qq(\n</td><td></td><td nowrap>);
#print qq(<span class="smalltext">row 3</span>);
print qq(</td><td nowrap>\n);
print qq(\n</td></tr>\n);

#### row 4
print qq(<tr><td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>\n);
&print_simple_info ("Dir");
print qq(&nbsp;&nbsp;<a href="$viewheader?directory=$directory" target="_blank" class=smalltext>Info</a>);


print qq(\n</td><td width=$table_horz_spacing></td><td $table_heading_color $table_heading_align nowrap>\n);
print qq(<span class="smallheading">Max list:&nbsp;&nbsp;</span>);
print qq(</td><td $table_contents_color nowrap>);
print qq(<INPUT TYPE=TEXT NAME="max_list" SIZE=4 MAXLENGTH=5 VALUE="$MAX_LIST" $dropbox_style>);
print qq(</td><td></td><td nowrap>);
print qq(</td><td valign=middle nowrap>\n);
print qq(</td></tr>\n);

#### row 5
print qq(<tr><td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>\n);

#adjust the diff mods for display
my $display_diff_mods = $diff_mods;

### NOTE: This code that formats $display_diff_mods should not be changed without checking to make
###       sure that the changes won't affect the form elements that are sent to protein report below.
#add symbol and : for each mod and put the mod number behind it
$display_diff_mods =~ s/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+))?/$2*:$1 $4#:$3 $6\@:$5 $9^:$8 $11~:$10 $13\$:$12 /;

$display_diff_mods =~ s/(\S+:\s)//g;						 # eliminate the mod symbols which has no values 
$display_diff_mods =~ s/\s*\S+\:0\.(0)+\s+/ /g;				 # eliminate the diff mod while the value is 0
$display_diff_mods =~ s/(\d+\.\d*?)(0)+(\s+)/$1$3/g;		 # eliminate the zeros at the end of the mod number	
$display_diff_mods =~ s/(\d+)\.(\s+)/$1$2/g;				 # eliminate the . while there is no numbers behind it
$display_diff_mods =~ s/:(\d)/:+$1/g;						 # add + for positive mod numbers

### Horribly wrong in terms of style, but works for now... needs to be combined correctly
$term_diff_mods =~ s/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+?/$4:$3 $2:$1 /;

$term_diff_mods =~ s/(\S+:\s)//g;						 # eliminate the mod symbols which has no values 
$term_diff_mods =~ s/\s*\S+\:0\.(0)+\s+/ /g;				 # eliminate the diff mod while the value is 0
$term_diff_mods =~ s/(\d+\.\d*?)(0)+(\s+)/$1$3/g;		 # eliminate the zeros at the end of the mod number	
$term_diff_mods =~ s/(\d+)\.(\s+)/$1$2/g;				 # eliminate the . while there is no numbers behind it
$term_diff_mods =~ s/:(\d)/:+$1/g;						 # add + for positive mod numbers

$display_diff_mods .= $term_diff_mods;

print qq(<span class="smallheading">Diff Mods:&nbsp;&nbsp;</span></td><td $table_contents_color width=280 nowrap><span class="smalltext" style="color:#215E21">$display_diff_mods</span>\n);
#print qq(</td><td nowrap>\n);
#print qq(<span class="smallheading">Header Filter:&nbsp;&nbsp;</span></td><td nowrap><span class="smalltext">$header_filter&nbsp;&nbsp;</span>\n) if ($header_filter =~ /\S/);
#print qq(</td><td nowrap>\n);
print qq(</td><td></td><td $table_heading_color $table_heading_align nowrap>);

# new Intensity controls added by cmw, 4/20/99
# mode "Peak" added by Mike 7/31/00
%printed_name = ("maxBP" => "Apex",  "fBP" => "Full", "zBP" => "Zoom", "TIC" => "MS2");
print qq(<span class="smallheading">&nbsp;&nbsp;Intensity:&nbsp;&nbsp;</span></td><td $table_contents_color nowrap>);
print qq(<span class="smalltext">$BPTot &nbsp;&nbsp;&nbsp;</span>);
print qq(<span class=dropbox><select name="BP_mode" $dropbox_style onChange="document.mainform.submit()">);
foreach $mode ("maxBP","fBP","zBP","TIC") {
	if (${"$mode\_available"}) {
		$checked = ($mode eq $BP_mode) ? " selected" : "";
		print qq(<option value="$mode"$checked>$printed_name{$mode});
	}
}
print qq(</select></span>);
print qq(<input type=hidden name="prev_BP_mode" value="$BP_mode">\n);
print ("&nbsp;" x 1);
print qq(</td><td></td><td></td>);
print qq(<td align=right nowrap>);
print qq(<table cellspacing=0 cellpadding=0 border=0><tr>);
if ($boxtype ne "HIDDEN" && $use_filter) { # display "Filter Off" button only if filter is on
	print <<EOF;
<td>
<table cellspacing=0 cellpadding=0 border=1 $button_table_border><tr height=$button_table_height>
<td valign=middle bgcolor=$filter_background_color nowrap>
<A HREF="javascript:filter_off()" onMouseover="status='Click to turn filter off'; return true" onMouseout="status=''; return true" class="smallheading" style="text-decoration:none; color:$button_font_color">&nbsp;Filter On&nbsp;</A></td>
</tr></table>
</td>
EOF
} else {
	print qq(<td width=58></td>);
}

if ($load_dta_vcr) {
  print qq(<td id="dta_vcr_cell">);
  #print qq(<table cellspacing=0 cellpadding=0 border=1 $button_table_border><tr height=$button_table_height><td valign=middle bgcolor=$button_background_color style="cursor:hand; color:$button_font_color" onclick="openDTA_VCR();" onmouseover="buttonHighlight(this);" onmouseout="buttonUnHighlight(this);" nowrap>);
  #print qq(<span class="smallheading">&nbsp;DTA VCR&nbsp;</span>);
  print qq(<input type=hidden name="DTAVCR:include_array" value="selected">) if ($boxtype ne "HIDDEN");
  print qq(<input type=hidden name="DTAVCR:conserve_space" value=1></td>);
  print qq(<input type=hidden name="chosen" value="">);
  #print qq(</tr></table>);
  print qq(</td><td width=12></td>);
}

print qq(<td nowrap>);

if ($boxtype ne "HIDDEN") {

	print qq(<span class="dropbox"><SELECT NAME="DTA_action" $dropbox_style>);
	print qq(<OPTION VALUE="clone" SELECTED>Clone dir...);
	print qq(<OPTION VALUE="clonest">Clone cloner clonEST);
	print qq(<OPTION VALUE="delete">Delete...);
	print qq(<OPTION VALUE="muquest">Muquest on selected);
	print qq(<OPTION VALUE="tsunami">Tsunami database...);


## Added 9/7/00 by Paul
## This is where we block the user from using certain functions in the drop down if there are more outfiles
## than are shown.  as of 9/7/00, only folge is allowed.  To allow more just add conditional exceptions to the
## javascript below.

if ($#outs + 1 > $MAX_LIST) {
	$GoLink = <<EOL;
	<A class="smallheading" style="text-decoration:none; color:#000000;" HREF=
		"javascript:
		var mdao = mainform.DTA_action.options[mainform.DTA_action.selectedIndex].value;
		if (mdao == 'report' || mdao == 'xmlreport') { 
			dtaActionFunction(); 
		} else {
			$maxlist_warning_js 
		}
		\"
	>
EOL
} else {
	$GoLink = "<A class=smallheading style=\"text-decoration:none; color:#000000\" HREF=\"javascript:dtaActionFunction();\">";
}
	print <<EXEBUTTON;		## document.mainform.target='_blank' below added by dmitry 990925
</SELECT></span>
</td><td width=4></td><td nowrap>
<table border=1 cellspacing=0 cellpadding=0 align=right $button_table_border><tr height=$button_table_height>
<td valign=middle bgcolor=$go_button_color nowrap>
$GoLink&nbsp;Go&nbsp;</A><INPUT TYPE=HIDDEN NAME="execute.x" VALUE=""></td>
</tr></table>
EXEBUTTON
}

print qq(</td></tr></table>);

print qq(</td><td valign=bottom nowrap>\n);
print qq(</td></tr>\n);


#### row 6 - only for some summaries
# for header filter (KM)
if ($header_filter =~ /\S/) {
	print qq(<tr><td $table_heading_color $table_heading_align height=$table_vert_spacing nowrap>\n) ;
	print qq(<span class="smallheading">&nbsp;&nbsp;Header Filter:&nbsp;&nbsp;</td><td $table_contents_color nowrap><span class="smalltext">$header_filter&nbsp;&nbsp;</span>\n);
}

#### end
print qq(<tr height=7><td>);
#temporary:
#
print qq(</td></tr>);
print qq(</table>\n\n);

######## end table ########



&print_top();

&print_data();

print "<p>\n";

#&print_consensi();	removed old maxlist functionality 7/12/00 tv

if (!$dbavail) {
    print "<BR>*Database $database[0] unavailable for sequence descriptions.\n";
}

&closeidx();

&dta_vcr_code if ($load_dta_vcr);

print "</FORM>\n";

my @dispdiffmods = split /\s+/, $display_diff_mods;
my @diffmods;
my %modchars = ('*' => 0, '#' => 1, '@' => 2, '^' => 3, '~' => 4, '$' => 5, ']' => 6, '[' => 7);
my $currentmod;
foreach (0..$#dispdiffmods) {
	$currentmod = ($dispdiffmods[$_] =~ /(.)\:/)[0];
	$diffmods[$modchars{$currentmod}] = $dispdiffmods[$_];
}
my $labelcode = "";
foreach (0..$#diffmods) {
	my $ind = $_+1;
	$labelcode .= qq(<input type=hidden name='m${ind}Label' value='$diffmods[$_]'>\n) if $diffmods[$_];
}

## Try to use the new mod sites of 6... this needs to be improved code.
#my @diffmods = ($diff_mods =~ /([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+)/);
#my @diffweights = @diffmods[0,2,4,6,8,10];
#my @diffaas = @diffmods[1,3,5,7,9,11];
#
## or support the old mod sites of 3
#if ($#diffmods == -1) {
#	@diffmods = ($diff_mods =~ /([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+) ([\+\-]?\d+\.\d+) (\w+)/);
#	@diffweights = @diffmods[0,2,4];
#	@diffaas = @diffmods[1,3,5];
#}
#my ($plusorminus, $labelnumber);
#foreach (0..$#diffweights) {
#	$labelnumber = $diffweights[$_];
#	$plusorminus = "+";
#	if ($labelnumber =~ /-/) {
#		$plusorminus = "–";		# note: this is an en dash (Alt+0150), not a simple hyphen
#	}
#	$labelnumber = abs $labelnumber;
#
#	$diffmods[$_] = ($diffweights[$_] != 0) ? "$diffaas[$_]$plusorminus$labelnumber" : "";
#}

# this form is used for sending parameters to flicka
print <<EOF;
<form name='retrieveform' action='$retrieve' method='POST' target='_blank'>
<input type=hidden name='Db'>
<input type=hidden name='NucDb'>
<input type=hidden name='MassType'>
<input type=hidden name='Pep'>
<input type=hidden name='Dir'>
<input type=hidden name='Ref'>
<input type=hidden name='running' value=1>
<input type=hidden name='mode' value = "">
</form>
<form name='reportform' action='$proteinreport' method='POST' target='_blank'>
<input type=hidden name='db'>
<input type=hidden name='ref'>
<input type=hidden name='peptides'>
<input type=hidden name='tics'>
<input type=hidden name='isnuc'>
<input type=hidden name='compare_against' value='ref'>
<input type=hidden name='directory' value='$dir'>
<input type=hidden name='masstype'>
$labelcode
EOF

#<input type=hidden name='m1Label' value='$diffmods[0]'>
#<input type=hidden name='m2Label' value='$diffmods[1]'>
#<input type=hidden name='m3Label' value='$diffmods[2]'>
#EOF
#if ($#diffaas > 3) {
#print <<EOF;
#<input type=hidden name='m4Label' value='$diffmods[3]'>
#<input type=hidden name='m5Label' value='$diffmods[4]'>
#<input type=hidden name='m6Label' value='$diffmods[5]'>
#EOF
#}

print ("</form>");

if ($boxtype eq "CHECKBOX") {
	&post_checkbox_js();
}

##### this JS code is used for flicka/report on selected feature
print qq(<script language="JavaScript"><!--\n);
foreach $r (keys %outs_js) {
	@jsfiles = ();
	foreach $h (@{$outs_js{$r}}) {
		push @jsfiles, qq(["$h->{sel}", "$h->{pep}", "$h->{tic}", "$h->{filenum}"]);
	}
	print "var group$r = [";
	print (join ', ', @jsfiles);
	print "];\n";
}
print "\n";
foreach $r (keys %hidden_outs_js) {
	print "var hidden$r = [";
	print (join ', ', @{$hidden_outs_js{$r}});
	print "];\n";
}
print qq(//-->\n</script>);



######### code to create pie chart:  ############

my $piecode = "";

if (scalar(keys %colorsandvalues) > 0) {
	my $nogroupcolor = "#f2f2f2";
	my $nogroupvalue = $colorsandvalues{"nogroup"};
	delete $colorsandvalues{"nogroup"};
	my @sortedcolorsandvalues = sort { $colorsandvalues{$b} <=> $colorsandvalues{$a} } keys %colorsandvalues;  # get a list of the keys sorted by value

	unless ($colorsandvalues{$sortedcolorsandvalues[0]} == 100) {	# don't show piechart if there is only one 'slice'
		my @flatlist;
		my $maxind = ($#sortedcolorsandvalues > 15) ? 15 : $#sortedcolorsandvalues;		# ensure no more than 16 pie slices
		for ($i=0; $i <= $maxind; $i++) {
			my $colr = $sortedcolorsandvalues[$i];
			#my $colorname = ($colr eq "nogroup") ? "#f2f2f2" : $colr;		# the nogroup color is #f2f2f2, a light grey (the light blue was #009cbc)
			#push @flatlist, $colorname;
			push @flatlist, $colr;
			push @flatlist, $colorsandvalues{$colr};
		}

		for ($i=0; $i<=$#flatlist; $i+=2) {
			my $piecolor = $flatlist[$i];
			my $pievalue = $flatlist[$i+1];
			my $valcolnum = $i/2 + 1;
			#print "$valcolnum--$pievalue--$piecolor<br>";		# for debugging
			$piecode .= "<param name='Pvalue$valcolnum' value='$pievalue'><param name='Pcolor$valcolnum' value='$piecolor'>";
		}
		#print "nogroup: $nogroupvalue";
		$nogroupstring = $nogroupvalue ? "<param name='nogroupval' value='$nogroupvalue'><param name='nogroupcolor' value='$nogroupcolor'>" : "";
		$piecode = "<param name='otherscolor' value='#000000'>$nogroupstring" . $piecode;
		$maxind++;
		$piecode = "<applet code='PieChart/PieChart.class' archive='PieChart.jar' codebase='$webjavadir' width=90 height=90><param name='columns' value='$maxind'>" . $piecode . "</applet>";
	}
}

# to simply print applet at bottom of page (for testing):
#print $piecode;

print qq(\n\n<script language='javascript'><!--\n);


# to print applet in correct place on page:
print qq(document.all('PieChart').innerHTML = "$piecode";\n) if $piecode;

print <<HIDEINDICATOR;

status='';

function loadingIndicatorOff()
{
var thecell = document.getElementById("loading_indicator");
thecell.style.display = "none";
}
function loadingIndicatorOn()
{
var thecell = document.getElementById("loading_indicator");
thecell.style.display = "";
}
loadingIndicatorOff();
-->
</script>
HIDEINDICATOR

print "</body></html>\n";
exit 0;

#########         end of main program            ###########
############################################################

sub URLized_mods {
  my ($filenum) = $_[0];
  my ($mods) = $mods[$filenum];
  my ($line) = "";

  $mods =~ s/Enzyme:.*//;
  $mods =~ s!\(.*?\)!!g;

  # remove anything in parens
  foreach $piece (split (' ', $mods)) {
    $piece =~ s!\s*!!g;

    # for AA mods:
    if ($piece =~ m!^[A-Z]=!i) {
      $line .= "&Mass" . $piece;

    # "N-term" goes to "Nterm", "C-term" to "Cterm":
    } elsif ($piece =~ m!\+([A-Z])-term!) {
      $piece =~ s!\+([A-Z])-term!$1term!; 
      $line .= "&$piece";

    } else {
      # blm addition of comment--what is this necessary for??? 000815
	  #$line .= "&:Unknown variable:$piece";
    }
  }
  return $line;
}

##
## print_clonest_form()
## prints a (hidden) formt that lets us launch clonestnsequest.pl from the dropdown
##

sub print_clonest_form
{
	print <<EOF;
	<form name="clonestform" action="$webcgi/clonestnsequest.pl" target="_blank">
	<input type=hidden name=directory value=$directory>
	<input type=hidden name=dtas value="">
	</form>
EOF
}


##
## this just prints the simple info of sample, masstype, dir, files, database, and enzyme specificity/
## The args are simply an ordered list of the options wanted. No args gives the standard order:
## ("Extd Sample", "Dir", "Files", "Db", "Mass", "Enzyme")
##
## Other possibilities are "Sample", "User", "SampleID", and "Operator".
##
## "Extd Sample" is in the form "Sample: Baker, M. (TESTOPER3) 99999 mab". It actually calls &print_sample_name();
## "Sample" is simply "TESTOPER3".
## 
## "Tot" outputed separately (see above)

sub print_simple_info {
  my (@terms) = @_;

  my %terms;
  if (! @terms) {
    @terms = ("Extd Sample", "Dir", "Files", "Db", "Mass", "Enzyme");
  }
  foreach $term (@terms) {
    $term{$term} = 1;
  }


  my (%dir_info);

  # $file_string was defined here, but I need it globally
  my ($db, $mtime, $dbdate, $massname, $url);
  my ($day, $month, $year, $t, $temp); # $t, $temp are dummy variables
  my ($check, $enzyme); # used to construct regexps so that we don't count
               # multiple databases more than once
  
  ## check for Mono or Avg mass:
  if ($term{"Mass"}) {
    $temp = $masstype[0];
    foreach $val (@masstype) {
      next if ($temp == $val);
      $temp = 2;
      last;
    }
    if ($temp == 2) {
      $massname = "Mixed";
    } else {
      $massname = $temp ? "Mono" : "Avg";
    }
  }

  ## check for databases used
  if ($term{"Db"}) {
    $db = $database[0];
    $temp = "";
    $check = "\Q$db\E";

    my $count = 0;
	foreach $val (@database) {
      next if ($val =~ m!^($check)$!);
      if ($count > 0) {
		$temp .= " ..... ";
		last;
	  }
	  $temp .= " $val";
      $check .= "|\Q$val\E";
	  $count++;
    }

    $mtime = (stat("$dbdir/$db"))[9];
    ($t, $t, $t, $day, $month, $year) = localtime($mtime);

    $url = "$webdbdir/$db";
    # remove ".fasta" from the name:
    $db =~ s!\.FASTA!!i;

	$turbo = "(turbo)&nbsp;" if ($databasename =~ /.HDR/i);	
    $db = qq(<a target="_blank" href="$url">$db</a>);
#    $year %= 100;
	$year += 1900;	# it comes with 1900 subtracted
    $month++; # it comes in the range 0-11

    $day = &precision ($day, 0, 2);
    $month = &precision ($month, 0, 2);
    $year = &precision ($year, 0, 4);

    $dbdate = "$month/$day/$year";

    $db .= "&nbsp;$turbo($dbdate)";

    if ($temp) {
      $temp =~ s!(\S+)(\.FASTA)!<a target="_blank" href="$webdbdir/$1$2">$1</a>!gi;

      $db .= " and " . $temp;
    }
  }

  if ($term{"Files"}) {
    ## check for multiple filename prefixes
    ## (this indicates the user combined more than one 
    ## run in the same directory)

    ($file_string) = $outs[0] =~ m!^([^\.]*)!;

	# SDR: Added so if out files don't exist, use dta's for the string name THIS MAY BE SLOW if called multiple times
	if (!$file_string) {
		opendir (DIR, "$seqdir/$dir");
		my (@dtafiles) = grep { /\.dta$/ } readdir (DIR);
		closedir DIR;
		($file_string) = $dtafiles[0] =~ m!^([^\.]*)!;
	}
	
	$temp = "";
    $check = "\Q$file_string\E";

    my $count = 0;
	foreach $file (@outs) {
      next if ($file =~ m!^($check)\.!); # quote to protect it
 	  if ($count > 0) {
		$temp .= " ...... ";
		last;
	  }
      $file =~ m!^([^\.]*)!;
      $temp .= " $1";
      $check .= "|\Q$1\E";
	  $count++;
    }

    $file_string .= $temp if ($temp);
  }

  if ($term{"Enzyme"}) {
    ## check all enzymes
    ($enzyme) = $mods[0] =~ m!Enzyme:\s*(\S+)!;
  
    $check = "\Q$enzyme\E";
    my $no_enz = 0;

    if ($enzyme eq "") {
      $enzyme = "None";
      $check = "";
      $no_enz = 1;
    }
    $temp = "";

    foreach $mod (@mods) {
      next if ($mod =~ m!Enzyme:\s*($check)\W!); # match end of word
      if ($mod =~ m!Enzyme:\s*(\S+)!) {
        $temp .= " $1";
        $check .= "|\Q$1\E";
      } else {
        next if $no_enz;

        $no_enz = 1;
        $temp .= " None";
      }
    }
    $enzyme .= " and" . $temp if ($temp);
  }

  if ($term{"Sample"} || $term{"Sample ID"} || $term{"User"} || $term{"Operator"}) {
    %dir_info = &get_dir_attribs ("$directory");
  }

  my ($term, $output, $title);

  while ($term = shift @terms) {
    $title = $term; # $title is the actual title output to the user; usually it is the same as the term name
  
	if ($term eq "Dir") {
      $title = "Directory";
	  $output = qq(<a target="_blank" href="$webseqdir/$directory">$directory</a>);

    } elsif ($term eq "Files") {
	  $title = "DataFiles";
      #$output = qq(<span style="color:#0080C0"><a href="\\\\$weblcqdir\\${file_string}.raw">$file_string</a>) . " ($date_string)</span>\n";
	  ## above line replaced with the following lines 5/30/02 to add the lcq tracker link to the date text
	  if ($lcq_tracker_link) {
		$date_string = ($date_string =~ /.*?\d+.*/g) ? qq(<a href="$lcq_tracker_link" style="color:#0080C0" onmouseover="this.style.color='#ff0000'; status='LCQ Tracker'; return true;" onmouseout="this.style.color='#0080C0'; status=''; return true;" target="_blank">($date_string)</a>) : "";
	  } else {
		$date_string = ($date_string =~ /.*?\d+.*/g) ? qq(<span style="color:#0080C0">($date_string)</span>) : "";
	  }
	  $output = qq(<a href="\\\\$weblcqdir\\${file_string}.raw">$file_string</a> $date_string) if ($file_string);

	  ## end 5/30/02 replacement

    } elsif ($term eq "Db") {
      $title = "Database";
      $output = qq(<span style="color:blue">$db</span>);

    } elsif ($term eq "Mass") {
      $title = "Mass";
	  $pep_mass_tol = &precision ($pep_mass_tol, 1);
      $output = qq(<span style="color:#215E21">±$pep_mass_tol&nbsp;&nbsp;($massname)</span>);

    } elsif ($term eq "Enzyme") {
      $title = "Enzyme";
      $output = qq(<span style="color:#8000FF">$enzyme</span>);

    } elsif ($term eq "Extd Sample") {
      &print_sample_name ($directory);
      print ("    \n") if (@terms);
      next;

    } elsif ($term eq "Sample") {
      $output = $dir_info{$term};

    } elsif ($term eq "SampleID") {
      $title = "Sample ID";
      $output = $dir_info{$term};

    } elsif ($term eq "Operator") {
      $title = "Oper";
      $output = $dir_info{$term};

    } elsif ($term eq "User") {
      $output = $dir_info{"LastName"} . ", " . $dir_info{"Initial"} . ".";

    } else {
      next;
    }
	
	print ("<span class=\"smallheading\">$title:&nbsp;&nbsp;</span>\n");
	print $table_breaks if ($table_breaks);
    ##
	# for fixed-width fonts in header: print qq(<tt>$output</tt>\n);
    # otherwise:
    print qq(<span class="smalltext">$output</span>\n);
	##
    print ("    \n") if (@terms);
  }
}


##
## this prints the buttons at the top of the page (after the header and simple info)
##

sub print_top {

print "<nobr>";

my $sort_type = &find_sort_value();

my $usenucleo = ($IsNucleotideDb) ? "n" : "p";

  print <<EOF;
<SCRIPT LANGUAGE="Javascript">
<!--

function do_chromatogram()
{
	oldtarget = document.mainform.target;

	document.mainform["image.x"].value = 1;
	document.mainform.target = "_blank";
	document.mainform.submit();

	document.mainform["image.x"].value = "";
	document.mainform.target = oldtarget;

	//self.onfocus = chromatogram_cleanup;
}
/*
function chromatogram_cleanup()
{
	// put things back as they were
	document.mainform["image.x"].value = "";
	document.mainform.target = oldtarget;

	self.onfocus = null;
}
*/
function toggleSFFilter()
{
	for (var i = 0; i < filteredGroups.length; i++) {
		var group = document.getElementById(filteredGroups[i]);
		if (sf_filter) {
			group.style.display = "";
		} else {
			group.style.display = "none";
		}
	}
	var btn = document.getElementById("sffiltertoggle");
	if (sf_filter) {
		btn.innerHTML = '<span style="color:blue">consensus filter:</span> off';
		sf_filter = 0;
		document.mainform.consensus_filter_mode.value = "off";
	} else {
		btn.innerHTML = '<span style="color:blue">consensus filter:</span> on';
		sf_filter = 1;
		document.mainform.consensus_filter_mode.value = "on";
	}
}
function toggle_advanced_consensus_stuff()
{
	var advcontoggle = document.getElementById("advcontoggle");
	
	if (advcontoggle.innerHTML == "advanced") {
		advcontoggle.innerHTML = "simple";
		document.styleSheets.advconstyle.rules[0].style.display = "none";
		document.styleSheets.advconstyle.rules[1].style.visibility = "hidden";
		document.mainform.consensus_view_mode.value = "simple";
	} else {
		advcontoggle.innerHTML = "advanced";
		document.styleSheets.advconstyle.rules[0].style.display = "";
		document.styleSheets.advconstyle.rules[1].style.visibility = "";
		document.mainform.consensus_view_mode.value = "advanced";
	}
}
function toggleAll(buttonPressed)
{
	var buttonFirst = document.getElementById("firstToggle");
	var buttonSecond = document.getElementById("secondToggle");

	for (var i = 0; i < expandAndContract.length; i++) {
		var groupSpanId = expandAndContract[i] + "_";
		var groupSpan = document.getElementById(groupSpanId);
		var button = document.getElementById(expandAndContract[i]);

		if (buttonPressed.act=="contractall") {
			button.src = "$webimagedir/tree_closed.gif";
			groupSpan.style.display = "none";
		} else {
			button.src = "$webimagedir/tree_open.gif";
			groupSpan.style.display = "";
		}
	}

	if (buttonPressed.act=="contractall") {
		buttonSecond.act = "";
		buttonSecond.style.display = "none";
		buttonFirst.act = "expandall";
		buttonFirst.src = "$webimagedir/tree_closed.gif";
		expanded = 0;
	} else {
		buttonSecond.act = "";
		buttonSecond.style.display = "none";
		buttonFirst.act = "contractall";
		buttonFirst.src = "$webimagedir/tree_open.gif";
		expanded = expandAndContract.length;
	}
	
	document.getElementById("hr1").style.display = "";
	document.getElementById("hr2").style.display = "";
}

function toggleGroupDisplay(toggleButton)
{
	var buttonFirst = document.getElementById("firstToggle");
	var buttonSecond = document.getElementById("secondToggle");
	var hr1 = document.getElementById("hr1");
	var hr2 = document.getElementById("hr2");

	var groupSpanId = toggleButton.id + "_";
	var groupSpan = document.getElementById(groupSpanId);

	var expandStateInputId = "expand_" + toggleButton.id;
	var expandStateInput = document.getElementById(expandStateInputId);

	if (groupSpan.style.display=="none") {
		toggleButton.src = "$webimagedir/tree_open.gif";
		groupSpan.style.display = "";
		expandStateInput.value = "expanded";
		expanded++;
	} else {
		toggleButton.src = "$webimagedir/tree_closed.gif";
		groupSpan.style.display = "none";
		expandStateInput.value = "collapsed";
		expanded--;
	}

	if (expanded == 0) {
		buttonSecond.act = "";
		buttonSecond.style.display = "none";
		hr1.style.display = "";
		hr2.style.display = "";
		buttonFirst.act = "expandall";
		buttonFirst.src = "$webimagedir/tree_closed.gif";
	} else if (expanded == expandAndContract.length) {
		buttonSecond.act = "";
		buttonSecond.style.display = "none";
		hr1.style.display = "";
		hr2.style.display = "";
		buttonFirst.act = "contractall";
		buttonFirst.src = "$webimagedir/tree_open.gif";
	} else {
		buttonFirst.act = "expandall";
		buttonFirst.src = "$webimagedir/tree_closed.gif";
		hr1.style.display = "none";
		hr2.style.display = "none";
		buttonSecond.act = "contractall";
		buttonSecond.src = "$webimagedir/tree_open.gif";
		buttonSecond.style.display = "";
	}
}

function adjustSortValue(sortitem) {
	loadingIndicatorOn();	
	document.mainform.svgh.name = sortitem;
	document.mainform.submit();
}

function buttonHighlight(obj) {
	obj.bgColor='$button_mouseover_background_color';
	obj.style.color='$button_mouseover_font_color';
}
function buttonUnHighlight(obj) {
	obj.bgColor='$button_background_color';
	obj.style.color='$button_font_color';
}

function clear_cache() {
	document.mainform.clearcache.value = 1;
	document.mainform.svgh.name = "sort_$sort_type";
	document.mainform.submit();
}

//var linkparameters="";
//var selectedfilename="";


popupfontselectedcolor="$popupfontselectedcolor";
popupmenuselectedcolor='$popupmenuselectedcolor';
popupmenudelay='$popupmenudelay';
DtaDir='$seqdir/$directory/';
WebDtaDir='\\\\\\\\$webserver\\\\sequest\\\\$directory\\\\';
displayions='$displayions';
fuzzyions='$fuzzyions';
javaions='$javaions';
denovox='$DEFS_IELAUNCH{"DenovoX"}';
muquestname='$webmuquest';
db_prg_aa_nuc_dbest='$db_prg_aa_nuc_dbest';
db_prg_aa_nuc_nr='$db_prg_aa_nuc_nr';
db_prg_aa_aa_yeast='$db_prg_aa_aa_yeast';
db_prg_aa_aa_nr='$db_prg_aa_aa_nr';
remoteblast='$remoteblast';
sequence_param='$sequence_param';
otherparams='&$word_size_aa&$expect&$defaultblastoptions';
curdirectory='$directory';
retrieve='$retrieve';
usenucleo='$usenucleo';
sf_filter=1;

//-->
</SCRIPT>
EOF

print <<EOF;
<script language="Javascript">
<!--
	var mywindows = new Array();   // This is required for the popups to work correctly w/ or w/out checkboxes shown
	function maxlist_warning(window_obj)
	{
EOF
if ($#outs + 1 > $MAX_LIST) {
	print <<EOF;
		window_obj.alert("This functionality is not available because the number of OUT files exceeds the current setting of MAX LIST ($MAX_LIST)");
		return false;
EOF
} else {
	print <<EOF;
		return true;
EOF
}
print <<EOF;
	}
//-->
</script>
EOF


##########
  ##
  ## Clone dir text (and lots of other stuff):
  ##

  if ($boxtype ne "HIDDEN") {

	print <<EOM;
<input type=hidden name="save_state" value=0>
<input type=hidden name="use_filter" value="$use_filter">
<input type=hidden name="filterstring" value="$filterstring">
<input type=hidden name="filterseq" value="$filterseq">
<input type=hidden name="filterz1" value="$filterz1">
<input type=hidden name="filterz2" value="$filterz2">
<input type=hidden name="filterz3" value="$filterz3">
<input type=hidden name="filterz4" value="$filterz4">
<input type=hidden name="filterz5" value="$filterz5">
<input type=hidden name="filtergbu1" value="$filtergbu1">
<input type=hidden name="filtergbu0" value="$filtergbu0">
<input type=hidden name="filtergbuminus1" value="$filtergbuminus1">
<input type=hidden name="filterScoresgtlt" value="$filterScoresgtlt">
<input type=hidden name="filterandor" value="$filterandor">
<input type=hidden name="filterXCorr" value="$filterXCorr">
<input type=hidden name="filterdCn" value="$filterdCn">
<input type=hidden name="filterSf" value="$filterSf">
<input type=hidden name="filterP" value="$filterP">
<input type=hidden name="filterSp" value="$filterSp">
<input type=hidden name="filterRSp" value="$filterRSp">
<input type=hidden name="filterMHplus" value="$filterMHplus">
<input type=hidden name="filterIons" value="$filterIons">
<input type=hidden name="filter_action" value="$filter_action">

<input type=hidden name="makefasta">
<input type=hidden name="includecontam">
<input type=hidden name="autoindex">
<input type=hidden name="copyhosts">
<input type=hidden name="clonedir">
<input type=hidden name="alldtas">
<input type=hidden name="includeouts">
<input type=hidden name="run">
<input type=hidden name="runhost">
<input type=hidden name="comments">
<input type=hidden name="op">
<input type=hidden name="refdir">
EOM

  }
  else { 
	  #print ("&nbsp;");
	  if ($pull_to_top) {
		#&button ("PULL_TO_TOP_OFF", "pulltotop_inverted",  90, 25);
		print qq(<INPUT TYPE=HIDDEN NAME="PULL_TO_TOP" VALUE="ON">);
	  } #else {
		#&button ("PULL_TO_TOP", "pulltotop",  90, 25);
	  #}
  }
print "</nobr>";

  my $w = 8; # width of a character, in pixels

  #&make_space(5);

  $BP_mode = "zBP" if (!defined $BP_mode);

  # added by LAB (lukas@pair) 8/20/01
  print <<EOF;
<SCRIPT language="Javascript">
<!--
function changedescrip(location,ref)
{
	if (document.mainform["differentdescrip:" + location]) {
		if (document.mainform["differentdescrip:" + location].value != ref) {
			document.mainform["differentdescrip:" + location].value = ref;
			document.mainform.svgh.name = "sort_Consensus";
			document.mainform.submit();
		}
	} 
}
//-->
</SCRIPT>
EOF

  $cellstartcode = "<td bgcolor=$button_background_color align=center width=";
  
  print '<nobr>';
  #print qq(<input name="svgh" type="hidden" value=1>);
  print "<table border=0 cellspacing=0 cellpadding=0 width=975><tr><td>";
  print "<table width=800 cellspacing=0 cellpadding=0 border=1 $button_table_border><tr height=$button_table_height><input name=\"svgh\" type=hidden value=1>";

  &make_table_button ("#", 28, "number");
  &make_table_button ("GBU", 24);
  &make_table_button ("$BP_mode", 48);
  &make_table_button ("Scan", 84);
  &make_table_button ("z", 15);
  &make_table_button ("dM", 33);
  &make_table_button ("MH+", 48, "mhplus");
  &make_table_button ("xC", 35);
  &make_table_button ("dCn", 35);
  &make_table_button ("Sp", 32);
  &make_table_button ("RSp", 30);
  &make_table_button ("Ions", 50);
  &make_table_button ("Sf", 34);
  &make_table_button ("P", 30);

  #print "<td width=30 bgcolor=$button_background_color align=center><span class=smallheading style=\"color:$button_font_color\">P</span></td>";
  my $widthsofar = 526;		# keep track of how wide table is.  update this number if the above widths change

  if ($boxtype ne "HIDDEN") {
	#print "<td width=25 bgcolor=$button_background_color>&nbsp;";
	#print "</td>";
	&make_table_button ("Sel", 28, "ckbox");
	$widthsofar += 28;
  }
  $w = 7.5;
  my $reftwidth = $w * ($reflen + 2);
  $widthsofar += $reftwidth;
  &make_table_button ("Reference", $reftwidth);

  #&make_table_button ("()", $w * 2, "parens");
  &make_table_button ("()", 15, "parens");
  $widthsofar += 15;

  
  #&make_table_button ("Sequence", $w * 16);

  my $extrawidth = 800 - $widthsofar;
  &make_table_button ("Sequence", $extrawidth);
  #$widthsofar += 128;
  
  
  print "</tr></table>";
  print "</td><td width=10>&nbsp;</td><td>";
  print "<table border=1 cellspacing=0 cellpadding=0 $button_table_border><tr height=$button_table_height>";
  #print "</td><td width=12>&nbsp;</td>";
  #print "<td width=80>";
  &make_table_button ("Consensus", 80);
  #&make_image_button ("Consensus");
  #print "</td><td>";
  print "</tr></table></td><td width=10></td><td>";
  print qq(<span class="smallheading">Depth:&nbsp;&nbsp;</span>);
  print qq(<INPUT TYPE=TEXT NAME="max_rank" SIZE=2 MAXLENGTH=2 VALUE="$MAX_RANK" $dropbox_style>);


  print "</td></tr></table>";

  print ("</nobr>\n");
## end replaced with ##

  # expand/contract buttons added by SDR
  # moved by LAB
  print <<EOF;
  <table border=0 bordercolor="black" cellspacing=0 cellpadding=0 width=100%>
<tr align=left bgcolor="#FFFFFF">
EOF

$sort = &find_sort_value();
if ($sort eq "consensus") {
	if ($DEFS_RUNSUMMARY{"Consensus group view"} eq "expanded") {
		print <<EOF;
<td width=10><img src="/images/tree_open.gif" id="firstToggle" onclick="javascript:toggleAll(this)" style="cursor:hand" act="contractall"></td>
<td width=2></td>
<td width=10><img src="/images/tree_closed.gif" id="secondToggle" onclick="javascript:toggleAll(this)" style="cursor:hand;display:none;" act=""><hr id=hr1></td>
<td width=2><hr id=hr2 width=100%></td>
<td width=755><hr></td>
<td width=2></td>
<td valign=center width=112><a onclick="javascript:toggleSFFilter()" style="cursor:hand; font-size:xx-small" id="sffiltertoggle" title="Hide groups with score <= $score_threshold or < $NUMFILES_GREATER_THAN sequences"><span style="color:blue">consensus filter:</span> $consensus_filter_mode</a></td>
<td width=2></td>
<td width=13><hr></td>
<td width=2></td>
<td valign=center width=30><a onclick="javascript:toggle_advanced_consensus_stuff()" style="cursor:hand; font-size:xx-small; color:blue" id="advcontoggle" title="Toggle display of advanced consensus group information">$consensus_view_mode</a></td>
<td width=2></td>
EOF
	} else {
		print <<EOF;
<td width=10><img src="/images/tree_closed.gif" id="firstToggle" onclick="javascript:toggleAll(this)" style="cursor:hand" act=""></td>
<td width=2></td>
<td width=10><img src="/images/tree_open.gif" id="secondToggle" onclick="javascript:toggleAll(this)" style="cursor:hand;display:none;" act="contractall"><hr id=hr1></td>
<td width=2><hr id=hr2 width=100%></td>
<td width=755><hr></td>
<td width=2></td>
<td valign=center width=112><a onclick="javascript:toggleSFFilter()" style="cursor:hand; font-size:xx-small" id="sffiltertoggle" title="Hide groups with score <= $score_threshold or < $NUMFILES_GREATER_THAN sequences"><span style="color:blue">consensus filter:</span> $consensus_filter_mode</a></td>
<td width=2></td>
<td width=13><hr></td>
<td width=2></td>
<td valign=center width=30><a onclick="javascript:toggle_advanced_consensus_stuff()" style="cursor:hand; font-size:xx-small; color:blue" id="advcontoggle" title="Toggle display of advanced consensus group information">$consensus_view_mode</a></td>
<td width=2></td>
EOF
	}
} else {
	&print_hidden_expand_state_inputs();
}
print <<EOF;
<td><hr></td>
</tr>
</table>
EOF

}


## arguments are, in order:
## $name - name of sort process for this button for the form in which it is contained
## $label - name of image and value of the button in this form
## $width - width of button
## $height - height of button
##
## this outputs the HTML for this image-based submit button, specifically for a button
## that is used for the sorting processes.

sub button {
  my ($label, $width, $height, $name);
  my ($url);

  $name = shift;
  $label = shift;
  $width = shift;
  $height = shift || 25;

  my ($nicelabel);
  ($nicelabel = $label) =~ s!_inverted!!;

  if ($use_buttonmaker) {
    $url = "$buttonmaker?width=$width&height=$height&text=$label";
  } else {
    $url = "$webimagedir/$label.gif";
  }
  print qq(<INPUT TYPE="IMAGE" NAME="$name" VALUE="$nicelabel" BORDER=0 ALIGN=$DEF_IMG_ALIGN WIDTH="$width" HEIGHT="$height" SRC="$url" ALT="$nicelabel">);
}

## arguments are, in order:
## $label - name of image and value of the button in this form
## $width - width of button
## (optional) $name - name of button for the form in which it is contained
## (optional) $height - height of button
##
## this outputs the HTML for this image-based submit button

sub make_sort_button {
  my ($label, $width, $height, $name);
  my ($next, $url, $temp);

  $label = shift;
  $width = shift;

  $next = shift;
  if ($next =~ m!^\d+$!) {
    $height = $next;
    $name = shift;
  } else {
    $name = $next;
  }
  $height ||= 25;
  $name ||= $label;

  # check if this button is the current sort
  # we can invert the button in that case

  ($temp = $name) =~ tr/A-Z/a-z/;
  $temp =~ s!\s!!g;
  my $is_curr_sort = ($temp eq $sort);

  $width = int ($width + 0.5);
  $height = int ($height + 0.5);

  $label = &url_encode ($label);
#  $name = &url_encode ($name) if $name;

  if ($use_buttonmaker) {
    $url = "$buttonmaker?width=$width&height=$height&text=$label";
    $url .= "&inverted=true" if ($is_curr_sort);
  } else {
    $url = "$webimagedir/$name.gif";
    $url = "$webimagedir/${name}_inverted.gif" if ($is_curr_sort);
  }

  print qq(<INPUT TYPE="IMAGE" NAME="sort_$name" BORDER=0 ALIGN=$DEF_IMG_ALIGN WIDTH="$width" HEIGHT="$height" SRC="$url" ALT="$label">);
}

# this function does the same thing, using table cells rather than images
sub make_table_button {
  my ($label, $width, $height, $name);
  my ($next, $url, $temp);

  $label = shift;
  $width = shift;

  $next = shift;
  if ($next =~ m!^\d+$!) {
    $height = $next;
    $name = shift;
  } else {
    $name = $next;
  }
  $height ||= 25;
  $name ||= $label;

  # check if this button is the current sort
  # we can invert the button in that case

  ($temp = $name) =~ tr/A-Z/a-z/;
  $temp =~ s!\s!!g;
  my $is_curr_sort = ($temp eq $sort);

  $width = int ($width + 0.5);
  $height = int ($height + 0.5);

  #$label = &url_encode ($label);		# I don't see why url encoding is necessary for the label - it just messes up the text
  #$label = "#" if ($label eq "%23");

  my $sname = "sort_$name";
  my $scolor = $is_curr_sort ? $button_selected_font_color : $button_font_color;
  my $sbgcolor = $is_curr_sort ? $button_selected_background_color : $button_background_color;


  print <<EOF;
<td bgcolor=$sbgcolor align=center width=$width id="$sname" style="cursor:hand; color:$scolor" onclick="adjustSortValue('$sname');" onmouseover="this.bgColor='$button_mouseover_background_color'; this.style.color='$button_mouseover_font_color';" onmouseout="this.bgColor='$sbgcolor'; this.style.color='$scolor';">
<span class=smallheading>$label</span></td>
EOF
}

sub make_image_button {
  my ($label, $name);
  $label = shift;
  $name ||= $label;

  # check if this button is the current sort
  # we can invert the button in that case
  ($temp = $name) =~ tr/A-Z/a-z/;
  $temp =~ s!\s!!g;
  my $is_curr_sort = ($temp eq $sort);
  $label = "#" if ($label eq "%23");

  my $imgpath = $is_curr_sort ? "$webimagedir/$name-new.gif" : "$webimagedir/${name}-new_inverted.gif";
  my $overpath = $is_curr_sort ? "$webimagedir/$name-new_over.gif" : "$webimagedir/${name}-new_inverted_over.gif";
  my $sname = "sort_$name";

  print qq(<img src="$imgpath" border=0 alt="$label" style="cursor:hand" onClick="adjustSortValue('$sname');" onMouseover="this.src='$overpath';" onMouseout="this.src='$imgpath';">);

}


##
## added by cmw (2/13/00)
## modified by ben guaraldi (10/24/02)
## evaluates filter conditions to determine whether a specific line of data should be displayed/checked
##

sub pass_filter {

# We're using this function to filter by ors or ands.  The upshot is that if $conj is "or", 
# then the filter lets it through if it passes any test.  If $conj is "and", then the filter
# stops it if it fails any test.  $not is a reference to a function that reverse or keeps the same
# boolean value of the test.  $return is what we return if the test is passed/failed.  $endreturn
# is what we return at the end if it passes/fails all the tests.

	my $return, $endreturn, $not;
	my %contents = @_;

	if ($filterandor eq "and") {
		$return = 0;
		$endreturn = 1;
		$not = "reverse";
	} else {
		$return = 1;
		$endreturn = 0;
		$not = "keepsame";
	}

	my $fullstring = join("", values %contents);

	# Remove regexps from search strings.
	($filterstring_safe = $filterstring) =~ s/([\W])/\\$1/g if (!defined $filterstring_safe);
	($filterseq_safe = $filterseq) =~ s/([\W])/\\$1/g if (!defined $filterseq_safe);

	# Filter by string in entire line
	if ($filterstring_safe =~ /\S/) {
		return $return if (&$not($fullstring =~ /$filterstring_safe/));
	}

	# Filter by string in sequence
	if ($filterseq_safe =~ /\S/) {
		return $return if (&$not($contents{"Seq"} =~ /$filterseq_safe/));
	}

	# Filter by gbu score
	if( $filtergbu1 or $filtergbu0 or $filtergbuminus1){
		unless (&$not($contents{"z"} > 2)) {
			return $return;
		}
		unless (&$not($contents{"gbu"} == 1)) {
			return $return if (&$not($filtergbu1));
		}
		unless (&$not($contents{"gbu"} == 0)) {
			return $return if (&$not($filtergbu0));
		}
		unless (&$not($contents{"gbu"} == -1)) {
			return $return if (&$not($filtergbuminus1));
		}
	}
	

	# Filter by charge state
	my @allowed_z = ();
	foreach (1..5) {
		$allowed_z[$_] = 1 if (${"filterz$_"});
	}
	if (@allowed_z) {
		return $return if (&$not(($allowed_z[$contents{"z"}]) || (($allowed_z[5]) && ($contents{"z"} > 4))));
	}

	# Filter by various Scores
	my $greater_than  = ($filterScoresgtlt eq "gt");

	# Turn Ions content into percentage for comparison with filter input
	$contents{"Ions"} =~ m!(\d+)/(\d+)!;
	$contents_Ions = $2 ? ($1 / $2) * 100 : 0;

	my @filterscores = ($filterXCorr,$filterdCn,$filterSp,$filterRSp,$filterMHplus,$filterIons,$filterSf,$filterP);
	my @actualscores = ($contents{"Xcorr"},$contents{"deltaCn"},$contents{"Sp"},$contents{"RSp"},$contents{"mass"},$contents_Ions,$contents{"Sf"},$contents{"P"});

	foreach $i (0..$#filterscores) {
		# ignore this value if filter input is blank
		next unless ($filterscores[$i]);
		# remove any non-numerical characters
		$actualscores[$i] =~ s/[^\d\.e]//g;
		if ($greater_than) {
			return $return if (&$not($actualscores[$i] > $filterscores[$i]));
		} else {
			return $return if (&$not($actualscores[$i] < $filterscores[$i]));
		}
	}

	# Either passed all tests or failed all tests.
	return $endreturn;

	sub reverse {
		return (not $_[0]);
	}

	sub keepsame {
		return $_[0];
	}

}


##
## this subroutine outputs a summary line for each .out file
## not very intelligent, yet.
##
sub print_data {
  my ($rank, $lastrank, $ref, $i, $num);
  my ($noconsensus,$filterthisgroup);

  ## find out how many files are in each consensus:
  my (@BPsum, @num_files_in_rank, @SFsum, @SFscores, $BPsum_noconsensus, $num_files_noconsensus, @ranks_to_skips);
  
  if ($is_cons_sort) {
	my $number_; 
    $lastrank = -2;
    foreach $file (@orderedouts) {
      $i = $number{$file};
      $rank = $ranking[$i];
      $rank = -1 if (!defined $rank);
	  $number_ = $i + 1; 
      if ($rank != $lastrank) {
		if ($lastrank >= 0) {
	        $num_files_in_rank[$lastrank] = $n;
		} else {
			$num_files_noconsensus = $n;
		}
        $n = 0;
      }
	  ($file_trunc = $file) =~ s/..$//;
	  if ($rank >= 0) {
	      $BPsum[$rank] += $BP{$file} unless ($summed{$file_trunc});
		  $SFsum[$rank] += $combinedscores{"$file.dta"}; 
		  $SFscores[$rank] .= ($combinedscores{"$file.dta"} . " ") unless ($pull_to_top and $level_in_file{"$i:$consensus_groupings[$rank]"} != 1);
	  } else {
		  $BPsum_noconsensus += $BP{$file} unless ($summed{$file_trunc});
		  $SFsum_noconsensus += $combinedscores{"$file.dta"};
		  $SFscores_noconsensus .= ($combinedscores{"$file.dta"} . " ");
	  }
	  # prevent same scan (with different charges) from being counted more than once
	  $summed{$file_trunc} = 1;
	  $lastrank = $rank;
      $n++;
    }
	if ($lastrank >= 0) {
		$num_files_in_rank[$lastrank] = $n;
	} else {
		$num_files_noconsensus = $n;
	}
  }

  $lastrank = -2; # we need a start sentinel value that is NOT -1!
  
  $noconsensus = 0;
  $n = 0;
  $outfile_count = -1;
  $group_count = -1;
  $openspan = 0;  # i'm so ashamed of this hack, i'm not going to identify myself -anon
  $filterthisgroup = 0;

  print <<EOF;
<script language="Javascript">
<!--
EOF
  print qq(var expandAndContract = new Array();\n);
  print qq(var filteredGroups = new Array();\n);
  print qq(var expanded = 0;\n);
  print <<EOF;
//-->
</script>
EOF

  my $grouprank = -1; #SDR: Used to determine the index to use in the javascript array expandAndContract for the no group items
  foreach $file (@orderedouts) {
	$outfile_count++;
	$i = $number{$file};
	# if this is high ranking, make it bold and colourful
	$rank = $ranking[$i];
	if (!defined $rank) {
		$rank = -1;
		if (!$notnew) {
			# ungrouped outs are unchecked by default
			$selected{$outs[$i]} = "";
		}
	}

	## if this is a consensus grouping, and we have moved on to
    ## the next group, make some space and print a header:
    if (($is_cons_sort) && ($rank != $lastrank)) {

     if ($lastrank != -2) {
		print("</span>"); # close the span tag enclosing all the datalines from the previous group
	 }

	  if ($filterthisgroup) {
		  print qq(</span>);
      }

	  if ($rank > -1) {
		  $SFscores[$rank] =~ s/ *$//;
	  }

	  if ($consensus_filter_mode eq "on") {
		  $filter_display_str = "display:none";
	  } else {
		  $filter_display_str = "";
	  }

	  # filter groups that don't meet the score threshold
	  if ($rank > -1 && $SFscores[$rank]) {
		@thesesfscores = split / /, $SFscores[$rank];
		$max_isf = scalar @thesesfscores;
		$SFsigma = 0;
		for ($i_SF = 0; $i_SF < $max_isf ; $i_SF++) {
			#$SFmedian = $SFscore_list[$i_SF] if($i_SF <= $max_isf / 2);
			$SFsigma += $thesesfscores[$i_SF];
		}
		if ($SFsigma < 10) {
		   $thissfsum = &precision ($SFsigma, 2);
		} elsif ($SFdisplay < 100) {
		   $thissfsum = &precision ($SFsigma, 1);
		} else {
		   $thissfsum = &precision ($SFsigma, 0);
		}
		if ($thissfsum <= $score_threshold or $num_files_in_rank[$rank] < $NUMFILES_GREATER_THAN) {
			$filterthisgroup = 1;
			print qq(<span id="sf_filter_$rank" style="$filter_display_str">);
		} else {
		  $filterthisgroup = 0;
	    }
	  } elsif ($rank > -1 and (($num_files_in_rank[$rank] < $NUMFILES_GREATER_THAN) || (scalar(keys %combinedscores) && !($reallynocombinedscores)))) {
		  $filterthisgroup = 1;
		  print qq(<span id="sf_filter_$rank" style="$filter_display_str">);
	  } else {
		  $filterthisgroup=0;
	  }

      # if not the first group, make some space:
      if ($lastrank != -2) {
		#print("<font size=-3>");
        #&make_space (5);
		#print("</font>");
		print qq(<table cellspacing=0 cellpadding=0 border=0 width=20><tr height=5><td></td></tr></table>);
      }

	  my $boxhtml = "";

      if ($boxtype ne "HIDDEN") {

		# this is kind of a hack, but useful: if you click this button, a JavaScript
        # function selects or deselects all OUT file checkboxes for this consensus:

		$num_files_in_group = ($rank != -1) ? $num_files_in_rank[$rank] : $num_files_noconsensus;
		$group_count++;

		$allselected = 1;
		for $ii ($outfile_count..($outfile_count + $num_files_in_group - 1)) {
			unless ($selected{$orderedouts[$ii]}) {
				$allselected = 0;
				last;
			}
	    }
	    $checked = ($allselected) ? " CHECKED" : "";
		$boxhtml = qq(<INPUT TYPE=CHECKBOX class="check" NAME="group_select" VALUE="$group_count" onClick="groupSelect($group_count)"$checked>);
		$boxhtml .= qq(<INPUT TYPE=HIDDEN NAME="group_select$group_count" VALUE="$outfile_count">);
      }

      if ($rank != -1) {
        $ref = $consensus_groupings[ $rank ];

		# SDR: Needed for expand/collapse all
		print <<EOF;
<script language="Javascript">
<!--
EOF
		print qq(expandAndContract[$rank] = "$ref";\n);
		if ($filterthisgroup) {
			print qq(filteredGroups[filteredGroups.length] = "sf_filter_$rank";\n);
		}
	    print <<EOF;
//-->
</script>
EOF
		&print_one_consensus ("ref" => $ref, with_others => 0, BPsum => $BPsum[$rank], SFsum => $SFsum[$rank], SFscores => $SFscores[$rank],
                              numfiles => $num_files_in_rank[$rank], checkboxhtml => $boxhtml, groupnumber => $group_count);

		$refwith = $ref . "_";
		
		if ($DEFS_RUNSUMMARY{"Consensus group view"} eq "expanded" || $FORM{"expand_$ref"} eq "expanded") {
			print ("<span id=\"$refwith\">");
		} else {
			print ("<span id=\"$refwith\" style=\"display:none\">");
		}

		$openspan = 1;
		$grouprank = $rank; #SR: Kludge to get the last value for the javascript array so I can put nogroup in it orderly
      } else {
		if ($openspan) {
			print ("</span>");
		}

		# SDR: Needed for expand/collapse all
		print <<EOF;
<script language="Javascript">
<!--
EOF
        #print qq(expandAndContract[$grouprank+1] = "nogroupgroup";\n);
		print "expandAndContract[" . ($grouprank+1) . qq(] = "nogroupgroup";\n);
		#print qq(expanded = expandAndContract.length;\n);  #why?
	    print <<EOF;
//-->
</script>
EOF

		my $purplec = "#800080";
		my $redc = "#ff0000";
		my $tsb = 35;
		my $tss = 8;
		print qq(<table width=975 border=0 cellspacing=0 cellpadding=0><tr $table_heading_color valign=top><td class=smalltext width=5>);
		print $boxhtml;
		
		print "</td><td width=8 valign=middle class=\"smalltext\">";

		if ($DEFS_RUNSUMMARY{"Consensus group view"} eq "expanded" || !$num_files_in_rank[0] || $FORM{'expand_nogroupgroup'} eq "expanded") {
			print ("<img src=\"/images/tree_open.gif\" id=\"nogroupgroup\" onclick=\"javascript:toggleGroupDisplay(this)\" style=\"cursor:hand\">");
			print qq(<input name="expand_nogroupgroup" type="hidden" value="expanded">);
		} else {
			print ("<img src=\"/images/tree_closed.gif\" id=\"nogroupgroup\" onclick=\"javascript:toggleGroupDisplay(this)\" style=\"cursor:hand\">");
			print qq(<input name="expand_nogroupgroup" type="hidden" value="collapsed">);
		}

		print "</td><td width=15 class=\"smalltext\">";
		print "&nbsp;&ndash;";
		print "</td><td width=290 class=\"smalltext\">";
		print "No Group";
		print "</td>";

		#print ("<span class=\"smalltext\" style=\"font-family:verdana\"><U> - No Group&nbsp;&nbsp;&nbsp;&nbsp;");   #formerly in <tt> tags

		$noconsensus=1;


		$BPsum = $BPsum_noconsensus;
		$BPsum_sci = &sci_notation($BPsum);
		$numfiles = $num_files_noconsensus;
		if ((defined $BPsum) && (defined $numfiles)) {
			#$BPperc = ($BPTot != 0) ? int((100 * $BPsum_sci/$BPTot) + 0.5) : 0;
			$BPperc = ($BPTot != 0) ? (100 * $BPsum_sci/$BPTot) : 0;
			$colorsandvalues{"nogroup"} = $BPperc;		# used for setting colors in the piechart applet
			$BPperc = int($BPperc + .5);

			$BPavg = &sci_notation($BPsum / $numfiles);
			$numfiles = "<span style=\"color:'$redc'\"><b>" . $numfiles . "</b></span>" if $numfiles >= $NUMFILES_GREATER_THAN;
			
			#print ($s, &precision($SFsum_noconsensus,2), "|", $numfiles, "|$BPsum_sci|$BPperc%");

			print <<EOF;
<td width=65 class=smalltext>
<span style="color:'$purplec'">Sequences</span>:</td><td align=center width=28 class=smalltext>$numfiles
</td><td width=$tsb></td>	
EOF
		}
		print "<td width=70 class=smalltext>";

		#calculate mean and meadian Sf for the noconcensus group and display them
		my($i_SF,$SFsigma,$SFmean,$SFmedian,$max_isf,@SFscore_list);
		$SFsum = $SFsum_noconsensus;
		if($SFsum){
			#@SFscore_list =  sort {$a <=> $b} split / /, $SFscores_noconsensus;
			@SFscore_list = split / /, $SFscores_noconsensus;
			$max_isf = scalar @SFscore_list;
			for ($i_SF = 0; $i_SF < $max_isf ; $i_SF++) {
				#$SFmedian = $SFscore_list[$i_SF] if($i_SF <= $max_isf / 2);
				$SFsigma += $SFscore_list[$i_SF];
			}
			$SFmean = $max_isf ? $SFsigma / $max_isf : 0;
			$SFmean = &precision($SFmean, 2);
			#$SFmedian = &precision($SFmedian, 2);
			#$SFmean = "<span style=\"color:'$redc'\"><b>" . $SFmean . "</b></span>" if $SFmean >= $SF_BOLD_IF_GREATER_THAN;
			#$SFmedian = "<b>" . $SFmedian . "</b>" if $SFmedian >= $SF_BOLD_IF_GREATER_THAN;
			$SFdisplay = $SFsigma;
			if ($SFdisplay < 10) {
			   $SFdisplay = &precision ($SFsigma, 2);
			} elsif ($SFdisplay < 100) {
			   $SFdisplay = &precision ($SFsigma, 1);
			} else {
			   $SFdisplay = &precision ($SFsigma, 0);
			}
			$SFdisplay = "<span style=\"color:'$redc'\"><b>" . $SFdisplay . "</b></span>" if $SFdisplay >= $SF_BOLD_IF_GREATER_THAN;

			#print("$SFmean|$SFsigma", "&nbsp;" x 3);
			print qq(<span style="color:'$purplec'">Score</span>:&nbsp;);
			print "$SFdisplay";
			print "</td><td width=$tsb></td>";
		}
		if ((defined $BPsum) && (defined $numfiles)) {
			print <<EOF;
<td width=25 class="smalltext">
<span style="color:'$purplec'">TIC</span>:</td><td align=right width=28 class="smalltext">$BPperc%
</td><td width=$tss class="advconstuff"></td><td width=14 class="smalltext advconstuff">
<span style="color:'$purplec'">&Sigma;</span>:</td><td width=40 class="smalltext advconstuff">$BPsum_sci
</td><td width=$tss class="advconstuff"></td><td width=28 class="smalltext advconstuff">
<span style="color:'$purplec'">Avg</span>:</td><td width=40 class="smalltext advconstuff">$BPavg
</td><td width=$tsb class="advconstuff"></td><td class=smalltext>&nbsp;</td>
EOF
		}
		print "</tr></table>\n";

		#print "</U></span><BR>\n";
		if ($DEFS_RUNSUMMARY{"Consensus group view"} eq "expanded" || !$num_files_in_rank[0] || $FORM{'expand_nogroupgroup'} eq "expanded") {
			print ("<span id=\"nogroupgroup_\">");
		} else {
			print ("<span id=\"nogroupgroup_\" style=\"display:none\">");
		}

      }
    }

    ## we print a reference description for the first $NUMDESCRIPS OUT
    ## files not belonging to any consensus:
    if ($noconsensus) {
	$n++;
    }

    ## if this is a consensus sort, and we are not in the no
    ## consensus zone, have the called subroutine make the
    ## peptide and reference printed agree with this reference.
    ## otherwise, just print the top reference.
    if ($is_cons_sort && ($rank != -1)) {
      $num = $level_in_file{"$i:$ref"};

	  if (!$notnew && $explicit_group_deselect[$rank]) {
		$selected{$outs[$i]} = "";
	  }

      ## If the checkbox is set to bring up the dataline from within lower levels of .out file
      ## to agree with given consensus, we do so. However, normally, we print the peptide, ion ratio,
      ## etc. for the top line of the .out file even if the peptide for this consensus is not the top
      ## one in the .out file.

      if ($pull_to_top) {
          if (&print_one_dataline ("index" => "$i:$num", rank => $rank, printdescrip => 0, preferred_ref => $ref) == -1) {
			  if ($openspan) {
				  $openspan = 0;
				  print("</span>");  
			  }
			  return;
		  }
      } else {
          if (&print_one_dataline ("index" => "$i:1", rank => $rank, printdescrip => 0) == -1) {
			  if ($openspan) {
				  $openspan = 0;
				  print("</span>");
			  }
		    return;
		  }
      }

    ## for ungrouped OUTs or in non-consensus mode, we just use the top line of the .out file:
    } else {
        $num = 1;
        if (&print_one_dataline ("index" => "$i:$num", rank => $rank, printdescrip => ($noconsensus && ($n <= $NUMDESCRIPS))) == -1) {
			if ($openspan) {
				  $openspan = 0;
				  print("</span>");
			}
   		  return;
		}
    }

    $lastrank = $rank;
  }
  if ($openspan) {
	  $openspan = 0;
	  print("</span>");
  }
}

## &print_one_dataline outputs one line, corresponding to the data for the "index" arg.
## args as follows (passed as a hash)
## index		-- used for the data. Normally, we just display the data for the top line of the OUT file, which
##			   corresponds to an index for "$filenum:1", where $filenum is the number for this OUT file.
## rank		-- the rank of this OUT file's consensus grouping
## printdescrip	-- true if and only if we should print out a descriptor line for the protein reference
## no_hyperlinks	-- true if we should output no hyperlinks (other HTML code, such as bolding, okay)
## Returns -1 if $MAX_LIST lines are displayed

my $count=0;
sub print_one_dataline {
  $count++;
  if ($count > $MAX_LIST && $MAX_LIST > 0) {
	print "<p>$ICONS{'warning'}Only the first $MAX_LIST datalines are displayed.  To see more, increase the <b>Max list</b> value.</p>";
	return -1;
  }
  my (%args) = @_;
  my ($index, $rank, $printdescrip, $preferred_ref, $no_hyper) =
	($args{"index"}, $args{"rank"}, $args{"printdescrip"}, $args{"preferred_ref"}, $args{"no_hyperlinks"});

  my ($i, $num, $url, $line, $file, $ref);
  my ($name, $z, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions, $Ions_NoJS, $Ref, $Seq, $Seq_NoJS, $BP);
  my ($dbpepurl, $disppepurl, $blasturl, $blasturl_NoJS);
  my ($filenumstr, $plainfilenum);

  my (%plain_contents);
  #### filtering feature added 1/16/00 by cmw: 
  #### the hash %plain_contents will contain the non-HTML-formatted contents of the dataline, one field at a time
  
  # $start, $end bound each piece of data
  # $start_l is a left-aligned version of $start
  # $startline, $endline bound each line
  # $s is our space-separator char
  #
  my ($startline, $divider, $endline, $s);

  $startline = "<TT style=\"font-size:12\"><NOBR>";       # font changed, this line used to be  $startline = "<TT><NOBR>";	
  $endline = "</NOBR></TT><BR>\n";
  $divider = " ";
  $s = "&nbsp;";
  
  ($i, $num) = $index =~ m!(\d+):(\d+)!;

  $file = $outs[$i];
  $filenumstr = &precision ($i+1, 0, 4, $s);
  $plainfilenum = $i+1;
  $plain_contents{"filenum"} = $filenumstr;

  if ($rank != -1) {										# -1 is the 'no group' rank
    my $colour = $rank_colour[$rank];
    $filenumstr = qq(<span style="color:$colour"><b>$filenumstr</b></span>);
  }

  $Seq = $peptide{$index};
  $plain_contents{"Seq"} = $Seq;

  ($disppepurl, $dbpepurl, $blasturl, $blasturl_NoJS) = &URLs_of_seq ($Seq, $file);

  # calculate URL for showing .out file
  $url = "$showout?OutFile=" . &url_encode("$seqdir/$directory/$file.out") . "&dbdir=" . &url_encode("$dbdir");
  ($name, $z) = $file =~ m!\.(\d+\.\d+)\.(\d)$!;

  $plain_contents{"z"} = $z;

  if($z == 1 or $z == 2){	
	$plain_contents{"gbu"} = $gbuscores{"$file.dta"};
  } else{
	$plain_contents{"gbu"} = "nonexistant";
  }

  $plain_contents{"Sf"} =  &precision($combinedscores{"$file.dta"},2);	# unfortunately, the filter ignores values of zero, so we have to make this nonzero

  # color-code charges
  $zdisplay = $z;
  $zcolor = $zcolors[ ($z > 3 ? 2 : $z - 1) ];
  $zdisplay = qq(<span style="color:$zcolor">$zdisplay</span>);
  # boldface if multiple charge states exist (Edward 9/6/2001)
  CHARGES: foreach $otherz ((1, 2, 3, 4, 5)) {
	next if $z == $otherz;
	(my $otherfile = $file) =~ s/\d$/$otherz/;
	if (grep {$otherfile eq $_} @outs){
		$zdisplay = "<b>$zdisplay</b>" ;
		last CHARGES;
	}
  }

  if ($name =~ m!^(\d+)\.\1$!) {
    # truncate single scans
	$name = $1;
  } else {
    $name =~ s!\.!-!; # make dots into dashes
  }
  
  $plain_contents{"name"} = $name;
  unless ($no_hyper) { $name = qq(<a target="_blank" href="$url">$name</a>); }
  $name = ($s x (11 - length($plain_contents{"name"}))) . $name;

  # 29.3.98: changed by Martin to make $mass reflect the experimental mass
  # and delta-M to be the deviation between that and the calculated mass of
  # the peptide:
  $delM = &precision ($MHplus{$index} - $mass_ion[$i], 1, 2, $s);
  $plain_contents{"delM"} = $delM;

  $mass = &precision ($mass_ion[$i], 1, 4, $s);
  $plain_contents{"mass"} = $mass;

  # 29.3.98: changed by Martin to only 2 significant digits:
  $Xcorr = &precision ($C10000{$index}, 2, 1, "0");
  $plain_contents{"Xcorr"} = $Xcorr;
  $Xcorr = "<b>$Xcorr</b>" if ($C10000{$index} >= $XCORR_THRESH);

  # adding an open span tag in front of $Xcorr and closing it after $RSp means only one tag needs to be added to turn all four values grey
  $Xcorr = qq(<span style="color:'$deemphasized_grey'">) . $Xcorr;

  # 29.3.98: changed by Martin to only 2 significant digits:
  # quick fix by Martin so that deltaCn dredged up from lower levels in the
  # out files don't give erroneous, positive values: 98/07/12:
  if ($num != 1) {
    $deltaCn = "----";
	$plain_contents{"deltaCn"} = $deltaCn;
  } else {
    $deltaCn = &precision (get_delCn($index), 2, 1, "0");
	$plain_contents{"deltaCn"} = $deltaCn;
    $deltaCn = "<b>$deltaCn</b>" if (get_delCn($index) >= $DELTACN_THRESH);
  }

  # 29.3.98: changed by Martin to NO significant digits:
  $Sp = &precision ($Sp{$index}, 0, 4, $s);
  $plain_contents{"Sp"} = $Sp;
  $Sp = "<b>$Sp</b>" if ($Sp{$index} >= $SP_THRESH);

  $RSp = &precision ($rankSp{$index}, 0, 3, $s);
  $plain_contents{"RSp"} = $RSp;
  $RSp = "<b>$RSp</b>" if ($rankSp{$index} <= $RSP_THRESH);

  # here we close the span tag that was opened before $Xcorr:
  $RSp .= "</span>";

  $plain_contents{"Ions"} = $ions{$index};
  $Ions = "$s" x (6 - length($ions{$index}));
  if ($no_hyper) {
    $Ions .= $ions{$index};
  } else {
    # calculate URL for displaying ions:
    $url = "$displayions?$disppepurl";
	
	# isolate the individual variables from the url to send to javascript:
	$jsdsite = ($disppepurl =~ /dsite=([^&]+)/i) ? $1 : "";
	$jsdmass1 = ($disppepurl =~ /dmass1=([^&]+)/i) ? $1 : "";
	$jsdmass2 = ($disppepurl =~ /dmass2=([^&]+)/i) ? $1 : "";
	$jsdmass3 = ($disppepurl =~ /dmass3=([^&]+)/i) ? $1 : "";
	$jsdmass4 = ($disppepurl =~ /dmass4=([^&]+)/i) ? $1 : "";
	$jsdmass5 = ($disppepurl =~ /dmass5=([^&]+)/i) ? $1 : "";
	$jsdmass6 = ($disppepurl =~ /dmass6=([^&]+)/i) ? $1 : "";
	$jsdmass7 = ($disppepurl =~ /dmass7=([^&]+)/i) ? $1 : "";
	$jsdmass8 = ($disppepurl =~ /dmass8=([^&]+)/i) ? $1 : "";

	

	$jspep = ($disppepurl =~ /pep=([^&]+)/i) ? $1 : "";
	$jsfile = $file;
	$jsnumaxis = ($disppepurl =~ /numaxis=([^&]+)/i) ? $1 : "";
	$jsmasstype = ($disppepurl =~ /masstype=([^&]+)/i) ? $1 : "";
	$jsiseries = ($disppepurl =~ /iseries=([^&]+)/i) ? $1 : "";
	$jsmassc = ($disppepurl =~ /massc=([^&]+)/i) ? $1 : "";

	$Ions_NoJS = $Ions;  # the _NoJS variables are used for DTAVCR
    $Ions_NoJS .= qq(<a target="_blank" href="$url">$ions{$index}</a>);

	$Ions .= qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="IonsGoTo('DisplayIons');" onmouseover="SetIonsVariables(this, '$jspep', '$jsfile', '$jsnumaxis', '$jsmasstype', '$jsiseries', '$jsmassc', '$jsdsite', '$jsdmass1', '$jsdmass2', '$jsdmass3', '$jsdmass4', '$jsdmass5', '$jsdmass6', '$jsdmass7', '$jsdmass8');" onmouseout="clearTimeout(PopupAppear); HideChoices('IonsMenu', event.x, event.y);">$ions{$index}</span>);



	# save this URL for DTA VCR
	$dta_vcr_url = $url;

  }

  # if asked, use the reference given us. Otherwise, use the usual value:
  $ref = $preferred_ref || $ref{$index};
  $plain_contents{"Ref"} = $ref;

  # calculate URL for reference:
  if ($no_hyper) {
    $Ref = $ref;
  } else {
    $url = "$retrieve?Ref=$ref";
    $url .= "&" . $dbpepurl;
	$url .="&Dir=" . $directory;

    $Ref_NoJS = qq(<a target="_blank" href="$url">$ref</a>);
	my $noDirURL = "Ref=" . $ref . "&" . $dbpepurl;   # the directory is not included here, will be added by javascript

	my $dbpepurl_plain;
	($dbpepurl_plain = $dbpepurl) =~ s/%([A-F0-9][A-F0-9])/pack("C", hex($1))/gie;
	$dbpepurl_plain =~ /db=([^&]+)/i;
	my $databasepath = $1;
	$dbpepurl_plain =~ /nucdb=([^&]+)/i;
	my $is_nucleo = ($1) ? $1 : 0;
	$dbpepurl_plain =~ /masstype=([^&]+)/i;
	my $masstype = $1;
	$dbpepurl_plain =~ /pep=([^&]+)/i;
	my $peplist_sp = $1;					# note: this should still contain mod site characters, if they exist

	#$peplist_sp =~ tr/\+/ /;

	# the order of elements in this array is important to the ref JS functions!
	my $refarray = qq(new Array('$databasepath', '$is_nucleo[$i]', '$masstype[$i]', '$ref', '$peplist_sp'));
	#$Ref = qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="refGoTo('Retrieve');" onmouseover="refSetVars(this, '$noDirURL');" onmouseout="clearTimeout(PopupAppear); HideChoices('RefMenu', event.x, event.y);">$ref</span>);
	## changed to use an array:
	$Ref = qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="refGoTo('Retrieve');" onmouseover="refSetVars(this, $refarray);" onmouseout="clearTimeout(PopupAppear); HideChoices('RefMenu', event.x, event.y);">$ref</span>);
  }

  my $tempAddVar="";

  if (!defined $ref_more{$index}) {
    $tempAddVar .= "$s" x ($reflen - length($ref));
  } else {
    $tempAddVar .= "$s" x ($reflen - length($ref_more{$index}) - length($ref));

    if ($no_hyper) {
      $tempAddVar .= $ref_more{$index};
    } else {
      # calculate ref_more URL
   
	  $url = "$morerefs?OutFile=" . &url_encode("$seqdir/$directory/$file.out") . "&Ref=" . $ref . "&Peptide=$plain_contents{\"Seq\"}";
      $tempAddVar .= qq(<a href="$url" target="_blank">$ref_more{$index}</a>);
    }
  }
  $Ref_NoJS .= $tempAddVar;
  $Ref .= $tempAddVar;

  if (defined $BP{$file}) {
	$BP = &sci_notation ($BP{$file});
	$plain_contents{"BP"} = $BP;

	my $spacedBP = ($s x (6 - length($BP))) . $BP;

	if ($BP >= &sci_notation($Median_BP)) {
	  $BP = "<b>$spacedBP</b>";
    } else {
	  $BP = $spacedBP;
	}

  } else {
    $BP = "------";
	$plain_contents{"BP"} = $BP;
  }

  # significance calculation code (Edward 8/2/01)
  my $justTheSeq = $Seq;
  $justTheSeq =~ s/<.*?>//g;
  $justTheSeq =~ s/^\(.\)//;
  my $SigCalc = "";
  if ($probscores{"$file.dta $justTheSeq"}) {
      $significance = $probscores{"$file.dta $justTheSeq"};
	  #if($significance != 1){
		#$significance = &sci_notation($significance);
	  #}

	  $significance = -10 * (log $significance) / (log 10);
	  $significance = &precision($significance, 0);
	  
	  #$SigCalc = qq(&nbsp<span style="color:#666666">$significance</span>);
	  $SigCalc = $significance;
	  $plain_contents{"P"} = $SigCalc;
  } elsif( %probscores) {
	  #$SigCalc = qq(&nbsp<span style="color:#666666">nd</span>);
	  $SigCalc = "nd";
	  $plain_contents{"P"} = 0;
  }
  my $SigCalcSpaces = 3 - length $SigCalc;		# number of pad spaces to add to the left of short SigCalcs (ie, ones less thatn 3 characters)
  $SigCalcSpaces = 0 if $SigCalcSpaces < 0;		# just in case $SigCalc is longer than 3 for some reason
  $SigCalcSpan = ($SigCalc > 13) ? qq(<span style="color:'$emphasized_purple'; font-weight:bold">) : qq(<span style="color:#000000">);	#former grey color was #666666

  $SigCalc = ("&nbsp" x $SigCalcSpaces) . $SigCalcSpan . qq($SigCalc</span>);
  # end sig calc code

  $jsblastpep = ($blasturl =~ /Pept=([^&]+)/i) ? $1 : "";  # added 2/4/02
  $jsblastdb = ($blasturl =~ /Oth=([^&]+)/i) ? $1 : "";    #
  $Seq_NoJS = qq(<a target="_blank" href="$blasturl_NoJS">$Seq</a>) unless $no_hyper;  # changed to the following line 2/4/02 for JS efficiency:
  #old: $Seq = qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="blastSetVars('$jsblastpep', '$jsblastdb')">$Seq</span>) unless $no_hyper;
  $Seq = qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="blastGoTo('dpaanr')" onmouseover="blastSetVars(this, '$jsblastpep');" onmouseout="clearTimeout(PopupAppear); HideChoices('SeqMenu', event.x, event.y);">$Seq</span>) unless $no_hyper;


  # what to do for empty .out files:
  if ($empty{$file}) {
 #   $mass = &precision ($mass_ion[$i], 1, 4, $s);
    $delM = "$s" x 4;
    $Xcorr = "$s" x 4;
    $deltaCn = "$s" x 4;
    $Sp = "$s" x 5;
    $RSp = "$s" x 3;
    $Ions = "$s" x 6;
	$Ions_NoJS = $Ions;
    $Ref = "no hits";
    $Ref = $s x ($reflen - length ($Ref)) . $Ref;
	$Ref_NoJS = $Ref;
	$Seq = "";
	$Seq_NoJS = $Seq;
  }

  $descrip_to_print = &printdescrip($ref);
  $plain_contents{"descrip"} = $descrip_to_print;

  if ($use_filter) {
		if ($filter_action eq "SHOW") {
			return (&filter_escape($file)) unless (&pass_filter(%plain_contents));	# print this line only if it passes filter
		} elsif ($filter_action eq "HIDE") {
			return (&filter_escape($file)) if (&pass_filter(%plain_contents));		# don't print this line if it passes filter
		} elsif ($filter_action eq "SELECT") {
			$selected{$file} = "CHECKED" if (&pass_filter(%plain_contents));	# check this scan if it passes filter
		} elsif ($filter_action eq "DESELECT") {
			$selected{$file} = "" if (&pass_filter(%plain_contents));		# uncheck this scan if it passes filter
		}
  }
  sub filter_escape {
	my $file = shift;
    # we're hiding this scan on the display, so don't count it in $outfile_count
	$outfile_count--;
	# preserve checkbox state even while hiding this scan
	print qq(<input type=hidden name="selected" value="$file">\n) if ($selected{$file});
	return 0;
  }

  ##
  ## if boxtype is hidden, only add it if we are a selected file
  ## otherwise, always show the box, but check it only if selected.
  ##

  if ($boxtype eq "HIDDEN") { 
    if ($selected{$file}) {
	  $tempAddVar = qq(<INPUT TYPE=$boxtype NAME="selected" VALUE="$file">);
      $Ref = $tempAddVar . $Ref;
	  $Ref_NoJS = $tempAddVar . $Ref_NoJS;
    }
  } else {
	$tempAddVar = qq(<INPUT TYPE=$boxtype class="check" NAME="selected" VALUE="$file" $selected{"$file"}>);
    $Ref = $tempAddVar . $Ref;
	$Ref_NoJS = $tempAddVar . $Ref_NoJS;
	push(@checkbox_BPs,&sci_notation($BP{$file}));
  }

  # Edward's goodbadugly addition, April 10, 2001. 
  # changed october 8, 2001 to print as a new column
  my($gbucolor);
  if( $gbuscores{"$file.dta"} == 1){
	$gbucolor = "#FF0000";
  }elsif( $gbuscores{"$file.dta"} =~ -1){
    $gbucolor = "#0300DD";
  } else{
	$gbucolor = "#00D0D0";
  }
  if(($z==2 or $z==1) and defined $gbuscores{"$file.dta"} ){
	$gbuString = qq(<span style="color:$gbucolor">$gbuscores{"$file.dta"}</span>);
  }else{
	$gbuString = "&nbsp;";
  }
  # since "-1" is two characters, we need an extra space in other cases
  $gbuString = "$s" . $gbuString unless($gbuscores{"$file.dta"} == -1 and ($z==2 or $z==1));

  # End of the Good bad ugly addition

  # now find the combined score
  # don't display it if this is not the top level of the outfile (10/11/01)
  $combined_score_string = (defined $combinedscores{"$file.dta"} and $num == 1) ? &precision($combinedscores{"$file.dta"},2) : $s .  "--"  . $s;
  #$combined_score_string = "<b>" . $combined_score_string . "</b>" if($combinedscores{"$file.dta"} > $SC_THRESH); 
  $combined_score_string = qq(<span style="color:'$emphasized_purple'"><b>) . $combined_score_string . "</b></span>" if($combinedscores{"$file.dta"} > $SC_THRESH); 


  $line_to_print =  $startline;
  $line_to_print_NoJS = $line_to_print;   # the _NoJS variables are used for opening the DTAVCR window
  $line_to_print .= join ("$divider", $filenumstr, $gbuString, $BP, $name, $zdisplay, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions, $combined_score_string, $SigCalc);
  $line_to_print_NoJS .= join ("$divider", $filenumstr, $gbuString, $BP, $name, $zdisplay, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions_NoJS, $combined_score_string, $SigCalc);
  $line_to_print .= $divider;
  $line_to_print_NoJS .= $divider;
  $line_to_print .= "$s$Ref";
  $line_to_print_NoJS .= "$s$Ref_NoJS";

  # added by cmw (7/14/99)
  $BP_sci = &sci_notation($BP{$file});

  $line_to_print .= $divider;
  $line_to_print_NoJS .= $divider;
  $line_to_print .= "$s$Seq";
  $line_to_print_NoJS .= "$s$Seq_NoJS";
  
  # throw in link to fuzzied seqs if it exists:
  unless ($no_hyper) {
    if (-f $file . ".fuz.html") {
	  $tempAddVar = qq( <a target="_blank" href="$webseqdir/$directory/${file}.fuz.html">+</a>);
      $line_to_print .= $tempAddVar;
	  $line_to_print_NoJS .= $tempAddVar;
    }
  }

  # ionquest links
  if (grep /$file/, @ionquest_base_names) {
	my $ionquest_dta = $file . ".dta";
	my $ionquest_refdta = $ionquest_pairs{$ionquest_dta};
	$tempAddVar = qq(&nbsp;<a target="_blank" href="$thumbnails?Dta=$seqdir/$ionquest_dir/$ionquest_dta&Dta=$seqdir/$ionquest_refdir/$ionquest_refdta">$ionquest_pairs_reference{$ionquest_dta}</a>);
	$line_to_print .= $tempAddVar;
	$line_to_print_NoJS .= $tempAddVar;
  }

  $line_to_print .= $endline; 
  $line_to_print_NoJS .= $endline;
  print $line_to_print;

  if ($printdescrip) {
    print $descrip_to_print;
  }

  ########################
  # for DTA VCR purposes:
  if ($load_dta_vcr) {
	  $vcr_count = 0 unless (defined $vcr_count);
	  push(@dtavcr_links, $dta_vcr_url);
	  $infoline = $line_to_print_NoJS;
	  if ($boxtype ne "HIDDEN") {
		# add checkbox interactivity to infoline
		$infoline =~ s!(<input\s+[^>]*type\s*=\s*"?checkbox"?[^>]*)>!$1 onClick="top.opener.vcr_update_opener($vcr_count)">!i;
	  }
	  $infoline =~ s/\n//g;
	  # append beginning of description line
	  $infoline .= $descrip_to_print;
	  push(@dtavcr_infos, $infoline);
	  push(@dtavcr_include_ifs, $file);
	  $vcr_count++;
  }
  # end of DTA VCR addition
  #########################


  push @{$outs_js{$rank}}, {sel => $count-1, file => $file, filenum => $plainfilenum, tic => $plain_contents{"BP"}, pep => $justTheSeq} unless $rank == -1;

}



sub print_one_dataline_bericht {
  my (%args) = @_;
  my ($index, $rank, $preferred_ref) =
	($args{"index"}, $args{"rank"}, $args{"preferred_ref"});

  my ($i, $num, $url, $line, $file, $ref);
  my ($name, $z, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions, $Ref, $Seq, $BP);
  my ($dbpepurl, $disppepurl, $blasturl, $blasturl_NoJS);
  my ($filenumstr);

  # $start, $end bound each piece of data
  # $start_l is a left-aligned version of $start
  # $startline, $endline bound each line
  # $s is our space-separator char
  #
  my ($startline, $divider, $endline, $s);

  $startline = "<TT>";
  $endline = "</TT><BR>\n";
  $divider = " ";
  $s = "&nbsp;";
  
  ($i, $num) = $index =~ m!(\d+):(\d+)!;


  $file = $outs[$i];
  
  $filenumstr = &precision ($i+1, 0, 3, $s);

  if ($rank != -1) {
    my $colour = $rank_colour[$rank];
    $filenumstr = qq(<span style="color:$colour"><b>$filenumstr</b></span>);
  }

  $Seq = $peptide{$index};

  ($disppepurl, $dbpepurl, $blasturl, $blasturl_NoJS) = &URLs_of_seq ($Seq, $file);

  # calculate URL for showing .out file
  $url = "$showout?OutFile=" . &url_encode("$seqdir/$directory/$file.out") . "&dbdir=" . &url_encode("$dbdir");

  ($name, $z) = $file =~ m!\.(\d+\.\d+)\.(\d)$!;

  if ($name =~ m!^(\d+)\.\1$!) {
    # truncate single scans
    $name = $1;
    $name .= "&nbsp;" x 5;
  } else {
    $name =~ s!\.!-!; # make dots into dashes
  }

  # 29.3.98: changed by Martin to make $mass reflect the experimental mass
  # and delta-M to be the deviation between that and the calculated mass of
  # the peptide:
  $delM = &precision ($MHplus{$index} - $mass_ion[$i], 1, 2, $s);

  $mass = &precision ($mass_ion[$i], 1, 4, $s);

  # 29.3.98: changed by Martin to only 2 significant digits:
  $Xcorr = &precision ($C10000{$index}, 2, 1, "0");
  $Xcorr = "<b>$Xcorr</b>" if ($C10000{$index} >= $XCORR_THRESH);

  # 29.3.98: changed by Martin to only 2 significant digits:
  # quick fix by Martin so that deltaCn dredged up from lower levels in the
  # out files don't give erroneous, positive values: 98/07/12:
  if ($num != 1) {
    $deltaCn = "----";
  } else {
    $deltaCn = &precision (get_delCn($index), 2, 1, "0");
    $deltaCn = "<b>$deltaCn</b>" if (get_delCn($index) >= $DELTACN_THRESH);
  }

  # 29.3.98: changed by Martin to NO significant digits:
  $Sp = &precision ($Sp{$index}, 0, 4, $s);
  $Sp = "<b>$Sp</b>" if ($Sp{$index} >= $SP_THRESH);

  $RSp = &precision ($rankSp{$index}, 0, 3, $s);
  $RSp = "<b>$RSp</b>" if ($rankSp{$index} <= $RSP_THRESH);



  $Ions = "$s" x (7 - length($ions{$index}));
  $Ions .= $ions{$index};

  # if asked, use the reference given us. Otherwise, use the usual value:
  $ref = $preferred_ref || $ref{$index};

  # calculate URL for reference:
  $Ref = $ref;

  if (defined $ref_more{$index}) {
    my $ref_more_spacing = $s x (4 - length($ref_more{$index}));
    $Ref .= "$s$ref_more_spacing$ref_more{$index}";
  }

  if (!defined $ref_more{$index}) {
    $Ref .= "$s" x (22 - length($ref));
  } else {
    $Ref .= "$s" x (17 - length($ref));
  }


  if (defined $BP{$file}) {

	$BP = &sci_notation ($BP{$file});

	# this does nothing, but it used to do something:
    if ($BP >= &sci_notation($Median_BP)) {
      $BP = "$BP";
    }

  } else {
    $BP = "-----";
  }

  # what to do for empty .out files:
  if ($empty{$file}) {
    $delM = "$s" x 4;
    $Xcorr = "$s" x 4;
    $deltaCn = "$s" x 4;
    $Sp = "$s" x 5;
    $RSp = "$s" x 3;
    $Ions = "$s" x 6;
    $Ref = "no hits";
    $Ref = $s x ($reflen - length ($Ref)) . $Ref;
    $Seq = "";
  }


  print ($startline);

  my($Seq1,$Seq2) = ($Seq =~ /(\(.\))(.*)/);

  if (length($Seq2) <= 32) {
	  print ("$s$Seq1$s$s", $Seq2,$s x (32 - length($Seq2)));
  } else {
	  print ("$s$Seq1$s$s", $Seq2, "<br>", $s x 38);
  }
  push(@all_bericht_seqs, $Seq2);

  print ($Ref);
      
  print ($BP, $s);
  print ($s, $Ions, "$s$s");
  print ($name);

  print ($endline);

}

sub return_one_dataline {		# this will replace print_one_dataline_bericht when the xml reports are functional
  my (%args) = @_;
  my ($index, $rank, $preferred_ref) =
	($args{"index"}, $args{"rank"}, $args{"preferred_ref"});

  my ($i, $num, $url, $line, $file, $ref);
  my ($name, $z, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions, $Ref, $Seq, $BP);
  my ($dbpepurl, $disppepurl, $blasturl, $blasturl_NoJS);
  my ($filenumstr);

  my %spectrum;
  # $start, $end bound each piece of data
  # $start_l is a left-aligned version of $start
  # $startline, $endline bound each line
  # $s is our space-separator char
  #
  my ($startline, $divider, $endline, $s);

  ($i, $num) = $index =~ m!(\d+):(\d*)!;

  if ($num eq "") {
	  $index = $i . ":" . "1";
  }
  $file = $outs[$i];
  $filenumstr = &precision ($i+1, 0);
  $spectrum{filenumber} = $filenumstr;

  $Seq = $peptide{$index};
  
  $spectrum{sequence} = $Seq;
  ($name, $z) = $file =~ m!\.(\d+\.\d+)\.(\d)$!;

  if ($name =~ m!^(\d+)\.\1$!) {
    # truncate single scans
    $name = $1;
  } else {
    $name =~ s!\.!-!; # make dots into dashes
  }
  $spectrum{scanname} = $name;

  # 29.3.98: changed by Martin to make $mass reflect the experimental mass
  # and delta-M to be the deviation between that and the calculated mass of
  # the peptide:
  $delM = &precision ($MHplus{$index} - $mass_ion[$i], 1);
  $spectrum{delm} = $delM;
  $mass = &precision ($mass_ion[$i], 1);
  $spectrum{mass} = $mass;

  # 29.3.98: changed by Martin to only 2 significant digits:
  $Xcorr = &precision ($C10000{$index}, 2, 1, "0");
  $spectrum{xcorr} = $Xcorr;

  # 29.3.98: changed by Martin to only 2 significant digits:
  # quick fix by Martin so that deltaCn dredged up from lower levels in the
  # out files don't give erroneous, positive values: 98/07/12:
  if ($num != 1) {
    $deltaCn = "----";
  } else {
    $deltaCn = &precision (get_delCn($index), 2, 1, "0");
  }
  $spectrum{deltacn} = $deltaCn;

  # 29.3.98: changed by Martin to NO significant digits:
  $Sp = &precision ($Sp{$index}, 0);
  $spectrum{sp} = $Sp;

  $RSp = &precision ($rankSp{$index}, 0);
  $spectrum{rsp} = $RSp;


  $Ions = $ions{$index};
  $spectrum{ions} = $Ions;

  # if asked, use the reference given us. Otherwise, use the usual value:
  $ref = $preferred_ref || $ref{$index};
  $spectrum{ref} = $ref;

  if (defined $ref_more{$index}) {
	$spectrum{refmore} = $ref_more{$index};
  }

  if (defined $BP{$file}) {
	$BP = &sci_notation ($BP{$file});
  } else {
    $BP = "-----";
  }
  $spectrum{bp} = $BP;

  # what to do for empty .out files:
  if ($empty{$file}) {
	$spectrum{ref} = "no hits";
  }

  my($Seq1,$Seq2) = ($Seq =~ /(\(.\))(.*)/);
  push(@all_bericht_seqs, $Seq2);

  return \%spectrum;
}


# this subroutine finds the deltaCn value for the given value of $index

sub get_delCn {
  my ($index) = $_[0];
  my ($i, $num) = $index =~ m!(\d+):(\d+)!;

  my ($index2, $deltaCn);

  while (1) {
    $num++;
    $index2 = "$i:$num";
    $deltaCn = $deltaCn{$index2};

    if (!defined $deltaCn) {
      $deltaCn = "0";
      last;
    }
    last if ($deltaCn != 0);
  }
  return $deltaCn;
}
# divide here

##
## this routine opens each .out file and puts the info into
## associative arrays
##

## changes by martin 98/9/1 to account for changes to the output file
## with Sequest version C2

## changes by lukas 01/04/30 to account for changes to the output file with
## rev 12

####### old style OUT files:

# 0817rsp100-gt.0489.0489.2.out
# SEQUEST v.C1, Copyright 1993-96
# Molecular Biotechnology, Univ. of Washington, J.Eng/J.Yates
# Licensed to Finnigan MAT
# 09/02/98, 04:43 PM, 1 min. 55 sec. on SEQUEST_HOST
# mass=920.3(+2), fragment_tol=0.00, mass_tol=2.50, MONO
# # amino acids = 93899880, # proteins = 310597, # matched peptides = 413190
# immonium (HFYWM) = (00000), total_inten=4437.0, lowest_Sp=202.7
# ion series nA nB nY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0
# rho=0.200, beta=0.075, top 12, C:/database/nr.fasta
# (M* +16.00) (K# +14.00) C=160.01 Enzyme:Trypsin 1 KRFWY - 

######## new style OUT files: (98/9/1)

# 0817rsp100-gt.0351.0351.2.out
# SEQUEST v.C2, (c) 1993-1998
# Molecular Biotechnology, Univ. of Washington, J.Eng/J.Yates
# Licensed to Finnigan Corp.,  A Division of ThermoQuest Corp.
# 09/02/1998, 04:30 PM, 1 min. 4 sec. on SEQUEST_HOST
# (M+H)+ mass = 852.0600 ~ 2.5000 (+2), fragment tol = 0.0, MONO/MONO
# total inten = 3712.2, lowest Sp = 156.5, # matched peptides = 94132
# # amino acids = 95306644, # proteins = 310593, C:/database/nr.fasta
# ion series nABY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0
# display top 12/12, ion % = 0.0, CODE = 1010
# (M* +16.000) (K# +14.000) C=160.009 Enzyme:Trypsin (5) 

######## new style OUT files: (01/4/30)

# 0411Zcbap200-gt.0801.0801.2.out
# TurboSEQUEST v.27 (rev. 12), (c) 1999-2000
# Molecular Biotechnology, Univ. of Washington, J.Eng/S.Morgan/J.Yates
# Licensed to ThermoFinnigan Corp.
# 04/30/2001, 02:33 PM, 7 sec. on HOST1
# (M+H)+ mass = 1175.0100 ~ 1.0000 (+2), fragment tol = 0.0, MONO/MONO
# total inten = 8497.0, lowest Sp = 510.8, # matched peptides = 557506
# # bases = 6167682 (frame=9), # proteins = 0, e:\database\est4g.fasta, e:\database\est4g.fasta.hdr
# ion series nABY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0
# display top 12/12, ion % = 0.0, CODE = 00194
# (M* +15.995) C=160.038 Enzyme:Trypsin (2)

sub process_outfiles {
	my ($i, $line, $num, $index, $ref, $segment);
	my (@a, $k);
	my ($date_y_low, $date_m_low, $date_d_low, $date_y_high, $date_m_high, $date_d_high);
	my $file;
	my ($OLDNUM);
	my $isrev12;


	@outs = sort {$a cmp $b} @current_outs; # sort alphabetically

	# make %number a quick associative array for their position in @outs:
	$i = 0; map {$number{ $_ } = $i++} @outs;

  	foreach $file (@outs) {
		$i = $number{ $file };
	
		open (FILE, "$file.out") or die "Cannot open $file.out!!!";

		# grab first two lines
		# check for rev.12
		$line = <FILE>;
		$line = <FILE>;
		$line = <FILE>;
		$isrev12 = ($line =~ /rev\. 12/);

		# skip licensing and time info:
		# this line is like
		# mass=1408.4(+2), fragment tol.=0.00, mass tol.=1.00, MONO
		while (<FILE>) {
			next unless m!(..)\/(..)\/(..+), \d+:.. .., (.*) on!;

			#in the meantime we are calculating the date range of the outfiles
			#NOTE: these rely on boolean logic optimization being on
			if ((!defined $date_y_high) || $3 > $date_y_high || $1 > $date_m_high || $2 > $date_d_high) {
				$date_y_high = $3;
				$date_m_high = $1;
				$date_d_high = $2;
			}

			if ((!defined $date_y_low) || $3 < $date_y_low || $1 < $date_m_low || $2 < $date_d_low) {
				$date_y_low = $3;
				$date_m_low = $1;
				$date_d_low = $2;
			}

			last;
		}

		$line = <FILE>;

		# nightmare regular expression:
		if ($line =~ m!^\s*mass=(\d+\.?\d*)\((\+\d)\)!) {
			($mass_ion[$i], $charge[$i]) = ($1, $2);
			$format = "C1";

		} elsif ($line =~ m!mass = (\d+\.?\d*).*\((\+\d)\)!) {
			($mass_ion[$i], $charge[$i]) = ($1, $2);
			if ($isrev12) {
				$format = "C3";
			} else {
				$format = "C2";
			}
		}

		if ( $line =~ m![^/]MONO! ) {	# [^/] added to accomodate SequestC2 (cmw, 12.9.98)
			$masstype[$i] = "1";
		} elsif ( $line =~ m![^/]AVG! ) {
			$masstype[$i] = "0";
		} else {
			print STDERR ("$ourshortname: File is $file.out, directory is $directory; unknown masstype\n");
			$masstype[$i] = "unknown";
		}


		# skip the next line if new format:
		if ($format gt "C1") {
			$line = <FILE>;
		}

		# next line is of the form:
		# # bases = 329462847, # proteins = 894319, # matched peptides = 83862
		#   ^^^^^ bases if nucleotides, amino acids if from protein database
   
		$line = <FILE>;
		$is_nucleo[$i] = ($line =~ m!amino acids!) ? 0 : 1;
		if ($format gt "C1") {
			# grab only the filename, not the directory, and eliminate ".fasta"
			($database[$i]) = $line =~ m!([^\\/]+\.FASTA)!i;
		}

		# skip this line: (only exists in old format)
		# immonium (HFYWM) = (00000), total inten. = 6129.0, lowest Sp = 182.0
		if ($format eq "C1") {
			$line = <FILE>;
		}

		# get the ion series info:
		# ion series nA nB nY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0
		#
		#  0    1     2  3  4     5      6 7 8  9   10  11  12  13  14  15  16  17

		# C2/C3 format:
		# ion series nABY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0
		#
		#  0    1     2       3      4 5 6  7   8   9   10  11  12  13  14  15

		$line = <FILE>;
		@a = split (' ', $line);
		# construct the string to pass to displayions; of the form "010000010"
		# these correspond to the a,b,c,d,v,w,x,y, and z ions
		$ionstr[$i] = "";
		if ($format eq "C1") {
			for ($k = 9; $k <= 17; $k++) {
				$ionstr[$i] .= ( ($a[$k] == 0 ) ? "0" : "1" );
			}
		} else {
			for ($k = 7; $k <= 15; $k++) {
				$ionstr[$i] .= ( ($a[$k] == 0 ) ? "0" : "1" );
			}
		}

		# next line contains the database name:
		#  rho=0.200, beta=0.075, top 15, /usr/entrez/database/dbEST.weekly.FASTA
		$line = <FILE>;

		# grab only the filename, not the directory, and eliminate ".fasta"
		if ($format eq "C1") {
			($database[$i]) = $line =~ m!([^\\/]+\.FASTA)!i;
		}

		# do not look for last line--might have a last line that print out
		# SEQUENCE HEADER = ALBUMIN ----- blm 000815 changes
		# last line or header gives modifications, just grab it. Of the form
		# (M# +16.0) C=160.0 Enzyme:Trypsin 
		# changed by cmw 10/24/98 to accomodate version C2
		#$nextline = <FILE>;
		#while ($nextline =~ /\S/) {	# search for last line before a line of white-space
		#$prevline = $nextline;
		#$nextline = <FILE>;
		#}
		#$mods[$i] = $prevline;
		$nextline = <FILE>;
		chomp $nextline;
		$mods[$i] = $nextline;
		while (<FILE>) {
			last if /^\s*$/; # stop on a space-filled line
		}

		while (<FILE>) {
			last if /\S/; # stop on a non-space-filled line
		}
		$dummy = <FILE>; # separator line

		# core of the program:
		# the lines from the .out file have this header:
		#  #   Rank/Sp  (M+H)+    Cn    deltCn  C*10^4    Sp     Ions  Reference        Peptide
		# ---  -------  ------  ------  ------  ------   ----    ----  ---------        -------

		# unless, of course, it's a C2 file, in which case, the lines are the following:
		#  #   Rank/Sp    (M+H)+   deltCn   XCorr    Sp     Ions  Reference                              Peptide
		# ---  -------  ---------  ------  ------   ----    ----  ---------                              -------

		# unless, of course, it's a rev. 12 (C3) file, in which case, the lines are the following:
		#  #   Rank/Sp      Id#     (M+H)+   deltCn   XCorr    Sp     Ions  Reference       Peptide
		# ---  --------  --------  --------  ------  ------   ----    ----  ---------       -------

		$OLDNUM = 0;
		$index = "";
		$empty{$file} = 1; # true if the file has no data

		my $line_already_read = 0;

		while ($line = <FILE>) {
			#maybe we need this 
			chomp $line;
			next if ($line =~ m!^\s*$!);

			if ($line =~ m!^\s*(\d+)\.\s+!) {
				$num = $1;

				#this is just an UGLY way of processing the outfile correctly if there is a highest preliminary 
				#scoring peptide which was not printed among the highest scorring XCorr peptides.
				#Relies on the assumption that the last section of the outfile containg further references contains entries
				#whose index starts lower than the last index of the results section.
				last if ($num <= $OLDNUM);

				 $index = "$i:$num";
				 $OLDNUM = $num;
				 &process_line ($line, $index);

				 $empty{$file} = 0;
			} else {
				## pull out additional refs, making them canonical according the indexing subroutines:
				
				# if rev.12, ignore ID# preceding ref id
				if ($format eq "C3") { 
					($segment) = $line =~ m!^\s*\S+\s+(\S+)!;
				} else {
					($segment) = $line =~ m!^\s*(\S+)!;
				}

				$ref = &parseentryid ($segment);
				&store_long_form ($segment, $ref);
				$other_refs{$index} .= " " . $ref unless ($index eq "");
				$level_in_file{"$i:$ref"} = $num unless (defined $level_in_file{"$i:$ref"});

				# it is not clear that the following block of code is working or is otherwise significant
				# it should gather some of the inlined reference data in the .out file however
			 
				#GMM: The code should work now. 
				$line =~ s/^\s*//;  #this is essential --GMM
				my($aref, @eol) = split(/\s+/, $line);
				$myref = &parseentryid($aref . "|");
				
				if (!defined($refdata{$myref})) {
					$refdata{$myref}->[0]="@eol";
				}
				next;
			}
		}

	    # collect further reference data
		my $lastref="";

		my %add_ref_pulled=();

		#NOTE: We have already read the first line to be parsed in this section
		while ($line) {
		    chomp $line;
			if ($line =~ m!^\s*$!) {
				$line = <FILE>;
			    next;
			}
			
			$line=~ s/^(\s*)//;
			my $spaces = length($1);

			if ($spaces <= 2 && $line =~ m/^\d+\.\s+/) {
				my($blank, $aref, @eol) = split(/\s+/, $line);
				$myref=parseentryid($aref . "|");
				
				if (!defined($refdata{$myref})) {
					$add_ref_pulled{$myref} = 1;
					$refdata{$myref}->[0]="@eol";
					$lastref=$myref;
				} elsif ($add_ref_pulled{$myref} != 1) {
					$lastref="";
				}
			} else {
				push(@{$refdata{$lastref}}, $line) if ($lastref ne "");
			}	
		
			$line = <FILE>;
		}
		
		close FILE;
	}

	# process dates of .out files
	$date_string = $date_m_low.'/'.$date_d_low.'/'.substr( $date_y_low,-2).'-'.$date_m_high.'/'.$date_d_high.'/'.substr($date_y_high,-2);

	#dump all the processed info to avoid reprocessing if possible
	&dump_data;
} # end of &process_outfiles

##
## &process_line
##
## this analyzes a single line from a .out file and creates appropriate
## entries for it in the various associative arrays

sub process_line {
  my ($line, $index) = @_;
  my @fields;
  my ($i, $num) = $index =~ m!(\d+):(\d+)!;

  # this separates Rank from Sp and separates the two parts of the Ions field
  $line =~ s!/! !g;
  @fields = split (' ', $line);

  shift @fields;

  $rank{$index} =  shift @fields;
  $rankSp{$index} = shift @fields;

  if ($format eq "C3") {
	$IDXNum{$index} = shift @fields;
  }

  $MHplus{$index} = shift @fields;
  
  if ($format eq "C1") {
    $Cn{$index} = shift @fields;
  } else {
    $Cn{$index} = "----";
  } 

  $deltaCn{$index} = shift @fields;
  $C10000{$index} = shift @fields;

  $Sp{$index} = shift @fields;
  $ions{$index} = shift (@fields) . "/" . shift (@fields);
  

  # sort the various possibilities of the rest of the line:
  $ref{$index} = $fields[0];
  if ( $ref{$index} =~ s!(\+\d+)!! ) {
    $ref_more{$index} = $1;
    $peptide{$index} = $fields[1];

  } elsif ( $fields[1] =~ m!\+\d+!) {
    $ref_more{$index} = $fields[1];
    $peptide{$index} = $fields[2];

  } else {
    $peptide{$index} = $fields[1];
  }

  # convert new peptide format "K.BLAHPEPR.L" to old "(K)BLAHPEPR"
  if ($format gt "C1") {
    $peptide{$index} =~ s!^(.)\.!($1)!m;
    $peptide{$index} =~ s!\.([^\.]*)$!!;
  }

  ## make the reference canonical, according to the rules
  ## of the indexing subroutines:
  my $short_ref = &parseentryid ($ref{$index});
  
  &store_long_form ($ref{$index}, $short_ref);
  $ref{$index} = $short_ref;

  $level_in_file{"$i:$ref{$index}"} = $num unless (defined $level_in_file{"$i:$ref{$index}"});
}


sub store_long_form {
  my ($ref, $short) = @_;
  my ($current);

  if ($DEBUG) {
    $ref_long_form{$ref} = $ref;
    return;
  }


  $current = $ref_long_form{$short};

  if (!defined $current) {
    $ref_long_form{$short} = $ref;
    return;
  }

  my ($l1, $l2, $l);
  $l1 = length ($current);
  $l2 = length ($ref);

  $l = ($l1 >= $l2) ? $l1 : $l2;
  if (substr ($ref, 0, $l) ne substr ($current, 0, $l)) {
    $ref_long_form{$short} .= "*" unless $current =~ m!\*!;
  } elsif ($l2 > $l1) {
    $ref_long_form{$short} = "$ref";
  }
}

sub load_data() 
{
	my $line;

	open (DUMPFILE, "$seqdir/$FORM{'directory'}/$RUNSUMMARY_DATA_CACHE_FILE") || die "Cannot open $RUNSUMMARY_DATA_CACHE_FILE\n";
	
	#the first line is always the date spread of the runs 
	chomp($date_string = <DUMPFILE>);
	
	#the number of outfiles comes second since it will be needed to restore some of the other data
	chomp($num_outs = <DUMPFILE>);

	#restore the hashes indexed by outfile name
	for ($i=0; $i < $num_outs && (split (',', <DUMPFILE>)); $i++) {
		#get rid of the record terminator
		chomp $_[2];

		my $file = shift;
		($empty{$file}, $number{$file}) = @_;

		$outs[$number{$file}] = $file;
	}

	chomp($refdata_keys = <DUMPFILE>);

	#the field seperator we use is important 
	for ($i=0; $i < $refdata_keys && (split ('<$>', <DUMPFILE>)); $i++) {
		#get rid of the record terminator
		chomp $_[$#_];

		my $key = shift;
		@{$refdata{$key}} = @_;
	}

	chomp($line = <DUMPFILE>);
	%level_in_file = split(',', $line);

	chomp($line = <DUMPFILE>);
	%ref_long_form = split(',', $line);

	#get the arrays which are indexed by an outfile number 
	#line format: value,value, .........
	for ($i=0; $i < $num_outs; $i++) {
		chomp($line = <DUMPFILE>);
		($mass_ion[$i],$charge[$i],$masstype[$i],$is_nucleo[$i],$database[$i],$ionstr[$i],$mods[$i]) = split (',', $line);
	}

	#initialize all hashes which use $index as their key
	#line format: $index,value,value, .....
	while (split (',', <DUMPFILE>)) {
		#get rid of the record terminator
		chomp $_[$#_];

		my $index = shift;
		($rank{$index},$rankSp{$index},$IDXNum{$index},$MHplus{$index},$Cn{$index},$deltaCn{$index},$C10000{$index},$Sp{$index},$ions{$index},$ref{$index},$ref_more{$index},$other_refs{$index},$peptide{$index}) = @_;
	}

	close(DUMPFILE);
}

sub dump_data()
{
	#number of outfiles we need to deal with
	$num_outs = $#outs + 1;

	open (DUMPFILE, ">$RUNSUMMARY_DATA_CACHE_FILE");

	#first line is the date spread
	print DUMPFILE "$date_string\n";

	#save the number of outfiles since restoring some of the hashes might need it
	print DUMPFILE "$num_outs\n";

	#some hashes indexed by truncated outfile name. NOTE: there are exactly $num_outs elements in these hashes
	foreach $key (keys %empty) {
		print DUMPFILE qq($key,$empty{$key},$number{$key}\n);
	}
	
	
	#the refdata hash has a weird format and requires special care
	@ref_keys = keys %refdata;
	
	$num_keys = $#ref_keys + 1;
	print DUMPFILE "$num_keys\n";

	foreach (@ref_keys) 
	{	
			print DUMPFILE join('<$>', $_, @{$refdata{$_}});
			print DUMPFILE "\n";
	}

	#miscellaneous  hashes which don't have a common index.
	#The entire hash takes one line.
	print DUMPFILE join(',', %level_in_file);
	print DUMPFILE "\n";

	print DUMPFILE join(',', %ref_long_form);
	print DUMPFILE "\n";
	#end of miscellaneous

	#some arrays indexed by outfile number ....
	for ($j = 0; $j < $num_outs; $j++) {
		print DUMPFILE qq($mass_ion[$j],$charge[$j],$masstype[$j],$is_nucleo[$j],$database[$j],$ionstr[$j],$mods[$j]\n);
	}

	#then we have all the hashes by $index
	foreach $key (keys %rank) {
		print DUMPFILE qq($key,$rank{$key},$rankSp{$key},$IDXNum{$key},$MHplus{$key},$Cn{$key},$deltaCn{$key},$C10000{$key},$Sp{$key},$ions{$key},$ref{$key},$ref_more{$key},$other_refs{$key},$peptide{$key}\n);
	}
  
	close DUMPFILE;

	#write the current check file 
	open (FILE, ">summaryStatus");
	print FILE join(',', %current_mtime);
	print FILE "\n";
	close FILE;
}

sub update_dumpfile()
{	
	if (-e "summaryStatus") {
		open (FILE, "summaryStatus");

		chomp ($line = <FILE>);
		%old_mtime = split(',', $line);

		close FILE;
		
		if (-e $RUNSUMMARY_DATA_CACHE_FILE) {

			# sanity checking: number of outs in the cache same
			# as number of modification times in summaryStatus?

			open FILE, $RUNSUMMARY_DATA_CACHE_FILE;
			$line = <FILE>;
			chomp($line = <FILE>);
			close FILE;

			if ($line != keys %old_mtime) {
				&process_outfiles;
				return 1;
			}
		} else {
			&process_outfiles;
			return 1;
		}

		#this will help us divide things in groups
		my %existed = ();
		map {$existed{$_} = 1} keys %old_mtime;
		
		@modified_outs = ();
		@removed_outs = ();
		@added_outs = ();

		foreach (@current_outs) {
			if (defined $existed{$_}) {
				delete $existed{$_};
				if ($current_mtime{$_} > $old_mtime{$_}) {
					push(@modified_outs, $_);
				} elsif ($current_mtime{$_} < $old_mtime{$_}) {
					#this shouldn't occur but if it does the best thikng we can do is reprocess everything
					&process_outfiles;
					return;
				}
			} else {
				push (@added_outs, $_);
			}
		}
			
		#the only keys left in the has should be of out files which no longer exist 
		foreach (keys %existed) {
			push (@removed_outs, $_);
		}
		
	} else {
		#this should never happen but if does just force the creation of "summaryStatus"
		$modified_outs[0] = 1;
	}

	#update the summaryStatus file contents so that we can determine if something 
	#has changed next time around 
	if (defined $modified_outs[0] || defined $added_outs[0] || defined $removed_outs[0]) {
		#for now we just reprocess everything. 
		#There is a more efficient way to do this which avoids reprocessing everything but it is not clear 
		#how much better it will be.
		&process_outfiles;

		return 1;
	}

	return 0;
}


sub read_profile {
  my ($line, $temp, $file, $zBP, $fBP, $TIC);
  my (@BPs);
  my ($maxBP);

  open (PROFILE, "lcq_profile.txt") || return;
  $line = <PROFILE>; # skip first line

  $fBPsum = $zBPsum = $TICsum = 0;
  while (<PROFILE>) {
    ($file, undef, $fBP, undef, $zBP, $TIC, undef) = split (' ');
    $file =~ s!\.dta$!!;
	foreach $variable ($fBP,$zBP,$TIC) {
		$variable = "9900000000" if ($variable < 0);
	}
	$fBP{$file} = $fBP;
	$zBP{$file} = $zBP;
	$TIC{$file} = $TIC;
	$fBPsum += $fBP;
	$zBPsum += $zBP;
	$TICsum += $TIC;
  }
  close PROFILE;

# This code added by Mike 7/31/00
  $maxBPsum = 0;
  if (open (CHROMATOGRAM_PEAKS, "lcq_chro.txt"))
  {
	  $line = <CHROMATOGRAM_PEAKS>; # skip first line


	  while (<CHROMATOGRAM_PEAKS>) {
		($file, undef, undef, $maxBP) = split (' ');
		$file =~ s!\.cta$!!;
		foreach $variable ($maxBP) {
			$variable = "9900000000" if ($variable < 0);
		}
		$maxBP{$file} = $maxBP;
		$maxBPsum += $maxBP;
	  }
	  close CHROMATOGRAM_PEAKS;
  }

  $fBP_available = 1;	# print this option regardless
  $zBP_available = ($zBPsum > 0) ? 1 : 0;
  $TIC_available = ($TICsum > 0) ? 1 : 0;
  $maxBP_available = ($maxBPsum > 0) ? 1 : 0;

# wsl attempt to swap TIC for zBP default 8/29/99
  $BP_mode = $FORM{"BP_mode"};
  if (!defined $BP_mode) {
	if ($TIC_available) {
		$BP_mode = "TIC";
	} elsif ($zBP_available) {
		$BP_mode = "zBP";
	} elsif ($maxBP_available) {
		$BP_mode = "maxBP";
	} else {
		$BP_mode = "fBP";
	}
  }
  %BP = %{"$BP_mode"};
	
  # calculate median BP
  if (0) {
    # old method - median over all original dta's
    @BPs = sort { $b <=> $a } values %BP;
  } else {
    # new method - median over all current dta's
    foreach $file (@outs) {
      push (@BPs, $BP{$file});
    }
    @BPs = sort { $b <=> $a } @BPs;
  }

  $Median_BP = $BPs[ ($#BPs/2) ];
  $Median_BP_sci = &sci_notation($Median_BP);
  $Max_BP = $BPs[0];
}


sub read_seqparams {

	open(SEQPARAMS, "<sequest.params") || return;
	@lines = <SEQPARAMS>;
	close SEQPARAMS;
	$whole = join("", @lines);
	($seq_info,$enz_info) = split(/\[SEQUEST_ENZYME_INFO\]*.\n/, $whole);
	$_ = $seq_info;

	($diff_mods) = /^diff_search_options\s*=\s*(.*?)(\s*;|\s*$)/m;
	($term_mods) = /^term_diff_search_options\s*=\s*(.*?)(\s*;|\s*$)/m;
	($header_filter) = /^sequence_header_filter\s*?= *?(.*)$/m;
	($pep_mass_tol) = /^peptide_mass_tolerance\s*=\s*(.*?)(\s*;|\s*$)/m;
	($databasename) = /^first_database_name\s*=\s*(.*?)(\s*;|\s*$)/m;

	# Have to add explanation of term_diff_mods in
	my @term_vals = ("ct[", "nt]");
	my $count = 0;
	foreach $mod (split ' ', $term_mods) {
		$term_diff_mods .= "$mod $term_vals[$count] ";
		$count++;
	}
}



##
## this subroutine takes a list of dates and compresses
## them into one string, of the form MM/DD/YY - MM/DD/YY
## to indicate a span of dates.
##
## we do this by converting each into integer, and grabbing
## the highest and lowest.

sub process_dates {
  my ($date_low, $date_high) = @_;
  my ($string, $temp, $m, $d, $y);

  $d = ($date_low % 3000);
  $temp = ($date_low - $d) / 3000;

  $m = ($temp % 13);
  $y = ($temp - $m) / 13;
#  $y -= 100 if ($y > 100);

  $d = &precision ($d, 0, 2);
  $m = &precision ($m, 0, 2);
  $y = &precision ($y, 0, 2);

  $string = "$m/$d/$y-";

  $d = ($date_high % 3000);
  $temp = ($date_high - $d) / 3000;

  $m = ($temp % 13);
  $y = ($temp - $m) / 13;
#  $y -= 100 if ($y > 100);

  $d = &precision ($d, 0, 2);
  $m = &precision ($m, 0, 2);
  $y = &precision ($y, 0, 2);

  $string .= "$m/$d/$y";

  return ($string);
}

##
## &group_and_score
##
## Prepares score data information for &print_consensi.
## Some information may be used by &print_data.
## 
sub group_and_score {
  my ($ref, $ref2, $i, $num, $j);
  my (@scorelist, @filenumlist, $list);
  my (@refs, @goodrefs);
  my %top_score;
  my %backloc;
  my $sort = &find_sort_value();
	
  ##
  ## make an inverse assoc array %location such that given a $ref,
  ## we can see which indices contain a reference to it.
  ##
  ## This is made as a space separated list of reference indices.
  ## 
  foreach $index (keys %ref) {
    $ref = $ref{$index};
    $location{$ref} .= " " . $index;
    if (defined $other_refs{$index}) {
      foreach $ref (split (' ', $other_refs{$index})) {
        $location{$ref} .= " " . $index;
      }
    }
  }
	
  ## look at only those references that hit more than one
  ## index:
  ##
  ## we do this by looking for those with a %location value
  ## containing more than one space (the number of spaces
  ## equals the number of indices).

  @refs = grep { $location{$_} =~ m! .* ! } keys %location;
  @refs = sort { $a cmp $b } @refs; # sort alphabetically

  ## now, put the %location values into some canonical
  ## (here, alphabetical) order, so we can compare them
  ## more easily:

  foreach $ref (@refs) {
    $location{$ref} = join (" ", sort { $a cmp $b } split (" ", $location{$ref}) );
  }


  ## Now we collect all references that have the same %location
  ## value. We do this in order(N) time by constructing an
  ## inverse assoc array for %location. We call this %backloc.
  ##
  ## The values of %backloc are now a "representative set" of
  ## references for display; we call these @goodrefs, and we
  ## calculate score data from them.

  foreach $ref (@refs) {
    $loc = $location{$ref};
    $back = $backloc{$loc};

    if (defined $back) {
		# display a different database entry in consensus line if called upon
		if ($ref eq $FORM{"differentdescrip:$loc"}) {
			$backloc{$loc} = $ref;
			$consensus_refs{$ref} = $consensus_refs{$back};
			delete $consensus_refs{$back};
			$consensus_refs{$ref} .= " " . $back;
		} else {
			$consensus_refs{$back} .= " " . $ref;
		}
    } else {
      $backloc{$loc} = $ref;
    }
  }

  ## analyze each reference for score and two breakdowns of the score;
  ## one breakdown by category and one by file numbers within categories
  ##
  ## for a consensus line:
  ##                       score   categories      breakdown by file numbers within categories
  ##  1. HSU21128            112 (11,0,0,0,0,2) {3 5 9 11 13 16 23 25 27 31 33, x, x, x, x, 10 14}
  ##                      
  ## The score data are stored in %score, %score_breakdown, and %score_showfiles
  ## for &print_consensi.

  my @answers;
  foreach $ref (values %backloc) {
    @answers = &consensus_score($ref);
    if ($answers[0] >= 2) {
      ($score{$ref}, $score_breakdown{$ref}, $score_breakdown_display{$ref}, $score_showfiles{$ref}, $peplist{$ref}) = @answers;
	($top_score{$ref}) = $score_breakdown{$ref} =~ m!^(\d+),!;
      push (@goodrefs, $ref);
    }
  }
  ## we create this global variable which orders the references from
  ## highest to lowest scoring.

  if ($new_algo) {
    # here, we make sure the top score (the number of OUT files for which this is the top hit)
    # counts the most
    @ordered_refs = sort { $top_score{$b} <=> $top_score{$a} || $score{$b} <=> $score{$a} || $a cmp $b } @goodrefs;
  } else {
    @ordered_refs = sort { $score{$b} <=> $score{$a} || $a cmp $b } @goodrefs;
  }
  # 08/03/00 wsl, blm commented out line below to ensure that all goodrefs are looked at for groupings.
  #$#ordered_refs = &min ($MAX_NUM_CONSENSI - 1, $#ordered_refs); # set it to use just the top 52
    
  ## to each .out file, assign its highest position, for the
  ## best few references. We store this in the array @ranking.
  ##
  ## if a consensus entry has no new files (ie has a strict subset
  ## of the .out files counted in the previous entries), then it
  ## is coloured according to the *lowest* ranking consensus entry
  ## whose files overlap its.
  ##
  ## The "colour ranking" of the consensus entries are stored in
  ## %consensus_colour_rank

  my ($lowest_rank);
  $j = 0; # keeps track of the rank
  my ($c) = 0; # keeps track of position within consensi

  @rank_counts = (); # array of ranks that contain new .outs files,
                     # and that therefore get new colours
OUTER:
  foreach $ref (@ordered_refs) {
    # 08-03-00 blm: next two lines used to be 
	# $consensus_pos{$ref} = ++$c;  (the 'c' is only kept now for posterity's sake)
	++$c;
	$consensus_pos{$ref} = $j;
    if ($j >= $num_ranks_to_colour) {
      $consensus_colour_rank{$ref} = -1;
      next OUTER;
    }

    $lowest_rank = -1;
  INNER:
    foreach $index (split (" ", $location{$ref})) {
      ($i, $num) = split (":", $index);

     
      if (defined $ranking[$i]) {
        $lowest_rank = &max ($lowest_rank, $ranking[$i]);
        next INNER;
      }
      # the use of the word "rank" in $MAX_RANK here is a bit
      # misleading. This means that we only assign a ranking
      # to the .out file if this hit was above $MAX_RANK in
      # the list of entries in the .out file.

      if ($num <= $MAX_RANK) {
	  # TV modification 6/8/00 to fix pull to top bug w/ Make Tsunami (&maka_fasta())
	  #   pull_to_top_ref hash description:    KEYS:   the OUT filenames  (i.e. "0406kwxenp14-gt.0435.0587.2")
	  #                                        VALUES: the correct references w/ pull-to-top on    (i.e. "gi|133252")
 	    if ($sort eq "consensus") {
			$pull_to_top_ref{$outs[$i]} = $ref if ($pull_to_top && !$pull_to_top_ref{$outs[$i]}); 		 
		}	 	  
		$ranking[$i] = $j;
        $lowest_rank = $j;
	  } else {
	  }
	} # end INNER loop

    $consensus_colour_rank{$ref} = $lowest_rank;

    # advance to next ranking level if we have new .out files
    if ($lowest_rank == $j) {
      push (@consensus_groupings, $ref);

      # 08/03/00 wsl, blm changed $c to $j to change the listing protocol from
	  # A, B, K, o to A, B, C, D (to ensure that counter does not run past 52)
	  push (@rank_counts, $j);
	  $j++;
    }
  } # end OUTER loop

  # calculate the length of the longest reference
  $cons_reflen = 10;
  foreach $ref (@ordered_refs) {
    $l = length ($ref_long_form{$ref});
    $cons_reflen = $l if ($l > $cons_reflen);
  }
  $cons_reflen++;

} # end &group_and_score



##
## &print_consensi
##
## actually output the consensus, in the form 
##  1. HSU21128            112 (11,0,0,0,0,2) {3 5 9 11 13 16 23 25 27 31 33, x, x, x, x, 10 14}

sub print_consensi {
  my ($i);
  foreach $ref (@ordered_refs) {
	&print_one_consensus ("ref" => $ref, "with_others" => 1);
    last if (++$i >= $MAX_LIST); # only allow $MAX_LIST number of consensi to be listed
  }
}

# Martin thinks that the $with_others variable is set to 1 if
# the consensus is part of all the others at the bottom of the page;
# if it is 0, then it is alone, heading a section in "consensus" mode

sub print_one_consensus {
  my (%args) = @_;
  my ($ref, $with_others) = ($args{"ref"}, $args{"with_others"});
  my ($BPsum, $numfiles, $SFsum, $SFscores) = ($args{"BPsum"}, $args{"numfiles"}, $args{"SFsum"}, $args{"SFscores"});
  my $boxhtml = $args{"checkboxhtml"};
  my $groupnumber = $args{"groupnumber"};
  my ($count) = $consensus_pos{$ref};
  my ($s) = "&nbsp;";

  my ($url, $score, $score_breakdown, $score_breakdown_display, $score_showfiles);
  my ($baseurl, $i);
  my (@peps, $col_rank);
  my (@temp, $j);
  my $purplec = "#800080";
  my $redc = "#ff0000";

  ($i) = $count;

  $baseurl = "$consensus?Db=$dbdir/" . $database[$i];
  $baseurl .= "&NucDb=1" if ($is_nucleo[$i]);
  $baseurl .= "&MassType=" . $masstype[$i];

  $baseurl .= "&Pep=$peplist{$ref}";
  $baseurl .= "&Dir=" . $directory;

  $url = $baseurl . "&Ref=$ref";
  my $databasepath = qq($dbdir/$database[$i]);
  my $peplist_sp;
  ($peplist_sp = $peplist{$ref}) =~ tr/\+/ /;			# note: mod site characters have not been removed

  # the order of elements in this array is important to the ref JS functions!
  my $refarray = qq(new Array('$databasepath', '$is_nucleo[$i]', '$masstype[$i]', '$ref', '$peplist_sp', $groupnumber));

  $score = $score{$ref};
  $score_breakdown = $score_breakdown{$ref};
  $score_breakdown_display = $score_breakdown_display{$ref};
  $score_showfiles = $score_showfiles{$ref};

  # add $count - 1 to list of 08-03-00 blm changes
  $countstr =  $s . &get_group_letter($count);

  $col_rank = $consensus_colour_rank{$ref};
  my $consensuscolor;
  if (($col_rank != -1) && ($col_rank <= $num_ranks_to_colour)) {
    my $colour = $rank_colour[ $col_rank ];
	$consensuscolor = $colour;
    $countstr = qq(<span style="color:$colour"><b>$countstr</b></span>);
  }

  #calculate mean and meadian for sf, if it exists in this dir
  my($i_SF,$SFsigma,$SFmean,$SFmedian,$max_isf,@SFscore_list);
  if($SFsum){
	#@SFscore_list = sort {$a <=> $b} split / /, $SFscores;
	@SFscore_list = split / /, $SFscores;
	$max_isf = scalar @SFscore_list;
	for ($i_SF = 0; $i_SF < $max_isf ; $i_SF++) {
		#$SFmedian = $SFscore_list[$i_SF] if($i_SF <= $max_isf / 2);
		$SFsigma += $SFscore_list[$i_SF];
	}
	$SFmean = $max_isf ? $SFsigma / $max_isf : 0;
	$SFmean = &precision($SFmean, 2);
	#$SFmedian = &precision($SFmedian, 2);
	if ($SFmean >= $SF_BOLD_IF_GREATER_THAN) {
		$SFmean = "<span style=\"color:'$redc'\"><b>" . $SFmean . "</b></span>";
	}
	$SFdisplay = $SFsigma;
    if ($SFdisplay < 10) {
	   $SFdisplay = &precision ($SFsigma, 2);
    } elsif ($SFdisplay < 100) {
	   $SFdisplay = &precision ($SFsigma, 1);
    } else {
	   $SFdisplay = &precision ($SFsigma, 0);
    }
	if (!$notnew && $SFdisplay < $SF_BOLD_IF_GREATER_THAN) {
		$explicit_group_deselect[$count] = 1;
		# please note: this will break if we ever revert to making it possible to toggle checkbox display state!  beware!
		$boxhtml =~ s! CHECKED!!;
	}
	#$SFmedian = "<b>" . $SFmedian . "</b>" if $SFmedian >= $SF_BOLD_IF_GREATER_THAN;
  }

  # added 7/28/99 by cmw: new popup window feature to choose different ref+descriptor for consensus line display
  my $link_to_other_refs = "&nbsp;" x 3;
  if ((!$with_others) && ($consensus_refs{$ref})) {

	my $num_other_refs = scalar(split(" ",$consensus_refs{$ref}));
	$num_other_refs = ($num_other_refs < 10) ? "+$num_other_refs" : "+$num_other_refs";
	#$link_to_other_refs = qq(<a href="javascript:showothers$i()" onMouseover="status='Click here to display other matching database entries'; return true" onMouseout="status=''; return true">$num_other_refs</a>);
	# above line also changed 1/29/02 to the following for mouseover functionality:
	$link_to_other_refs = qq(<span style="cursor:hand; color:blue; text-decoration:underline" onMouseover="showothers($i, this);" onMouseout="clearTimeout(PopupAppear); hideothers($i, event.x, event.y);">$num_other_refs</span>);

	# create a unique name for the popup window
	my $dir_id = $directory;
	$dir_id =~ s/\W//g;
	my $choosedescrip_name = "choosedescrip_$dir_id\_$i\_$^T";

###### added 1/29/02 to use mouseovers rather than popup window:
	print <<EOF;
<div class="scrolldiv" style="position:absolute; visibility:hidden; top:-1000; width:436; z-index:10" id="choosedescrip$i" onMouseout="hideothers($i, event.x, event.y);">
<table bgcolor="#e8e8fa" border=1 cellspacing=0 cellpadding=0 width=420>
EOF
	# the top attribute must be a large negative number on directories with any very large +n numbers (eg +55) to prevent the browser from showing a bunch of extra space
	foreach $r ($ref, split (" ", $consensus_refs{$ref})) {
		my $descrip = &printdescrip($r);
		$descrip =~ s/\n//g;
		$descrip =~ s/<.+?>//g;		# &printdescrip sometimes returns with <div> tags, they need to be removed
		if ($r eq $ref) {
			print qq(<tr><td class=smalltext>$countstr <b>$ref_long_form{$r}</b>:<br>$descrip</td></tr>\n);
		} else {
			print qq(<tr><td class=smalltext>$countstr <a href="javascript:changedescrip(\'$location{$ref}\',\'$r\');">$ref_long_form{$r}</a>:<br>$descrip</td></tr>\n);
		}
	}
	
	print <<EOF;
</table>
</div>
<input type=hidden name="differentdescrip:$location{$ref}" value="$ref">
EOF

###### end 1/29/02 addition

  }
  my $tsb = 35;
  my $tss = 8;

  if (!$notnew && (defined $BPsum) && (defined $numfiles) && !($numfiles >= $NUMFILES_GREATER_THAN)) {
	$explicit_group_deselect[$count] = 1;
	# please note: this will break if we ever revert to making it possible to toggle checkbox display state!  beware!
	$boxhtml =~ s! CHECKED!!;
  }



  print ("\n<div class=\"smalltext\">");      #   formerly: print ("\n<tt>");

  print qq(<table width=975 border=0 cellspacing=0 cellpadding=0><tr $table_heading_color valign=top><td class=smalltext width=5>);
  if ($boxhtml) {
	  print $boxhtml;
  }
  print qq(</td><td width=8 valign=top class="smalltext">);
  if (! $is_image) {
	  if ($DEFS_RUNSUMMARY{"Consensus group view"} eq "expanded" || $FORM{"expand_$ref"} eq "expanded") {
		  print ("<img src=\"/images/tree_open.gif\" id=\"$ref\" onclick=\"javascript:toggleGroupDisplay(this)\" style=\"cursor:hand\">");
		  print qq(<input name="expand_$ref" type="hidden" value="expanded">);
	  } else {
		  print ("<img src=\"/images/tree_closed.gif\" id=\"$ref\" onclick=\"javascript:toggleGroupDisplay(this)\" style=\"cursor:hand\">");
		  print qq(<input name="expand_$ref" type="hidden" value="collapsed">);
	  }
  }
  #print ("<U>") unless ($with_others);
  print "</td><td width=15 class=\"smalltext\">";
  print $countstr; 
  print "</td><td width=290 class=\"smalltext\">";
  
  $prettyref = $ref_long_form{$ref};
  #print (qq(<a target="_blank" href="$url">$prettyref</a>), $s x ($cons_reflen - length ($prettyref)) );
  # above line changed 2/21/02 to the following lines for mouseover functionality
  my $noDirURL;
  ($noDirURL = $url) =~ s/Dir=[^&]*//i;   # the directory does not need to be included here, will be added by javascript
  $noDirURL =~ s/&&/&/;
  $noDirURL =~ s/^[^\?]*\?//;             # program name also added in javascript.  note: the program used will be $retrieve rather than $consensus -- as of 2/21/02 these variables are identical
  ## changed to use an array:
  print qq(<span style="cursor:hand; color:blue; text-decoration:underline" onclick="refGoTo('RetrieveSel')" onmouseover="refSetVars(this, $refarray, 1);" onmouseout="clearTimeout(PopupAppear); HideChoices('RefGroupMenu', event.x, event.y);">$prettyref</span>);
  
  # end 2/21/02 addition
  print "&nbsp;&nbsp;$link_to_other_refs";
  #print "</td><td width=20 class=\"smalltext\" align=left>";
  
  print "</td>";

  
  #if($SFsum){
  # print ("$SFmean</td><td width=32 class=\"smalltext\">$SFmedian</td><td width=32 class=\"smalltext\">$score");
  #}else{
  # print "$score";
  #}

  #print "</td><td width=25></td><td width=15 class=\"smalltext\" align=right>";
  if ((defined $BPsum) && (defined $numfiles)) {
	$BPsum_sci = &sci_notation($BPsum);
    #$BPperc = ($BPTot != 0) ? int((100 * $BPsum_sci/$BPTot) + 0.5) : 0;
	$BPperc = ($BPTot != 0) ? (100 * $BPsum_sci/$BPTot) : 0;
	$colorsandvalues{$consensuscolor} = $BPperc;		# used for setting colors in the piechart applet
	$BPperc = int($BPperc + .5);
    
	#print ($s, $numfiles, "|$BPsum_sci|$BPperc%");
    $BPavg = &sci_notation($BPsum / $numfiles);
	$numfiles = "<span style=\"color:'$redc'\"><b>" . $numfiles . "</b></span>" if $numfiles >= $NUMFILES_GREATER_THAN;
	#print ($s x 3, $numfiles, "|&Sigma;:$BPsum_sci|$BPperc%|avg:$BPavg");
	#print ($numfiles, "</td><td width=50 class=\"smalltext\">", "&nbsp;&Sigma;:$BPsum_sci</td><td width=27 class=\"smalltext\" align=right>$BPperc%</td><td width=70 class=\"smalltext\">&nbsp;avg:$BPavg");
	print <<EOF;
<td width=65 class=smalltext>
<span style="color:'$purplec'">Sequences</span>:</td><td align=center width=28 class=smalltext>$numfiles
</td><td width=$tsb></td>
EOF
  }

  print "<td width=70 class=smalltext>";
  if($SFsum){
   $SFdisplay = "<span style=\"color:'$redc'\"><b>" . $SFdisplay . "</b></span>" if $SFdisplay >= $SF_BOLD_IF_GREATER_THAN;
   #print "$SFmean</td><td width=32 class=\"smalltext\">$SFmedian</td><td width=32 class=\"smalltext\">$score");
   print qq(<span style="color:'$purplec'">Score</span>:&nbsp;);
   print "$SFdisplay";    # or $SFmean
   print "</td><td width=$tsb></td>\n";
	#print "</span>";
  }else{
   print "&nbsp;";
  }
  if ((defined $BPsum) && (defined $numfiles)) {
	  print <<EOF;
<td width=25 class="smalltext">
<span style="color:'$purplec'">TIC</span>:</td><td align=right width=28 class="smalltext">$BPperc%
</td><td width=$tss class="advconstuff"></td><td width=14 class="smalltext advconstuff">
<span style="color:'$purplec'">&Sigma;</span>:</td><td width=40 class="smalltext advconstuff">$BPsum_sci
</td><td width=$tss class="advconstuff"></td><td width=28 class="smalltext advconstuff">
<span style="color:'$purplec'">Avg</span>:</td><td width=40 class="smalltext advconstuff">$BPavg
</td><td width=$tsb class="advconstuff"></td>
EOF
  }



  #print "</td><td align=right class=\"smalltext\">";


  # sneaky LISP functions like map() find their way into Perl....
  # we colorize the scoring so people can pick out what score corresponds to which files

  @temp = split (',', $score_breakdown_display);
  $j = 0;
  $score_breakdown_display = join (",", map { qq(<span style="color:$scorecolours[$j++]">$_</span>) } @temp);

  print qq(<td class="smalltext">);
  print qq(<span class="advconstufftoo">);
  print qq(<span style="color:'$purplec'">EYS</span>:&nbsp;$score&nbsp;);
  print "<a style='cursor:default' onmouseover=\"window.document.all['ref$count'].style.display=''\" onmouseout=\"window.document.all['ref$count'].style.display='none'\">";
  print "{$score_breakdown_display}";
  print "</a>\n";

  @temp = split (', ', $score_showfiles);
  $j = 0;

############################## changed by Vanko: ######################################################

  unless ($with_others) {
	undef $score_showfiles;
	my $group = 1;
	my $highlight_thresh = $MAX_RANK;
	$i = 0;
    foreach $val (@temp) {
	  $i++;
	  my $outp = "";
	  my $field;
	  foreach $field (split (" ", $val)) {
		if ($highest_rank[$field] && $highest_rank[$field] <= $highlight_thresh) {
			# if previously displayed, highlight it:
			$outp .= "<I>$field</I> ";
			push @{$hidden_outs_js{$groupnumber}}, $field if $i <= $MAX_RANK;
		} else {
			$outp .= "$field ";
			unless ($field eq "x") {
				$highest_rank[$field] = $group if (!$highest_rank[$field] || $highest_rank[$field] > $group);
			}
		} 
	  }
  	  chop $outp;
	  $score_showfiles .= qq(<span style="color:$scorecolours[$j++]">$outp</span>) . ", ";
	  $group++;
	}
    # remove last ", ":
    chop $score_showfiles;
    chop $score_showfiles;
  } else {
    $score_showfiles = join (", ", map { qq(<span style="color:$scorecolours[$j++]">$_</span>) } @temp);
  }

#######################################################################################################
  
  $score_showfiles_check = $score_showfiles;
  
  # following line commented out by LAB (lukas@pair.com) 8/20/01
  # it was stripping out the initial color tag (<span style="color:...)
  # i'm afraid there may be other ramifications i'm not aware of, however...
  #$score_showfiles_check =~ s/<[^>]*>//s;
  
  # note: 600 = approx. # of bytes in 2.5 lines of text => purely arbitrary...  2/7/01
  if (length ($score_showfiles_check) > 480) {
	$score_showfiles = substr ($score_showfiles_check, 0, 480);
	$score_showfiles =~ s/<[^>]*$//s;
    #$score_showfiles .= "</i></span> ...";  # not necessary, it appears
	$score_showfiles .= " ...";
  }

  #print ($s, "<span class=smalltext id=\"ref$count\" style=\"display:none\"><br>($score_showfiles)</span><br>\n");
  print "<span class=smalltext id=\"ref$count\" style=\"display:none\"><br>($score_showfiles)</span><br>\n";

  #print ("</U>") unless ($with_others);

  print qq(</span></td></tr></table></div>\n);

  #print ("<br>\n");

  $descrip_to_print = &printdescrip($ref);
  #my $descrip_to_print_truncated = $descrip_to_print;
  #$descrip_to_print_truncated =~ s/<.+?>//g;
  #my $truncate_to = 135;
  #if (length ($descrip_to_print_truncated) > $truncate_to) {
  #	  $descrip_to_print_truncated = substr ($descrip_to_print_truncated, 0, $truncate_to) . "...";
  #}
  my $descrip_to_print_span = $descrip_to_print;
  $descrip_to_print_span =~ s/<.+?>//g;

  # 150 is approximately the number of characters per line in this span tag -- so unless there is a way to determine
  # whether the line wraps at run time, this is the only way to decide if a span is needed
  unless (length $descrip_to_print_span < 150) {
	  $descrip_to_print_span = qq(<span style="cursor:hand; text-align:justify; width:920; height:13; overflow:hidden" onclick="toggleOverflow(this);">$descrip_to_print_span</span>);
  }
  #print qq(<table width=975 border=0 cellspacing=0 cellpadding=0><tr><td width=45></td><td $table_contents_color class=smalltext>$descrip_to_print_truncated</td></tr></table>);
  print <<EOF;
<table width=975 border=0 cellspacing=0 cellpadding=0>
<tr>
<td width=45></td>
<td $table_contents_color class=smalltext>
$descrip_to_print_span
</td>
</tr>
</table>

EOF


  print "<tt>";   # formerly: print "</tt>" . $descrip_to_print . "<tt>"
  

  if (($with_others) && ($consensus_refs{$ref})) {
    my @r = ();
    foreach $r (split (" ", $consensus_refs{$ref})) {
      $url =  $baseurl . "&Ref=$r";
      push (@r, qq(<a target="_blank" href="$url">$r</a>));
    }
    print ($s x 8, join (",$s", @r), "<br>\n");
  }
  print ("</tt>\n");
}

## this subroutine prints out the database descriptor line for its argument, a reference to a protein
## in the database:
##
## If the index does not exist, it will search the info it has culled from the outfiles. It will premark
## those with an asterisk, however.
##
## generalized by cmw (11/2/98): now it returns a string instead of printing it
sub printdescrip {
  my($ref) = $_[0];
  my ($myref, $refstuff, $refline, @linedata, @reflines);
  my $retstring;
  

  $pdfontheader = "<div class=\"smalltext\">";   # these variables are used to change font in bericht report
  $pdfontender = "</div>\n";                     #
  # formerly: $retstring = "<span class=\"reflinefont\">";
  $retstring = $pdfontheader;

#  $myref = &parseentryid($ref . "|");   # doesn't work because of "|"; why is it there? -cmw
  $myref = &parseentryid($ref);


  $refline = substr(&lookupdesc($myref), 0, 300);

  ($refstuff, @linedata) = split(/\s/, $refline);

  if ($refline ne "") {
    $retstring .= "@linedata<br>\n";
  } else {
    @reflines = split(/\n/, $refdata{$myref});
    @reflines = @{$refdata{$myref}};
    if ($reflines[0] ne "") {
      foreach $i (0..$#reflines) {
        $reflines[$i] =~ s/\s$//;
      }
      $refline = substr(join('',@reflines),0,300);
      $retstring .=  "*$refline<br>\n";
    }
  }

  $retstring .= $pdfontender;
  return $retstring;
}

##PERLDOC##
# Function : get_group_letter
# Argument : $rank - The rank number of the group
# Globals  : $consensi_letterstr - The string of letters to use for the group characters
# Returns  : The characters that make up the group name
# Descript : Takes a rank value and comes up with the appropriate letter for that group
# Notes    : 
##ENDPERLDOC##
sub get_group_letter {
	my ($rank) = (@_);

	# First check to see how many characters to put together
	my $firstChar = ($rank / 26) - 2;  # 52 characters with a-z and A-Z
	my $secondChar = ($rank % 26) + 26; # Add the 26 to get all lower case for the lookup

	my $letter;
	if ($rank >= 52) {
		$letter = substr ($consensi_letterstr, $firstChar, 1);
		$letter .= substr ($consensi_letterstr, $secondChar, 1);
	} else {
		$letter .= substr ($consensi_letterstr, $rank, 1);
	}
	return $letter;
}

## this subroutine prints out the sequence for the given reference.
sub print_seq {
  my($ref, $peps) = (@_);
  my ($myref, @seq, $line, $seq);

#  $myref = &parseentryid($ref . "|");   # doesn't work because of "|"; why is it there? -cmwendl
  $myref = &parseentryid($ref);
  
  @seq = &lookupseq($myref);

  # print FASTA header:
  $line = shift @seq;
  print (&HTML_encode ($line), "<br>\n");

  $seq = join ("", @seq);
  &highlight_peps_in_seq ($seq, $peps);

#  print &printdescrip($ref);
}

## this routine pretty-prints the sequence, with highlighting of all internal peptides
## found in the array reference by "$peps"

sub highlight_peps_in_seq {
  my ($seq, $peps) = @_;
  my (@matcharray, $pos, $len, $i);
  
 LOOP:
  foreach $pep (@{$peps}) {
    $len = length ($pep);

   SEARCH:
    while ($seq =~ m!$pep!g) {
      $pos = pos($seq);
    
      for ($i = $pos - $len; $i < $pos; $i++) {
        $matcharray[$i] = 1;
      }

      # reset search position to just after *beginning* of last match
      pos ($seq) = $pos - $len + 1;
    }
  }

  my ($matchHTML) = qq(<span style="color:#FF0000"><u><b>);
  my ($unmatchHTML) = "</u></b></span>";

  $len = length ($seq);
  for ($i = 0; $i < $len; $i++) {

    # put in a space after every ten, a <BR> after every 60:
    if (($i % 10 == 0) && ($i != 0)) {
      if ($i % 80 == 0) {
        print ("<br>");
      }
      print ("\n");
    }

    # if we start a matching area, put in the match HTML:
    print $matchHTML if ($matcharray[$i] && (($i == 0) || !$matcharray[$i - 1]) );

    print substr ($seq, $i, 1); # print the AA

    # if we are leaving, put in the end of the match HTML:
    print $unmatchHTML if ($matcharray[$i] && !$matcharray[$i + 1]);
  }
  # 
  print ("<br>\n"); # we need to finish with a CR
}

##
## this subroutine calculates a score for a quick reference
## for use in grading relative importance of proteins
##
## The global variable $numscores counts how many scoring
## categories we keep. if $numscores is "n", then we have
## 1st, 2nd, ..., (n-1)th, and then, altogether "nth and lower".
##
## Output:
##   First: the total score
##   Second: the list of number of hits per category excluding repeated peptides (used for calculating score)
##	 Third: the list of totoal number of hits per category whether or not peptides are repeated (used for display purposes)
##   Fourth: the list of file numbers, per category
##   Fifth: the list of peptides (separated by "+") to send to consensus
##
sub consensus_score {
  my ($ref) = @_;
  my $score = 0;

  my ($i, $num, $ranknum, $pep, $pep_mods);
  my ($breakdown, $filelist, $peplist);
  my (@filenumlist, @scorelist,@scorelist_display);
  my (@peps);

  ## initialize the scorelist to all zeros
  for ($i=0; $i < $numscores; $i++) {
    $scorelist[$i] = 0;
	$scorelist_display[$i] = 0;
    $filenumlist[$i] = "";
  }

  ## We make the following modification: to avoid single files
  ## counting multiple times, a single file is allowed only once
  ## EXCEPT if the file matches against more than one peptide of
  ## the reference. In this case, it counts once for each peptide
  ## that matches the reference.

  # a hash for matching already seen peps
  # keys will be "$pep"
  my (%pep_seen);

  # hash for peps to be put in the $peplist
  my (%in_peplist);

  # a hash for matching already seen file-peptide combos
  # keys are "$i:$pep"
  my (%file_pep_seen);

  # a hash for files actuall counting toward a consensus
  my (%file_used);

  ## for each file which references this $ref, we put
  ## the file number ($i) into the array @filenumlist
  ## according the value of $num (its ranking in the
  ## .out file).
  ##

  my @temparr = split (" ", $location{$ref});
  my %n;
  # sort by importance in .out file
  foreach $index (@temparr) {
    ($n{$index}) = $index =~ m!:(\d+)!;
  }
  @temparr = sort { $n{$a} <=> $n{$b} } @temparr;

  foreach $index (@temparr) {
    ($i, $num) = $index =~ m!(\d+):(\d+)!;

    # take off diff mods to avoid problems with differential mods.
    $pep = &cleanpep($peptide{$index});
	$pep_mods = $peptide{$index};			# keep a version with mods
    $pep =~ s!\(.\)!!; # remove preceding aa
	$pep_mods =~ s!\(.\)!!; # remove preceding aa

    next if ($file_pep_seen{"$i:$pep"});

    $file_pep_seen{"$i:$pep"} = 1;

    # since @temparr is already sorted by rank in the .out file,
    # in order to count each .out file once, for its highest match,
    # we simply count it just the first time.
    # In addition, for a given peptide, we want to count it only
    # once, at its highest level, but those .out files that match
    # should be mentioned (in $filenumlist) if not counted directly.

    # count all hits below a certain rank at the same, minimal level:
    $realnum = &min ($num, $numscores);

    $filenumlist[$realnum-1] .= " " . ($i + 1);

    ## changed by Martin 98/07/06:
    # pulled the line "$scorelist[$realnum-1]++;" out of the "if"
    # statement so it can stand up and be counted in the per-category tally
    # ($breakdown) but not counted toward the $score.
    #
    # to undo this change, comment out the following line and uncomment
    # its twin just after the "if" statement. (wsl reversed 98/07/07)
    #$scorelist[$realnum-1]++;

	# as of 10/19/01 the new spec for runsummary is that the counts which are displayed are independant of whether the peptide has been seen
	$scorelist_display[$realnum-1]++;

	if (!$pep_seen{$pep}) {			
      $scorelist[$realnum-1]++;

      # if ranked high enough, add to the peplist and the score
      if ($num <= $MAX_RANK) {
        $score += $scorearr[$realnum-1];

		push (@peps, $pep_mods) unless ($in_peplist{"outfile: $i"} || $in_peplist{$pep});
		$in_peplist{"outfile: $i"} = 1;
		$in_peplist{$pep} = 1;

        $file_used{$i} = 1;
      }
      $pep_seen{$pep} = 1;
    }								
  }

  ## return undefined if only one significant file seen
  return undef if (scalar (keys %file_used) < 2);

  ## return undefined if only one distinct peptide is seen
  return undef if (scalar (@peps) < 2); 

  # create list of peps up to 1500 chars long (the maximum for ie > 4.0 is 2083 characters, and this includes server name and path)
  ## 6/25/02: no longer need to worry about length because the values are now submitted using POST
  #my $len;
  $peplist = "";
  while ($pep = shift @peps) {
    #$len += length($pep) + 1;
    #last if ($len > 1500);
    $peplist .= "$pep+"
  }
  $peplist =~ s!\+$!!;

  $breakdown = join (",", @scorelist);
  my($breakdown_display) = join (",", @scorelist_display);

  ## this is the breakdown by file numbers within the categories
  ##
  ## Remember that modification of the stepping variable (in this
  ## case, $list) within a foreach loop alters the value *inside*
  ## the given array.
  ##
  ## we make it "x" if there are no files for this reference in this
  ## score category; otherwise, we order them numerically.
  ##
  foreach $list (@filenumlist) {
	if ($list eq "") {
      $list = "x";
    } else {
      # sort numerically
      $list = join (" ", sort { $a <=> $b } split (" ", $list));
    }
  }
  $filelist = join (", ", @filenumlist);
  return ($score, $breakdown, $breakdown_display, $filelist, $peplist);
}

## returns the peptide sequence cleaned
## of all non-alphabetic characters.

sub cleanpep {
  my ($pep) = @_;

  $pep =~ tr!#*@\$\^\~\[\]!!d;

  return $pep;
}


##
## &URLs_of_seq creates a string to be included in an URL to a helper program
## Since this will go to a web page, ampersands are represented with "&"
##
## Return array:
##   the first element is an URL suitable for the displayions family of apps
##   the second is an URL suitable for database helper programs (retrieve, blast)
##   the third is the peptide sequence suitable for sending to BLAST
##
## Arguments:
##   First arg is the raw peptide string from the .out file
##   second is the truncated file name.
##
## The file number is not used right now, but probably will be as this gets more
## sophisticated.

sub URLs_of_seq {
  my ($pep, $file) = @_;
  my ($filenum) = $number{$file};

  my ($cleanpep, $disppepurl, $dbpepurl, $blasturl, $blasturl_NoJS);
  
  my ($mods) = $mods[$filenum];
  my ($mod1, $mod2, $mod3);

  # remove extraneous characters from the peptide for use in URLs
  # '*' and '#' mark sites of differential modifications -- so does '@'
  $extendedpep = &cleanpep($pep);

  # remove the parentheses of the preceding or following amino acid
  $extendedpep =~ tr!()\-!!d;

  # remove the parens AND the preceding or following aa
  ($shortpep = $pep) =~ s!\(.\)!!;
  $cleanpep = $shortpep;

  ## $diffsite is a string of numbers, each of which corresponds to
  ## one amino acid in the sequence.
  ##
  ## here, we mark $diffsite according to the differential mods
  ## present. "2" is used for the '#' mods, "1" for the '*' mods
  ##
  ## The positions of unmodified amino acids are marked with "0".

  if ($shortpep =~ m![\#\*\@\^\~\$\]\[]!) {
    my ($pos, $diff, $diffsite);
    my ($count);

    my ($mods) = $mods[$filenum];
    my ($mod1, $mod2, $mod3, $mod4, $mod5, $mod6, $mod7, $mod8);

    # the modifications are in the form "(M# +16.0)"
    # or "(STY* +80.0)". Possibly negative.

	($mod1) = $mods =~ m!\(.*?\* (.*?)\)!;
    ($mod2) = $mods =~ m!\(.*?\# (.*?)\)!;
	($mod3) = $mods =~ m!\(.*?\@ (.*?)\)!;
	($mod4) = $mods =~ m!\(.*?\^ (.*?)\)!;
	($mod5) = $mods =~ m!\(.*?\~ (.*?)\)!;
	($mod6) = $mods =~ m!\(.*?\$ (.*?)\)!;
  	($mod7) = $mods =~ m!\(.*?\] (.*?)\)!;
  	($mod8) = $mods =~ m!\(.*?\[ (.*?)\)!;
  
    # url-escape the "+" and "-" characters:		(No, that isn't what &cleanpep does.  &cleanpep removes mod site characters)
    $cleanpep = &cleanpep ($cleanpep);

    $count = 0;
    $diffsite = "0" x (length ($cleanpep));

    while ($shortpep =~ m!([\#\*\@\^\~\$\]\[])!g) {
      # first or second (or third) diff mod?
      $number = ($1 eq "*") ? "1" : 
				($1 eq "#") ? "2" :
				($1 eq "@") ? "3" :
				($1 eq "^") ? "4" :
				($1 eq "\~") ? "5" :
				($1 eq "\$") ? "6" : 
				($1 eq "\]") ? "7" : 
				($1 eq "\[") ? "8" : "9";
 
	  $pos = pos ($shortpep) - 1 - ($count);
      $count++;

      substr ($diffsite, $pos - 1, 1) = $number;
    }

    $disppepurl = "DSite=$diffsite&";
    $disppepurl .= "DMass1=" . &url_encode($mod1) . "&" if (defined $mod1);
    $disppepurl .= "DMass2=" . &url_encode($mod2) . "&" if (defined $mod2);
    $disppepurl .= "DMass3=" . &url_encode($mod3) . "&" if (defined $mod3);
    $disppepurl .= "DMass4=" . &url_encode($mod4) . "&" if (defined $mod4);
    $disppepurl .= "DMass5=" . &url_encode($mod5) . "&" if (defined $mod5);
    $disppepurl .= "DMass6=" . &url_encode($mod6) . "&" if (defined $mod6);
    $disppepurl .= "DMass7=" . &url_encode($mod7) . "&" if (defined $mod7);
    $disppepurl .= "DMass8=" . &url_encode($mod8) . "&" if (defined $mod8);

  }

  $disppepurl .= "Pep=$cleanpep";
  $disppepurl .= "&Dta=" . &url_encode("$seqdir/$directory/$file" . ".dta");
  $disppepurl .= "&MassType=$masstype[$filenum]";
  $disppepurl .= "&NumAxis=1&ISeries=$ionstr[$filenum]";
  $disppepurl .= &URLized_mods($filenum) if ($mods[$filenum]);
  $dbpepurl = "Db=" . &url_encode("$dbdir/" . $database[$filenum]);
  $dbpepurl .= "&NucDb=1" if ($is_nucleo[$filenum]);
  $dbpepurl .= "&MassType=" . $masstype[$filenum];
  $dbpepurl .= "&Pep=" . $shortpep;			# changed 7/22/02 - want to leave the mod site characters in for selective use later

  my $db = $database[$filenum];
  # remove the .fasta suffix:
  $db =~ s!\.fasta!!;

  # calculate URL for the sequence blast
  # this blast uses the previous or following amino acid, if it exists
  $blasturl_NoJS = "$remoteblast?$sequence_param=$extendedpep&";  # the _NoJS variables are used for DTAVCR
  $blasturl = "Pept=$extendedpep&";   # $blasturl is only used in the runsummary page itself, so it can be changed in this function without affecting reports
									  # $blasturl here is not actually a URL, but is used to pass information that javascript uses to open the correct windows

  if (($db eq "est") || ($db =~ m!dbEST!i)) {
    $blasturl .= "Oth=dpanucdb";
	$blasturl_NoJS .= "$db_prg_aa_nuc_dbest";
  } elsif ($db eq "nt") {
    $blasturl .= "Oth=dpanucnr";
	$blasturl_NoJS .= "$db_prg_aa_nuc_nr";
  } elsif ($db =~ m!yeast!i) {
    $blasturl .= "Oth=dpaayst";
	$blasturl_NoJS .= "$db_prg_aa_aa_yeast";
  } else {
    $blasturl .= "Oth=dpaanr";
	$blasturl_NoJS .= "$db_prg_aa_aa_nr";
  }

  ## our default parameters for display and significance:
 
  $blasturl_NoJS .= "&$word_size_aa&$expect&$defaultblastoptions";

  return ($disppepurl, $dbpepurl, $blasturl, $blasturl_NoJS);
}


##
## sort subroutines
##

sub by_BP {
  $BP{$b} <=> $BP{$a} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

sub sort_by_ions {
  my @outs = @_;
  my %i;
  my ($numerator, $denominator);

  foreach $out (@outs) {
    ($numerator, $denominator) = $ions{"$number{$out}:1"} =~ m!(\d+)/(\d+)!;
    $i{$out} = $denominator ? ($numerator/$denominator) : 0;
  }

  return sort { $i{$b} <=> $i{$a} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"} } @outs;
}

sub by_ref {
  $ref{"$number{$a}:1"} cmp $ref{"$number{$b}:1"} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}


sub by_prev_aa {
  $peptide{"$number{$a}:1"} cmp $peptide{"$number{$b}:1"} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

sub by_sp {
  $Sp{"$number{$b}:1"} <=> $Sp{"$number{$a}:1"} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

sub by_rsp {
  $rankSp{"$number{$a}:1"} <=> $rankSp{"$number{$b}:1"} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

sub by_Xcorr {
  $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

sub by_Sf{
  $combinedscores{"$b.dta"} <=> $combinedscores{"$a.dta"};
}

sub by_prob {
  $probscoresByFile{"$a.dta"} <=> $probscoresByFile{"$b.dta"};
}

sub by_ckbox {
  $sa = $selected{$a} ? 1 : 0;
  $sb = $selected{$b} ? 1 : 0;
  if ($sa) {
	  return -1;
  } elsif ($sb) {
	  return 1;
  } else {
	  return 0;
  }
}


sub sort_by_mass {
  my %mass;

  # 29.3.98: changed by Martin to match the fact that
  # the mass displayed reflects the experimental mass
  foreach $out (@_) {
#    $mass{$out} = $MHplus{"$number{$out}:1"} || $mass_ion[$number{$out}];
     $mass{$out} =  $mass_ion[$number{$out}];
  }
  return sort { $mass{$a} <=> $mass{$b} ||
		  $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"}
	      } @_;
}

## remember that we are given the *truncated* file name
## (".out" had been dropped) in $a and $b. Thus the
## charge state is the last character in the filename.

sub by_charge {
  substr ($a, -1) <=> substr ($b, -1) || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
}

# sort by absolute value first, then by sign
sub sort_by_delM {
  my $i;
  my %del;

  foreach $out (@_) {
    $i = $number{$out};
    $del{$out} = $mass_ion[$i] - $MHplus{"$i:1"};
  }
  return sort {
    ( abs ($del{$a}) <=> abs ($del{$b}) ) || ( $del{$a} <=> $del{$b} )
      || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"};
  } @_;
}

sub sort_by_delCn {
  my %i;
  foreach $out (@_) {
    $i{$out} = &get_delCn("$number{$out}:1");
  }
  return sort { $i{$b} <=> $i{$a} ||
		  $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"}
	      } @_;
}

sub sort_by_gbu{
	my %i;
	my($out,$z);
	foreach $out (@_) {
		$out =~ /\.(\d)$/;
		$z = $1;
		$i{"$out"} = ($z==1 or  $z ==2) ? $gbuscores{"$out.dta"} : -2 ;
	}

	return sort {$i{"$b"} <=> $i{"$a"}} @_;
}
	

sub sort_by_seq {
  my (%s, $index);

  foreach $out (@_) {
    $index = $number{$out} . ":1";
    ($s{$out} = $peptide{$index}) =~ s!\(.\)!!;
  }

  return sort { $s{$a} cmp $s{$b} || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"} } @_;
}

##
## this sorts by rank in the consensus
##
sub sort_by_rank {
  my (%r);

  foreach $out (@_) {
    $r{$out} = $ranking[$number{$out}];
  }

  return sort {
     defined $r{$b} <=> defined $r{$a} || $r{$a} <=> $r{$b}
     || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"}
  } @_;
}

##
## end of sort subroutines
##
    
sub output_form {

	# get default settings from microchem_var.pl
	$checked{$DEFS_RUNSUMMARY{"Show/Sort by"}} = " CHECKED";
	$checked{$DEFS_RUNSUMMARY{"Secondary sort field"}} = " selected";

  print "<HR><br style='font-size:25'>\n";
  my $dirheading = &create_table_heading(title=>"Directory");
  my $displayheading = &create_table_heading(title=>"Display Options");
  my $helplink = &create_link();
  print <<EOM;
<script language=javascript>
	function disableSortBy(disabled) {
		var sortByOption = document.getElementById("sortbyoption");
		var sortBy = document.getElementById("sortby");
		var sortByTitle = document.getElementById("sortbytitle");
		var conshow = document.getElementById("conshow");
		var chroshow = document.getElementById("chroshow");
		var depth = document.getElementById("depth");
		var depthtitle = document.getElementById("depthtitle");
		if (disabled != "no") {
			action = "true";
			sortByOption.checked = "";
		}
		else {
			action = "";
			conshow.checked = "";
			chroshow.checked = "";
		}
		if (!conshow.checked) {
			depth.disabled = "true";
			depthtitle.disabled = "true";
		}
		else {
			depth.disabled = "";
			depthtitle.disabled = "";
		}
		sortBy.disabled = action;
		sortByTitle.disabled = action;
}

</script>
<FORM ACTION="$ourname" METHOD=POST>
<TABLE BORDER=0 cellspacing=0 cellpadding=0>
<tr><td width=60></td>
<td>
<TABLE BORDER=0 cellspacing=0 cellpadding=0 width=425>
<tr><td colspan=2>$dirheading</td></tr>
<tr><td><table class=outline BORDER=0 cellspacing=0 cellpadding=0 width=425>
	<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td colspan=5 bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
	
<tr height=33><td class=title width=80>&nbsp;</td>
	<td class=data>&nbsp;
EOM
 
  my $dropbox = make_sequestdropbox("directory");
  print $dropbox;

  my $pull_to_top_chk = " CHECKED" if ($DEFS_RUNSUMMARY{"Pull to Top"});

  print <<EOM;
</td></tr>
</TABLE></td></tr></table>
</td></tr></table>
<br style="font-size:30">
<TABLE BORDER=0 cellspacing=0 cellpadding=0>
<tr><td width=60></td>
<td>
<TABLE BORDER=0 cellspacing=0 cellpadding=0 width=425>
<tr><td>$displayheading</td></tr>
<tr><td><table class=outline BORDER=0 cellspacing=0 cellpadding=0 width=425>
	<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td colspan=5 bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
<tr height=25>
	<td class=title width=80>Show:&nbsp;&nbsp;</td>
	<td class=data>&nbsp;<INPUT TYPE=RADIO NAME="sort" id="conshow" VALUE="consensus"$checked{"Consensus"} onclick="disableSortBy()">Consensus</td>
	<td class=data width=200 id=depthtitle>Depth&nbsp;<INPUT TYPE=TEXT id=depth NAME="max_rank" SIZE=2 MAXLENGTH=2 VALUE="$DEFS_RUNSUMMARY{"Max rank"}" style="font-size:12"></td></tr>
<tr height=25>
	<td class=title width=80>&nbsp;</td>
	<td class=data colspan=2>&nbsp;<INPUT TYPE=RADIO NAME="sort" id="chroshow" VALUE="chromatogram"$checked{"Chromatogram"} onclick="disableSortBy()">Chromatogram&nbsp;&nbsp;
</td></tr>
<tr height=25>
	<td class=title width=80>&nbsp;</td>
	<td class=data colspan=2>&nbsp;<input type=radio name="sortbyoption" id="sortbyoption" onclick="disableSortBy('no')">Sort By:</td>
</tr>

<tr height=25>
	<td class=title id="sortbytitle" disabled="true" width=80>&nbsp;</td>
	<td class=data colspan=2>&nbsp;&nbsp;<span class=dropbox><select name="sort" id="sortby" disabled="true">
		<option VALUE="z"$checked{"Charge State"}>Charge State (z)
		<option VALUE="xC"$checked{"Cross Correlation Value"}>Cross Correlation Value (x 10^4)
		<option VALUE="Ref"$checked{"Database Reference"}>Database Reference
		<option VALUE="dCn"$checked{"Delta Cn"}>Delta Cn (Cn = Normalized Correlation)
		<option VALUE="dM"$checked{"Deviation from Exp. MH+"}>Deviation of Sequence from Experimental MH+
		<option VALUE="File"$checked{"Filename"}>Filename (Scan Number)
		<option VALUE="ions"$checked{"Fragment Ions Hit Ratio"}>Fragment Ions Hit Ratio
		<option VALUE="fBP"$checked{"Full Scan Base Peak"}>Full Scan Base Peak (fBP)
		<option VALUE="maxBP"$checked{"Max Full Scan Base Peak"}>Max Full Scan Base Peak (maxBP)
		<option VALUE="TIC"$checked{"MSMS Total Ion Count"}>MSMS Total Ion Count (TIC)
		<option VALUE="Sequence"$checked{"Peptide Sequence"}>Peptide Sequence
		<option VALUE="mhplus"$checked{"Precursor MH+"}>Precursor MH+
		<option VALUE="sp"$checked{"Preliminary Score"}>Preliminary Score (Sp)
		<option VALUE="()"$checked{"Previous Amino Acid"}>Previous Amino Acid
		<option VALUE="rsp"$checked{"Rank of Preliminary Score"}>Rank of Preliminary Score (RSp)
		<option VALUE="zBP"$checked{"Zoom Scan Base Peak"}>Zoom Scan Base Peak (zBP)
	</select></span>&nbsp;&nbsp;
</td></tr>
<tr height=25>
	<td class=title width=80>Max List:&nbsp;&nbsp;</td>
	<td class=data colspan=2>&nbsp;&nbsp;<INPUT TYPE=TEXT NAME="max_list" SIZE=4 MAXLENGTH=5 VALUE="$DEFS_RUNSUMMARY{"Max list"}" style="font-size:12"></td>
</TR>	
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td colspan=5 bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
</table>
<tr height=50 valign=bottom><td colspan=2 align=right><INPUT TYPE="SUBMIT" CLASS="outlinebutton button" style="width=50" VALUE="Run">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$helplink</td></tr>	
</table> </td></tr></table>
</FORM>

EOM

# removed by wsl 991024  If needed again, it should be placed the line before /form tag above
#<INPUT TYPE=CHECKBOX NAME="load_dta_vcr" VALUE=1 CHECKED>Enable DTA VCR?<br>

}

# this subroutine is called by &do_execution() if we need to make a new FASTA database for the new directory
# to be run against.

sub maka_fasta {
  my (%args) = @_;
  my ($new_db, $autoindex, $append, $copyhosts, $autoindex, $silent) = 
     ($args{"new_db"}, $args{"autoindex"}, $args{"append"}, $args{"copyhosts"}, $args{"autoindex"}, $args{"silent"});
  my ($temp, @seq, $myref, $append_matchname);
  my (@selected) = split (", ", $FORM{"selected"});	#this field contains the reference numbers
  my (@no_index);
  my (%databased);
  my (%headers);
  my $protein;
  my %processed;

  if (&UserSelectedSkip()) {
	print "skipped";
	return;
  }
  &VerifyOverwrite("$dbdir/$new_db", $silent);

  &group_and_score() if ($pull_to_top);	# pull to top fix (grouping/scoring is necessary for pull to top functionality)
                                        # and this function isn't called if the script has an execute command (i.e. make tsunami)

  # these have cleverly stored in the form itself:
  foreach $out (@selected) {
	$protein = $ref{"$number{$out}:1"};
	$protein = $pull_to_top_ref{$out} if ($pull_to_top && $pull_to_top_ref{$out});	# pull to top fix
	$databased{ $database[ $number{$out} ] } .= ":$protein";
  }  

  open (NEWDB, ">$dbdir/$new_db") || &error ("Cannot create new database $dbdir/$new_db. $!");

  # we always include append file, so there is no need to include proteins/nucleotides from it:
  $append_matchname = $append;
  $append_matchname =~ s/\./\\./g;

  my $count = 0;
  foreach $db (keys %databased) {
    next if ($db =~ m!^$append_matchname$!i);

    # open each database only once:
    &openidx ("$dbdir/$db") || push (@no_index, $db) && next;
    $error = 0;

    foreach $protein ( split (':', $databased{ $db }) ) {
      next unless $protein;

      $myref = &parseentryid( $protein );
      next if $processed{$myref};

	  print '.' if ($count % 1000 == 0);
	  $count++;

	  @seq = &lookupseq($myref);
	  if ($#seq != -1) {	# Tim 5/24/00 - to avoid blank lines in db
		print NEWDB (join ("\n", @seq), "\n\n");	
        push (@{$headers{$db}}, $seq[0]); # save the header lines for later display
	  } else {
		print $error ? '<br>' : '<p>';
	  	$error = 1;
        # sequence lookup failed
		$DbDate = &get_datestamp((stat ("$dbdir/$db"))[9], '/');
		$FlatFile = &RemoveExtension("$dbdir/$db") . $FLAT_FILE_INDEX_SUFFIX;
		$FlatFileDate = &get_datestamp((stat ($FlatFile))[9], '/');
		print "<span><font color=red>$ICONS{'error'}The reference <b>$myref</b> could not be found in <a href=\"$webdbdir/$db\">$db</a></font></span>\n";
	  }
      $processed{$myref} = 1; # don't look at this reference again
    }
	if ($error) {
		$FlatFile = &GetFilename($FlatFile);
		print "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"$webdbdir/$db\">$db</a> last modified on $DbDate";
		print "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href=\"$webdbdir/$FlatFile\">$FlatFile</a> last modified on $FlatFileDate<br>&nbsp;";
	}
    &closeidx();
  }

  print ("Unable to open index file for database(s) ", join (", ", @no_index), "<br>\n") if (@no_index);

  # copy over contaminants to the end of our new database:
  if ($append) {
	  open (CONTAM, "$dbdir/$append") || ($append = "<font color=red>Unable to open $append");
	  print NEWDB while (<CONTAM>);
	  close CONTAM;
  }

  close NEWDB;
  print '<font color="#008000"><b>done.</b></font>';

  &PrintDbCreationResults(db        => $new_db,
                          include   => (($append) ? $append : ''),
                          appended  => '0',
                          copyhosts => $copyhosts,
                          autoindex => $autoindex,
						  nonextbar => $silent);
 

  print '<p>';

  if (!$silent) {
	  $append =~ s!\.!\\.!;	# replace . in filename with \. for r.e. matching
	  foreach $db (keys %databased) {
		next if ($db =~ m!^$append$!i);

		next if grep { $db eq $_ } @no_index;

		print qq(From <a href="$webdbdir/$db">$db</a>: <br><tt>);
		print join ("<br>\n", @{$headers{$db}} );
		print ("</tt><p>");
	  }
  }

  return;
}

# this subroutine runs Sequest on the given directory against the given database
sub smack_momma {
  my (%args) = @_;
  my ($db, $dir, $operator, $host) = ($args{"db"}, $args{"dir"}, $args{"operator"}, $args{"host"});

  my ($oldparams_exist, $files, $cmdline, $args);

  chdir("$seqdir/$dir");

  opendir (DIR, ".");
  my (@dtafiles) = grep { /\.dta$/ } readdir (DIR);
  closedir DIR;

  &error ("No such database: $db") if (! (-f "$dbdir/$db"));
#  $files = "-D$dbdir/$db " . join (" ", @dtafiles);			# necessary: we can specify database without editing seqparams
#  $files = "-$dbdir/$db " . join (" ", @dtafiles);			# this version works with SequestC1 only (the above for C2 only)
  $files = join (" ", @dtafiles);

  if ( -f "sequest.params") {
    rename ("sequest.params", "sequest.params.tempbak");
    $oldparams_exist = 1;
  }

  open (DEFAULT, "$default_seqparams") || &error ("Could not open default sequest.params file.");
  open (PARAMS, ">sequest.params") || &error ("Could not write to sequest.params file.");
  while (<DEFAULT>) {
	s!^(database\s*=\s*)(.+?)(\s*;|\s*$)!$1$dbdir/$db$3!m;
	s!^(database_name\s*=\s*)(.+?)(\s*;|\s*$)!$1$dbdir/$db$3!m;
	s!^(enzyme_number\s*=\s*)(.+?)(\s*;|\s*$)!${1}0$3!m;  # no enzyme
	print PARAMS $_;
  }
  close DEFAULT;
  close PARAMS;

  # run Sequest on local machine with newly created database
  $seqid = "TSUNSEQ$dir" . "_" . time();
  $error = &sequest_launch("seqid" => $seqid, "dir" => $dir, "db" => $db, "files" => $files, "onServer" => $host);
  &error("Failed to run Sequest: $error") if ($error);

  # write to log file (added by cmw,7-24-98)
  &write_log($dir,"Sequest started (automated) " . localtime() . " $db " . " No Enzyme " . " $operator");

  $cmdline = "$sequest $files";
  $onhost = ($host) ? " on $host" : '';
      print <<EOM;
<br>
&nbsp;&nbsp;&nbsp;&nbsp;Sequest is now running on <a href="$webseqdir/$dir">$dir</a>
against <a href="$webdbdir/$db">$db</a>$onhost.
EOM

@text = ("View new Sequest summary", "View Sequest status", "Go to Inspector", "Go back to Sequest Summary");
@links = ($createsummary . "?directory=$dir", $seqstatus, $inspector . "?directory=$dir", $createsummary . "?directory=$FORM{'directory'}&sort=consensus");
&WhatDoYouWantToDoNow(\@text, \@links);

  sleep 5;

  # restore old params file if necessary
#  if ($oldparams_exist) {
#    unlink("sequest.params");
#    rename("sequest.params.tempbak", "sequest.params");
#  }
}



#
# &do_execution();
#
# Implements the drop-down list box actions
#
sub do_execution {
	my ($action, $op, $comments) = ($FORM{"DTA_action"}, $FORM{'op'}, $FORM{'comments'});
    ($truncated = $directory) =~ s!_.*!!;

    $operator =~ tr/A-Z/a-z/;
	$comments = &encode_comments($FORM{"comments"});

	# show output immediately
	$|=1; 

	if ($action eq 'tsunami') {
		my ($newdb, $includecontam, $autoindex, $copyhosts, $clonedir, $includeouts, $run, $runhost, $alldtas) = 
		   ($FORM{'makefasta'}, $FORM{'includecontam'}, $FORM{'autoindex'}, $FORM{'copyhosts'}, $FORM{'clonedir'},
		    $FORM{'includeouts'}, $FORM{'run'}, $FORM{'runhost'}, $FORM{'alldtas'});
		my $silent = ($run || $clonedir) ? 1 : 0;

		# 1) Make Fasta
		print "<hr><p><img src=\"$webimagedir/circle_1.gif\"> Making FASTA database...";
		$copyhosts = &AddToStringList($runhost, $copyhosts) if ($run && $runhost);
		&maka_fasta(new_db => $newdb, append => $includecontam, autoindex => $autoindex, copyhosts => $copyhosts, silent => $silent);

		# 2) Clone directory
		if ($clonedir) {
			my $clonedir_fullname = $truncated . "_" . $clonedir;
			my $includemsg = " (including .OUT files)" if ($includeouts);
			print "<p><img src=\"$webimagedir/circle_2.gif\"> Cloning directory <a href=\"$webseqdir/$clonedir_fullname\">$clonedir_fullname</a>$includemsg...";
			$newdir = &do_clone(newdirtag => $clonedir, copy_outfiles => $includeouts, operator => $op,
							    comments => $comments, silent_success => ($run), copy_all => $alldtas);
		}

		# 3) Run Sequest
		if ($run) {
			my $runhost_display = ($runhost) ? $runhost : "<font color=\"$SERVER_COLOR\"><b>$MAIN_SERVER</b></font>";
			print "<p><img src=\"$webimagedir/circle_3.gif\"> Initializing run on $runhost_display...";
			&smack_momma (db => $newdb, dir => $newdir, operator => $operator, host => $runhost);
		}

	} elsif ($action eq 'copy') {
		# copy selected files into a reference directory
		my ($refdir, $alldtas, $includeouts) = ($FORM{'refdir'}, $FORM{'alldtas'}, $FORM{'includeouts'});

		@files = keys %selected;
		unshift @list, ".DTAs" if ($alldtas);
		unshift @list, ".OUTs" if ($includeouts);
		unshift @list, ".FUZ.HTMLs";
		my $exts = "DTA-sets";
		$exts .= " (except .OUTs)" unless ($includeouts);
		print "<P><HR><P>Copying selected $exts to $refdir...\n";
		print (((@files) == 0) ? "<p><font color=red>$ICONS{'error'}No files to copy</font>" : '<p>');

		print '<ul>';
		foreach $file (@files) {
			copyfiles("$file.dta", "$seqdir/$refdir") if $alldtas;
			copyfiles("$file.out", "$seqdir/$refdir") if $includeouts;
			copyfiles("$file.fuz.html", "$seqdir/$refdir");
			&add_to_lcq_profile("$file.dta", "$seqdir/$refdir");	# added 10/19/01 REP

			print "<li><p><tt>$file</tt> DTA-set copied.<br>\n";
		}
		print '</ul>';
		
		@text = ("Go back to Sequest Summary", "Go to destination Sequest Summary");
		@links = ($createsummary . "?directory=$FORM{'directory'}&sort=consensus", $createsummary . "?directory=$refdir&sort=consensus");
		&WhatDoYouWantToDoNow(\@text, \@links);

		print "</body></html>";
		exit 0;		

	} elsif ($action eq 'clone') {
		my ($clonedir, $includeouts, $op, $comments, $alldtas) = 
		   ($FORM{'clonedir'}, $FORM{'includeouts'}, $FORM{'op'}, $FORM{'comments'}, $FORM{'alldtas'});

		my $clonedir_fullname = $truncated . "_" . $clonedir;
		my $includemsg = " (including .OUT files)" if ($includeouts);
		print "<p>$ICONS{'info'} Cloning directory <a href=\"$webseqdir/$clonedir_fullname\">$clonedir_fullname</a>$includemsg...";
		$newdir = &do_clone(newdirtag => $clonedir, copy_outfiles => $includeouts, operator => $op,
							comments => $comments, silent_success => 0, copy_all => $alldtas);
	} elsif ($action eq 'delete') {
		&do_delete ($FORM{'alldtas'}, $FORM{'includeouts'}, $FORM{'op'}, $FORM{'all'});
	} else {
		return;
	}

	exit;
}


sub do_delete {
  my ($delete_dtas, $delete_outs, $operator) = @_;
  my $num, $outnum;
  $|=1;
  @notdeleted = ();
  @deleted = ();

  $stuff = 'DTAs' if ($delete_dtas && !$delete_outs);
  $stuff = 'OUTs' if (!$delete_dtas && $delete_outs);
  $stuff = 'DTAs & OUTs' if ($delete_dtas && $delete_outs);
  
  print "<hr><p>Deleting $stuff from <a href=\"$webseqdir/$directory\">$directory</a>...";

  foreach $file (keys %selected) {
    if ($delete_dtas) {
		if (&delete_files("$file.dta")) {
			push(@deleted,"$file.dta");
			$num++;
		} else {
			push(@notdeleted,"$file.dta: " . Win32::FormatMessage(Win32::GetLastError()));
		}
    }	# &delete_files automatically deletes OUTs along with DTAs, so no need to delete outs now if we've aleady deleted DTAs
    elsif ($delete_outs) {
		if (&delete_files("$file.out")) {
			push(@deleted,"$file.out");
			delete $selected{"$file"};		# deselect file
			$num++;
		} else {
			push(@notdeleted,"$file.out: " . Win32::FormatMessage(Win32::GetLastError()));
		}
	}
  }
  &update_selected_dtas($directory);

  if (@notdeleted) {
    print "<p>$ICONS{'error'}<font color=red>The following files could not be deleted:</font><ul><li><p>\n";
    print join("\n<li><p>",@notdeleted);
    print "</ul>";
  } else {
	if ($delete_dtas) {
		$file = 'DTA-set' . (($num != 1) ? 's' : '');
	} else {
		$file = 'OUT file' . (($num != 1) ? 's' : '');
	}
    print <<EOM;
<p>$ICONS{'info'}$num $file deleted.
EOM
  }

@text = ("Go back to Sequest Summary", "Run Sequest", "Home");
@links = ($createsummary . "?directory=$FORM{'directory'}&sort=consensus", "$seqlaunch?directory=$FORM{'directory'}", $HOMEPAGE);
&WhatDoYouWantToDoNow(\@text, \@links);


  # logging feature added by cmw, 8-3-98
  $num_selected = (keys %selected);
  $num_dtas_deleted = ($delete_dtas) ? $num_selected : 0;
  $num_outs_deleted = ($delete_outs) ? $num_selected : 0;
  $logentry = "Runsummary deleted $num_outs_deleted OUT files and $num_dtas_deleted DTAs  " . localtime() . "  $operator";
  &write_deletionlog($directory,$logentry,\@deleted);

  exit;

}

## arguments, passed as an assoc array
## newdirtag => the suffix for the new directory
## operator => the name of the operator making this clone
## comments => comments provided by the operator
##
##    optional:
## copy_outfiles => true if we should copy over outfiles as well
## silent_success => true if we should not produce output
## copy_all => true if we should copy all files, not just the selected ones

sub do_clone {
  my (%args) = @_;

  require "clone_code.pl";

  my (@dtafiles);
  if ($args{"copy_all"}) {
    @dtafiles = map { $_ . ".dta" } @outs;
  } else {
    @dtafiles = map { $_ . ".dta" } ( split (", ", $FORM{"selected"}) );
  }

  ($newdir, @retval) = &clonedir ($directory, $args{"newdirtag"}, \@dtafiles, $args{"copy_outfiles"}, 
					$args{"operator"}, $args{"comments"});

  if ((shift @retval) != 0) { # error
    &clone_error (@retval);
  }

  # print success message
  print '<font color="#008000"><b>done.</b></font>';

  # sometimes we don't want output yet:
  return ($newdir) if $args{"silent_success"};

@text = ("Run Sequest", "View Sequest Summary", "All Charged Up", "Oops!  Delete $newdir directory");
@links = ("$seqlaunch?directory=$newdir", $createsummary . "?directory=$newdir&sort=consensus", "$webcgi/all_charged_up.pl?directory=$newdir&viewonly=true", "$trimmer?directory=$newdir");
&WhatDoYouWantToDoNow(\@text, \@links);

  return ($newdir);
}


sub clone_error {
  my @retval = @_;
  my $msg = shift @retval;

  print <<EOM;
<p><font color=red>$ICONS{'error'}Cannot create new directory:  $msg</font>
EOM
  print join ("\n", @retval);
  &closeidx();

@text = ("Go back to Sequest Summary", "Delete $newdir directory");
@links = ($createsummary . "?directory=$FORM{'directory'}&sort=consensus", "$trimmer?directory=$newdir");
&WhatDoYouWantToDoNow(\@text, \@links);

  exit;
}

sub do_graph {
  my ($pngfile) = @_;

  # Lincoln Stein's great Perl port
  # 	http://www-genome.wi.mit.edu/ftp/pub/software/WWW/GD.html
  # of Thomas Boutell's wonderful gd (gifdraw) C library
  #	http://www.boutell.com/gd/ 

  use GD;

  my ($firsttick, $tickinterval, $x, $i, $f, $l, $label, $bare, $rank, $fancyname, $str);
  my $qtof_exists = ( -f "$seqdir/$directory/qtof_convert.txt");

  local ($upperbound, $lowerbound, $scanlen, $maxsum, @files);

  foreach $file (@outs) {
    next unless ($file =~ m!(\d+)\.(\d+)\.\d$!);

	if ($qtof_exists) {
		$upperbound = &max ($1, $upperbound);
	    $lastscan{$file} = $1;
	} else {
		$upperbound = &max ($2, $upperbound);
	    $lastscan{$file} = $2;
	}
    
	$lowerbound = ($lowerbound ? &min ($1, $lowerbound) : $1);
    $firstscan{$file} = $1;
	push (@files, $file);
  }

  @files = sort { ($firstscan{$a} + $lastscan{$a}) <=>
		       ($firstscan{$b} + $lastscan{$b}) } @files;

  $lowerbound -= 5;
  $lowerbound = 0 if ($lowerbound < 0);
  $upperbound += 5;
  
  $scanlen = $upperbound - $lowerbound;
  if ($scanlen <= 0) {
    print ("<h2>No data files to graph.</h2>");
    return;
  }
 
  $maxsum = $Max_BP || 1;

  local $HBUFFER = 30;
  local $VBUFFER = 40;

  local $HAVAIL = $HSIZE - (2 * $HBUFFER);
  local $VAVAIL = $VSIZE - (2 * $VBUFFER);

  local $font = gdMediumBoldFont;
  my $tickfont = gdSmallFont;
  local $labelfont = gdSmallFont;

  my $TICKLENGTH = 5;

  local $im = new GD::Image($HSIZE, $VSIZE);
  $im->interlaced("true");

  local ($white, $black, $red, $gray, $blue, $brown, $lightgray);
  local (@graph_colours);

  # background colour: white
  $white = $im->colorAllocate (255, 255, 255);

  # for use in labeling the ranks of the peaks in the graph subroutine
  for ($i = 0; $i < $num_ranks_to_colour; $i++) {
	@array = &parse_colstr ($rank_colour[$i]);
     $graph_colours[$i] = $im->colorAllocate( @array );
  }


#  $lightblue = $im->colorAllocate (70, 50, 255);
  $black = $im->colorAllocate (0,0,0);
  $red = $im->colorAllocate (255, 0, 0);
  $gray = $im->colorAllocate (80, 80, 80);
  $lightgray = $im->colorAllocate (200, 200, 200);
#  $orange = $im->colorAllocate (255, 127, 0);
  $blue = $im->colorAllocate (0, 0, 255);
#  $darkgreen = $im->colorAllocate (0, 128, 0);
#  $darkred = $im->colorAllocate (100, 0, 0);

#  $orangey_yellow = $im->colorAllocate (200, 128, 0);
  $brown = $im->colorAllocate (140, 23, 23);

  # fill with white
  $im->filledRectangle(0,0, $HSIZE, $VSIZE, $white);

  # draw axes:
  $im->line($HBUFFER, $VBUFFER, $HBUFFER, $VSIZE - $VBUFFER, $black);
  $im->line($HBUFFER, $VSIZE - $VBUFFER, $HSIZE - $HBUFFER, $VSIZE - $VBUFFER, $black);

  # draw a line at median BP:
  $y = $VSIZE - $VBUFFER - int (($Median_BP / $maxsum) * $VAVAIL + 0.5);

  $im->setStyle($lightgray, $lightgray, gdTransparent, gdTransparent);
  $im->line($HBUFFER, $y, $HSIZE - $HBUFFER, $y, gdStyled);

  # do tick marks:
  if ($scanlen > 5000) {
    $tickinterval = 500;
  } elsif ($scanlen > 1500) {
    $tickinterval = 250;
  } elsif ($scanlen > 750) {
    $tickinterval = 100;
  } elsif ($scanlen > 300) {
    $tickinterval = 50;
  } elsif ($scanlen > 150) {
    $tickinterval = 25;
  } elsif ($scanlen > 80) {
    $tickinterval = 10;
  } else {
    $tickinterval = 5;
  }

  $firsttick = (int ($lowerbound /$tickinterval) + 1) * $tickinterval;
  for ($i =  $firsttick; $i < $upperbound; $i += $tickinterval) {
    $x = $HBUFFER + int ($HAVAIL * ($i - $lowerbound)/$scanlen + 0.5);
    
    $im->line($x, $VSIZE - $VBUFFER, $x, $VSIZE - $VBUFFER + $TICKLENGTH, $black);
    &x_center_normal ($im, $tickfont, $x, $VSIZE - $VBUFFER + $TICKLENGTH, $i, $black);
  }
  
  
  # label axes:
  &x_center_normal ($im, $font, $HBUFFER, $VSIZE - $VBUFFER + 3 * $TICKLENGTH, $lowerbound, $red);
  &y_center_upright ($im, $font, $HBUFFER - $font->height, $VSIZE - $VBUFFER, "0", $black);
  
  $str = &sci_notation($maxsum);
  $im->stringUp ($font, $HBUFFER - $font->height, $VBUFFER + length ($str) * $font->width, $str, $red);
  &x_center_normal ($im, $font, $HSIZE - $HBUFFER, $VSIZE - $VBUFFER + 3 * $TICKLENGTH, $upperbound, $red);

  # graph and label the peaks:
  foreach $file (@files) {
    $f = $firstscan{$file};
    $l = $lastscan{$file};

    $rank = $ranking[ $number{$file} ];

    if (!defined $rank) {
      $rank = -1;
      $label = $ref{$bare};
    } else {
      $label = $consensus_groupings[$rank];
    }
    &graph ($im, $f, $l, $BP{$file}, $label, $rank);
  }

  #output the image
  open (PNG, ">$tempdir/$pngfile") || die ("Could not write to $tempdir/$pngfile");
  binmode PNG;
  print PNG $im->png;
  close PNG;
}


sub parse_colstr {
  my ($a) = $_[0];
  my (@a, @arr, $temp);

  $a =~ s!^#!!;

  @a = $a =~ m!(..)(..)(..)!;
  foreach $a (@a) {
    push (@arr, hex ($a));
  }
  return @arr;
}

sub x_center_normal {
  # given an x on which to CENTER the given font, using same y
  my ($im, $font, $x, $y, $s, $color) = @_;

  my ($w) = $font->width;

  $im->string($font, $x - $w * length($s)/2 + 1, $y, $s, $color);
}

sub y_center_upright {
  # given an y on which to CENTER the given font, using same x
  my ($im, $font, $x, $y, $s, $color) = @_;

  my($h) = $font->width;
  $im->stringUp($font, $x, $y + $h * length($s)/2, $s, $color);
}

sub graph {
  my ($im, $firstscan, $lastscan, $sum, $label, $rank) = @_;
  my ($midscan, $mid, $H, $B, $delta, $x, $y, $colour);

  if ($rank == -1) {
    $colour = $gray;
  } else {
    $colour = $graph_colours[$rank];
  }

  $firstscan -= $lowerbound;
  $lastscan -= $lowerbound;
  $midscan = ($firstscan + $lastscan) / 2;
  $B = $lastscan - $firstscan;
  $H = $sum/$maxsum;

  $left = $HBUFFER + int ($HAVAIL * $firstscan / $scanlen + 0.5);
  $right = $HBUFFER + int ($HAVAIL * $lastscan / $scanlen + 0.5);

  $mid = $HBUFFER + int ($HAVAIL * $midscan / $scanlen + 0.5);
  $peak = $VSIZE - $VBUFFER - int ($VAVAIL * $H + 0.5);

  # this does triangles:
#	if ($firstscan > 0 && $midscan < $scanlen) {
  $im->line($left, $VSIZE - $VBUFFER, $mid, $peak, $colour);
#	}
#	if ($midscan > 0 && $lastscan < $scanlen) {
  $im->line($mid, $peak, $right, $VSIZE - $VBUFFER, $colour);
#	}

  ##
  ## Here is the logic to direct where to place the labels, based
  ## on peak height
  ##

  if ($H > .75) {
    # if very tall, put the label in the middle of the peak:
    $y =  $VSIZE - $VBUFFER - int (($H /2) * $VAVAIL + 0.5);
  } elsif ($H > .4) {
    # if medium height, put the label in the middle of the space above the peak
    $y = $VSIZE - $VBUFFER - int (((1 + $H) /2) * $VAVAIL + 0.5);
  } else {
    # if short, place the label a fixed distance above the peak
    $y = $peak - $VAVAIL * .5;
  }

#  $y = $peak - int ($VAVAIL / 3.5) - 50;
#  $y = $peak + int ($VAVAIL / 3.5) if ($y < $VAVAIL / 4);

  $x = $mid - ($labelfont->height)/2;

  &y_center_upright ($im, $labelfont, $x, $y, $label, $colour);

  my $font = gdMediumBoldFont;

  if ($rank != -1) {
    my $letter = &get_group_letter($rank);

    # place (20 + 10 * $rank) below the label
    $y += 10 * $rank + 20 + length($label) * $labelfont->width / 2;

    if ($rank != 0) {
      &x_center_normal ($im, $font, $mid, $y,  $letter, $colour);
    } else {
      if (($y + 20 > $peak) && ($peak > 30) ) {
	$y = $peak - 25;
      }
      &x_center_normal ($im, $font, $mid, $y,  $letter, $colour);

      &y_center_upright ($im, $font, $mid - $font->height/2, $y + 16,  "-", $colour);
    }
  }
}

# add_to_lcq_profile
# input 1 is filename in current directory. input 2 is directory name (complete path) for a new directory to which the file's lcq
# entry must be added. This subroutine adds the entry if it doesn't exist already
sub add_to_lcq_profile{
	my($dta,$otherDir) = @_;
	my(@lines,$line);

	open LCQ2, "$otherDir/lcq_profile.txt";
	while (<LCQ2>) {
		if($_ =~ /$dta/){
			#entry already exists
			close LCQ2;
			return;
		}
	}
	close LCQ2;

	open LCQ1, "$seqdir/$dir/lcq_profile.txt";
	while (<LCQ1>) {
		if($_ =~ /$dta/){
			$line = $_;
			last;
		}
	}
	close LCQ1;

	open NEWLCQ, ">>$otherDir/lcq_profile.txt";
	print NEWLCQ "$line";
	close NEWLCQ;
}

##
## this looks in %FORM to find the sort parameter the user selected

sub find_sort_value {
  my (@arr) = grep { /^sort_/ } keys %FORM;
  my ($sort, $temp);

  if ($FORM{"sort"}) {
    $sort = $FORM{"sort"};
  } else {
    foreach $key (@arr) {
      ($temp = $key) =~ s!^sort_!!g;
      $temp =~ s!\..$!!g; # remove .x and .y from image hits

      if ($sort) {
        return undef if ($sort ne $temp);
  	  } else {
        $sort = $temp;
      }
    }
  }

  $sort =~ tr/A-Z/a-z/;
  $sort =~ s/\s//g;
  $sort = $FORM{"prevsort"} unless ($sort); 

  return $sort;
}

##
## return sorted list of the given @outs
##
## we modify $sort, a global variable

sub do_sort_outs {
  my (@files) = @_;
  my (@orderedouts);
  my (@outs, @empties);
  
  foreach $out (@files) {
    if ($empty{$out}) {
      push (@empties, $out);
    } else {
      push (@outs, $out);
    }
  }
  $sort = &find_sort_value();

  if (($sort eq "number") or ($sort eq "#")) {
    @orderedouts = sort { $number{$a} <=> $number{$b} } @files;

  } elsif ($sort eq "scan") {
	# Translate all files into hash with first group of digits being the numeric in the value, then sort on that
	my %tosort = map {$_, ((split '\.')[1])} @files;  # The split takes the second split value, which should be the first scan number
	@orderedouts = sort {$tosort{$a} <=> $tosort{$b}} keys %tosort;

  } elsif ($sort eq "dm") {
    @orderedouts = ((&sort_by_delM (@outs)), @empties);

  } elsif (($sort eq "mh+") or ($sort eq "mhplus")) {
    @orderedouts = &sort_by_mass (@files);

  #} elsif ($sort eq "xc") {
  #  @orderedouts = ((sort by_Xcorr @outs), @empties);

  } elsif ($sort eq "dcn") {
    @orderedouts = ((&sort_by_delCn (@outs)), @empties);

  } elsif ($sort eq "gbu") {
	@orderedouts = ((&sort_by_gbu (@outs)), @empties)

  } elsif ($sort eq "sp") {
    @orderedouts = ((sort by_sp @outs), @empties);

  } elsif ($sort eq "rsp") {
    @orderedouts = ((sort by_rsp @outs), @empties);

  } elsif ($sort eq "sf") {
    @orderedouts = ((sort by_Sf @outs), @empties);

  } elsif ($sort eq "p") {
	@orderedouts = ((sort by_prob @outs), @empties);

  } elsif ($sort eq "ckbox") {
	@orderedouts = ((sort by_ckbox @outs), @empties);

  } elsif ($sort eq "ions") {
    @orderedouts = ((&sort_by_ions (@outs)), @empties);

  } elsif ($sort eq "ref") {
    @orderedouts = ((sort by_ref @outs), @empties);

  } elsif ($sort eq "sequence") {
    @orderedouts = ((&sort_by_seq (@outs)), @empties);

  } elsif ($sort eq "zbp") {
	if ($zBP_available) {
		$BP_mode = "zBP";
		%BP = %zBP;
	}
    @orderedouts = sort by_BP (@outs, @empties);

  } elsif ($sort eq "fbp") {
    if ($fBP_available) {
		$BP_mode = "fBP";
		%BP = %fBP;
	}
    @orderedouts = sort by_BP (@outs, @empties);

  } elsif ($sort eq "tic") {
	if ($TIC_available) {
		$BP_mode = "TIC";
		%BP = %TIC;
	}
    @orderedouts = sort by_BP (@outs, @empties);

  } elsif ($sort eq "maxbp") {	# added 7/31/00 by Mike; is the case here a bug?!
    if ($maxBP_available) {
		$BP_mode = "maxBP";
		%BP = %maxBP;
	}
	@orderedouts = sort by_BP (@outs, @empties);

  } elsif (($sort eq "parens") or ($sort eq "()")) {
    @orderedouts = ((sort by_prev_aa @outs), @empties);

  } elsif ($sort eq "z") {
    @orderedouts = sort by_charge (@outs, @empties);
  
  } elsif ($sort eq "consensus") {
    @orderedouts = ((&sort_by_rank (@outs)), @empties);
    $is_cons_sort = 1;

  # by default, sort by deltaCn
  #} else {
  #  @orderedouts = ((&sort_by_delCn (@outs)), @empties);
  #  $sort = "dcn";
  #}
  } else {
	@orderedouts = sort by_Xcorr (@outs, @empties);
	$sort = "xc";
  }

  return (@orderedouts);
}

sub output_image {
  $ourshortname =~ s!\.pl!!;
  my ($pngfile) = "$ourshortname". "_$$.png";
  &make_space (10);
  
  $table_breaks = "";
  &print_simple_info ("Extd Sample", "Db", "Files");

  print ("<BR CLEAR=ALL>\n");

  ##
  ## width and height of images
  ##
  $HSIZE = 725;
  $VSIZE = 500;

  &do_graph($pngfile);
  print qq(<IMG SRC="$webtempdir/$pngfile" WIDTH="$HSIZE" HEIGHT="$VSIZE" ALT="Loading image..."><p>\n);

  foreach $ref (@consensus_groupings) {
	&print_one_consensus ("ref" => $ref, with_others => 1);
    print ("<br>\n");
  }
}

sub make_space {
  print qq(<IMG SRC="$transparent_pixel" HEIGHT=$_[0] WIDTH=1 ALIGN=LEFT><BR CLEAR=ALL>\n);
}

sub chdir_error {
  my $dir = $_[0];

  print <<EOM;
<h3>Error: Unable to access $dir</h3>
Please be sure the directory actually exists and access
permissions are sufficient.
EOM
  &closeidx();
  exit;
}


## this subroutine takes the selected files and creates a Folgesuchebericht (report):
##
## all color removed by cmw (7/26/99)
sub print_bericht {

	my(%dir_info) = &get_dir_attribs($directory);
	my $db = $database[0];
	my $temp = "";
	my $check = "\Q$db\E";

	$now = &get_yyyymmdd_hhmmss();

	# wsl added the next two lines and added variables to Bericht filename
	$smpid = $dir_info{"SampleID"};
	$smp = $dir_info{"Sample"};

	## bericht is copied to temp dir, only saved for real from logrun.pl
	## (dmitry 3/12/99)
	$berichtfilename = "Bericht\_$smpid\_$directory\_$now.html";
		open(BERICHTFILE,">$berichtfilename");		# (i think this is obsolete; Bericht feature is Harvard-only anyway? -cmw, 1/17/00)
	select(BERICHTFILE);


	# this block added by cmw, 1/16/00 (recycled from the "save checkbox state" section at the beginning)
	# save checkbox state in a timestamped file every time Bericht is done
	$checkbox_state_file = "checkbox_state_$berichtfilename";
	&save_checkbox_state("$tempdir/$checkbox_state_file");

	print <<EOF;
<html>
<head>
<base href="$server">
<title>Summary Report</title>
$stylesheet_html

</head>
<BODY BGCOLOR="#FFFFFF">
EOF

  foreach $val (@database) {
    next if ($val =~ m!^($check)$!);
    $temp .= " $val";
    $check .= "|\Q$val\E";
  }

  my $mtime = (stat("$dbdir/$db"))[9];
  ($t, $t, $t, $day, $month, $year) = localtime($mtime);

  # remove ".fasta" from the name:
  $db =~ s!\.FASTA!!i;

  $year %= 100;
  $month++; # it comes in the range 0-11

  $day = &precision ($day, 0, 2);
  $month = &precision ($month, 0, 2);
  $year = &precision ($year, 0, 2);

  $dbdate = "$month/$day/$year";

  $db .= " ($dbdate)";
#  $db = "<span style=\"color:blue\">$db</span>";

  # strip _suffix from run name for folge title
  $stripped_samp = $dir_info{"Sample"};
  $stripped_samp =~ s/_.*//g;
  
  print <<EOF;
<table width=100% cellspacing=0 cellpadding=0><tr>
<td width=20% nowrap valign=top>
<span class="smallheading">Sample:</span> <tt>$stripped_samp</tt><br>
<span class="smallheading">Sample ID:</span> <tt>$dir_info{"SampleID"}</tt>
</td>
<td width=60% align=center valign=top nowrap>
<span class="smallheading">User:</span> <tt>$dir_info{"LastName"}, $dir_info{"Initial"}.</tt>
</td>
<td width=20% align=right nowrap valign=top>
<span class="smallheading">Db:</span> <tt>$db</tt><br>
<span class="smallheading">Dir:</span> <tt>$dir_info{"Sample"}</tt><br>
</td>
</tr></table>
EOF
  ### end of header

	print "<hr>\n";
	print "<br>\n";

	$FORM{"sort"} = "consensus";
	@orderedouts = &do_sort_outs (keys %selected);

	if (!&openidx("$dbdir/$database[0]")) {
		$dbavail=0;
	} else {
		$dbavail=1;
	}

#	## XML CODE: (now in a different function)
#	my %report_data = (	sample		=> {name => $stripped_samp, id => $dir_info{SampleID}},
#						user		=> "$dir_info{LastName}, $dir_info{Initial}.",
#						db			=> $db,
#						sampledir	=> $dir_info{Sample},
#						directory	=> $directory,
#						files		=> "$file_string ($date_string)",
#						maxrank		=> $MAX_RANK,
#						enzyme		=> $enzyme,
#						operator	=> $dir_info{"Operator"},
#						bpmode		=> $BP_mode,
#	);
#	my $xml = &create_xml_report(\%report_data, &consensus_data());
#
#
#	$reportfilename = "report\_$smpid\_$directory\_$now.xml";
#	open(RFILE,">e:/documents/matthew/xmlreports/$reportfilename");
#	print RFILE $xml;
#	close(RFILE);
#
#	# cut out early for testing xml:
#	&no_content();
#	return;

	&print_bericht_list();

	print "<p><span class=\"smallheading\">Comments:</span> <span class=\"reflinefont\">$comments</span><p>" if ($comments);

	if (@orderedouts) {
		print <<EOF;

<p><span class="smallheading">Legend:</span><br>
<table width=100% cellspacing=0 cellpadding=0><tr>
<td width=1></td>
<td width=98%>
<span class="smallheading">Sequence:</span> <span class="reflinefont">The isobaric residue pairs Leu/IIe, Gln/Lys and Phe/Msx are displayed
with the assignment as in the known sequence.  Either residue within the pair may be possible: the displayed assignment
does not connote a defined assignment to one or the other.  The amino acid N-terminal to the known sequence is displayed
in parentheses ().</span><br>

<span class="smallheading">Ions:</span> <span class="reflinefont">The number of fragment ions (b-, y- and/or a-ions) experimentally
observed / number of fragment ions possible.  This fraction is a crude estimate of the minimum percentage of
the sequence represented by the spectrum.</span><br>

<span class="smallheading">Reference:</span> <span class="reflinefont">The database reference which contains the displayed sequence.
A reference followed by a plus sign and number (e.g. +2) indicates the displayed sequence is also present
in that number of additional database references</span><br>

EOF

  if ($BP_mode eq "zBP") {
	print <<EOF;
<span class="smallheading">zBP:</span> <span class="reflinefont">The intensity (zoom scan base peak) of the ion fragmented to
produce the MS/MS spectrum.  This is a unitless number.  Note: mass spectrometry of different peptide analytes is
not quantitative.  This value should not be used to ascertain a major versus a minor component.</span><br>
EOF
  } elsif ($BP_mode eq "fBP") {
	print <<EOF;
<span class="smallheading">fBP:</span> <span class="reflinefont">The intensity (full scan base peak) of the ion fragmented to
produce the MS/MS spectrum. This is a unitless number. Note: mass
spectrometry of different peptide analytes is not quantitative. This value
should not be used to ascertain a major versus a minor component.</span><br>
EOF
  } elsif ($BP_mode eq "TIC") {
	print <<EOF;
<span class="smallheading">TIC:</span> <span class="reflinefont">The intensity (total ion current) of the the MS/MS spectrum. This is a
unitless number. Note: mass spectrometry of different peptide analytes is
not quantitative. This value should not be used to ascertain a major versus
a minor component.</span><br>
EOF
  } elsif ($BP_mode eq "maxBP") {
	print <<EOF;
<span class="smallheading">maxBP:</span> <span class="reflinefont">
The intensity of the highest peak at the given m/z ratio among several scans.
</span><br>
EOF
  }

  print <<EOF;
<span class="smallheading">Scans:</span> <span class="reflinefont">The scan number(s) of the acquired MS/MS spectrum.</span><br>

<span class="smallheading">Modifications:</span> <span class="reflinefont">
EOF

  my ($mods, $lastmods);
  foreach $file (@orderedouts) {
    $mods = $mods[ $number{$file} ];
    if ((defined $lastmods) && $mods ne $lastmods) {
      $mods = -1;
      last;
    }
    $lastmods = $mods;
  }

  if ($mods == -1) {
#    print ("Varying mods in this set of files.<br>\n");
  } else {

	$mods =~ s!Enzyme.*!!;
	my @mods = ("\\\*", "\\\#", "\\\@", "\\\^", "\\\+", "\\\$");
	my $modtxt;	
	
	foreach $mod (@mods) {
		# If we have a number for this mod...
		if ($mods =~ s!\(.*?$mod ([\+\-]?\d+\.?\d*)\)!!) {
			my $modnum = $1;
			# ...get rid of any 0s after the tens place...
			$modnum =~ s|(\.\d[^0]*)0{1,}|$1|;
			# ...and then add it to $modtxt.
			if ($modtxt) { $modtxt .= ", "; }
		    $modtxt .= (substr($mod, -1) . " = $modnum");
		}
	}

	if ($modtxt) {
		$modtxt =~ s!,([^,]*)$!, and/or$1!;
		print "$modtxt modification of preceding amino acid. ";
	}

    if ($mods =~ m!\S!) { # any non-whitespace chars? Then print out the info
      print ("$mods<br>\n"); 
    }
  }

  print "</span></td><td></td></tr></table><p>\n";
  
  } else {

	print "&nbsp;<p><center><tt>No sequences from the __________ database correlated with this data.</tt></center><p>&nbsp;<p>\n";

  }


    ## check for multiple filename prefixes
    ## (this indicates the user combined more than one 
    ## run in the same directory)

    ($file_string) = $outs[0] =~ m!^([^\.]*)!;
    $temp = "";
    $check = "\Q$file_string\E";

    foreach $file (@outs) {
      next if ($file =~ m!^($check)\.!); # quote to protect it
      $file =~ m!^([^\.]*)!;
      $temp .= " $1";
      $check .= "|\Q$1\E";
    }

    $file_string .= $temp if ($temp);

    ## check all enzymes
    ($enzyme) = $mods[0] =~ m!Enzyme:\s*(\S+)!;
  
    $check = "\Q$enzyme\E";
    my $no_enz = 0;

    if ($enzyme eq "") {
      $enzyme = "None";
      $check = "";
      $no_enz = 1;
    }
    $temp = "";

    foreach $mod (@mods) {
      next if ($mod =~ m!Enzyme:\s*($check)\W!); # match end of word
      if ($mod =~ m!Enzyme:\s*(\S+)!) {
        $temp .= " $1";
        $check .= "|\Q$1\E";
      } else {
        next if $no_enz;

        $no_enz = 1;
        $temp .= " None";
      }
    }
    $enzyme .= " and" . $temp if ($temp);

	#Pull to Top button indicator
	my $ptt = ($pull_to_top)?'+':'-';

	print <<EOF;
		<table width=100% cellspacing=0 cellpadding=0 border=0>
		<tr valign=top>
			<td width=25% nowrap valign=top>
				<span class="smallheading">Dir:</span> <tt>$directory</tt>
			</td>
			<td width=60%>
				<!--<span class="smallheading">Files:</span> <tt><span style="color:#0080C0">$file_string ($date_string)</span></tt>-->
				<span class="smallheading">Files:</span> <tt>$file_string ($date_string)</tt>
			</td>
			<td align=right width=15%>
				<tt><span class="smallheading">MR:&nbsp;</span>$MAX_RANK&nbsp;<span class="smallheading">PTT:&nbsp;</span>$ptt</tt>
			</td>
		</tr>
		<tr valign=top>
			<td width=25%>
				<!--<span class="smallheading">Enz:</span> <tt><span style="color:#8000FF">$enzyme</span></tt>-->
				<span class="smallheading">Enz:</span> <tt>$enzyme</tt>
			</td>
			<td width=60%>
				<table cellspacing=0 cellpadding=0 border=0 bordercolor=red width=100%>
				<tr valign=top>
					<td width=50%>
						<span class="smallheading">Oper:</span> <tt>$dir_info{"Operator"}</tt>
					</td>
					<td width=50%>
EOF

			  #changed by Georgi 06/19/2000; previous version had the following statement uncommented
			  #print ("&nbsp;" x 29);

	  print <<EOF;
						<span class="smallheading">Report:</span> <tt><!--BEGIN_OPER-->$operator<!--END_OPER--></tt>
					</td>
				</tr>
				</table>
			</td>
			<td align=right width=15%>
EOF

	  # find sum of all duplicated sequences in Bericht output
	%already_found_one = ();
	$D = 0;
	foreach $seq (@all_bericht_seqs)
	{
		$seq =~ s/[#\*]//g;
		$D++ if ($already_found_one{$seq});
		$already_found_one{$seq} = 1;
	}

	#Pull to Top button indicator
	my $ptt = ($pull_to_top)?'+':'-';
	print <<EOF;
				<span class="smalltext">R$R/D$D<!--BEGIN_CHARGE--><!--END_CHARGE--></span>
			</td>
		</tr>
		</table>
		<br clear=all>
		<center><span class="times"><span class="smalltext"><i>William S. Lane
		&nbsp;&nbsp;&nbsp;Harvard Microchemistry Facility
		&nbsp;&nbsp;&nbsp;16 Divinity Av&nbsp;&nbsp;&nbsp;Cambridge MA 02138
		&nbsp;&nbsp;&nbsp;(617) 495-4043&nbsp;&nbsp;&nbsp;fax (617) 495-1374</span></span></center>
EOF
  ### end of footer

	close BERICHTFILE;
	select(STDOUT);

	## note: the duplicates of Berichts to Access directory which used to be made from here
	## are now made from logrun.pl
		#	# now let's try to keep a duplicate report in a local dir for Access to retrieve
		#	$accessname = "$berichtdir/$smpid\_$directory\_$now.html";
		#	copy($berichtfilename,$accessname);
		&redirect("$webseqdir/$directory/$berichtfilename");

}




sub stupid_table_header {
  print ("<tt><u>");
  my $s = "&nbsp;";
  print ($s, "#", $s x 3, "BP", $s x 2, "File");
  print ($s x 6, "z", $s x 2, "dM", $s x 3, "MH+");
  print ($s x 3, "Xcorr", $s x 1, "dCn", $s x 2, "Sp");
  print ($s x 3, "RSp", $s x 1, "Ions", $s x 3, "Reference", $s x ($reflen - 7), "( )Sequence");
  print ("</u></tt><br>\n");
}


sub stupid_bericht_table_header {
  print ("<tt>");
  my $s = "&nbsp;";
  print ($s x 6, "Sequence", $s x 24, "Reference", $s x 13, "$BP_mode", $s x 6, "Ions", $s x 3, "Scans", $s x 3);
  print ("</tt><br>\n");
}



## this subroutine prints out the sample name of this directory
## first arg: the directory name
## (optional) second arg: the total length output wanted. We will
##                        output the appropriate number of padding spaces.

sub print_sample_name {
  my ($directory, $padding) = @_;
  
  my (%dir_info) = &get_dir_attribs ($directory);
  $dir_info{"Fancyname"} = &get_fancyname($directory,%dir_info);

  print qq(<span class="smallheading">Sample:&nbsp;&nbsp;</span>\n);
  print $table_breaks if ($table_breaks);

  # join together the fancyname, sample ID, and operator name:
  $output = join (" ", map { $dir_info{$_} } ("Fancyname", "SampleID", "Operator") );
  ($dir_info{'Fancyname'}) =~ m/(.*) \((.*)\)/;
  $matched_name = $1;
  $matched_ID = "($2)" if ($2);

  $actualoutput = $output;


  print qq(<span class="smalltext">$actualoutput);

  if ($padding) {
    print ("&nbsp;" x ($padding - length ($output)));
  }
  print ("</span>\n");
}

sub open_main_form {
  print <<EOM;
<FORM name="mainform" METHOD=post ACTION="$ourname">
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$directory">
<INPUT TYPE=HIDDEN NAME="notnew" VALUE="notnew">
<INPUT TYPE=HIDDEN NAME="prevsort" VALUE="$sort">
<INPUT TYPE=HIDDEN NAME="boxtype" VALUE="$boxtype">
<INPUT TYPE=hidden name="score_threshold" value="$score_threshold">
<input type=hidden name="sequences_threshold" value="$NUMFILES_GREATER_THAN">
<INPUT TYPE=HIDDEN NAME="load_dta_vcr" VALUE="$load_dta_vcr">
<INPUT TYPE=HIDDEN name="wait_for_sf" value="">		<!-- 11/13/01 -->
<input type=hidden name="consensus_view_mode" value="$consensus_view_mode">
<input type=hidden name="consensus_filter_mode" value="$consensus_filter_mode">
EOM
}


## this acts like &print_data(), but it always acts in a consensus-like
## mode and prints only peptides and shortened headers.

sub print_bericht_list {
  my ($rank, $lastrank, $ref, $i, $num);
  my ($noconsensus, $pep);
  my $s = "&nbsp;";

  ## find out how many files are in each consensus:
  my (@BPsum, @num_files_in_rank);

  $R = $D = $num_files_noconsensus = $BPsum_noconsensus = 0;
  @all_bericht_seqs = ();

  $lastrank = -2;
  foreach $file (@orderedouts) {
    $i = $number{$file};
    $rank = $ranking[$i];
    $rank = -1 if (!defined $rank);

    if ($rank != $lastrank) {
      $num_files_in_rank[$lastrank] = $n unless ($lastrank < 0);
      $n = 0;
    }


	($file_trunc = $file) =~ s/..$//;
	unless ($summed{$file_trunc}) {
		$BPsum[$rank] += $BP{$file} unless ($rank < 0);
		$BPsum_noconsensus += $BP{$file} if ($rank == -1);
	}
	# prevent same scan (with different charges) from being counted more than once
	$summed{$file_trunc} = 1;

    $num_files_noconsensus += 1 if ($rank == -1);

    $lastrank = $rank;
    $n++;
  }
  $num_files_in_rank[$lastrank] = $n unless ($lastrank < 0);


  $lastrank = -2; # we need a start sentinel value that is NOT -1!
  $noconsensus = 0;

  foreach $file (@orderedouts) {
    $i = $number{$file};
    # if this is high ranking, make it bold and colourful
    $rank = $ranking[$i];
    $rank = -1 if (!defined $rank);

    ## if this is a consensus grouping, and we have moved on to
    ## the next group, make some space and print a header:
    if ($rank != $lastrank) {
      # if not the first group, make some space:
      if ($lastrank != -2) {
        #&make_space (10);
	    print " <br>\n";
      }

	  $Tot = "zTot" if ($BP_mode eq "zBP");
	  $Tot = "fTot" if ($BP_mode eq "fBP");
	  $Tot = "tTot" if ($BP_mode eq "TIC");
	  $Tot = "mTot" if ($BP_mode eq "maxBP");

      if ($rank != -1) {
		 $ref = $consensus_groupings[ $rank ];

         my ($countstr) =  " " . &get_group_letter($rank);
         my ($col_rank) = $rank;
         if (($col_rank != -1) && ($col_rank <= $num_ranks_to_colour)) {
           my $colour = $rank_colour[ $col_rank ];

#           $countstr = qq(<span style="color:$colour">$countstr</span>);
         }

	     print "<table width=100% cellspacing=0 cellpadding=0><tr><td>";
	     print ("<tt><U>$countstr $ref</U></tt>");
	     print "</td><td align=right><tt>";
         print (&precision ($num_files_in_rank[$rank], 0, 3, $s), " MS/MS spectra");
	     $R += $num_files_in_rank[$rank];		# add totals for bottom of the page
         print ($s x 3, "$Tot: ", &sci_notation ($BPsum[$rank]));
	     
		 print "</tt></td></tr></table>\n";

         print ("</tt>");
		 ##########
		 #old: print &printdescrip($ref);
		 #now, save to variable $pdesc :
		 my $pdesc = &printdescrip($ref);
		 #create new font tags to use, here and below in no group case:
		 $brfontheader = "<span class=\"reflinefont\">";
		 $brfontender = "</span>\n";
		 #remove span/div tags from $pdesc, replace with span tag to be used in bericht report:
		 $pdesc =~ s/$pdfontheader/$brfontheader/ie;
		 #same with close tag
		 $pdesc =~ s/$pdfontender/$brfontender/ie;
		 
		 #finally, print this modified variable:
		 print $pdesc;
		 ##########


      } else {
         print "<table width=100% cellspacing=0 cellpadding=0><tr><td>";
 	     print ("<tt><U> Single Sequences (No Groups)</U></tt>");
	     print "</td><td align=right><tt>";
         print (&precision ($num_files_noconsensus, 0, 3, $s), " MS/MS spectra");
	     $R += $num_files_noconsensus;
         print ($s x 3, "$Tot: ", &sci_notation ($BPsum_noconsensus));
	     print "</tt></td></tr></table>\n";
         $noconsensus=1;
      }
      &stupid_bericht_table_header();
    }

    ## if this is a consensus sort, and we are not in the no
    ## consensus zone, have the 
    ## peptide and reference printed agree with this reference.
    ## otherwise, just print the top reference.
    if ($rank != -1) {
      $num = $level_in_file{"$i:$ref"};

    ## for ungrouped OUTs or in non-consensus mode, we just use the top line of the .out file:
    } else {
      $num = 1;
    }

	# force buttons off:
	$boxtype = "HIDDEN";

	# just do a regular line, hold the hyperlinks
	my @args;
	if ($pull_to_top) {
		@args = ("index" => "$i:$num", "rank" => $rank);
		push (@args, "preferred_ref" => $ref) unless ($rank == -1);
	} else {
		@args = ("index" => "$i:1", "rank" => $rank);
	}

#	print &printdescrip($consensus_groupings[ $rank ]);

	&print_one_dataline_bericht (@args);
    unless ($empty{$file} || !$noconsensus) {
      #$descrip_to_print = &printdescrip($ref{"$i:1"});
	  my $pdescnogroup = &printdescrip($ref{"$i:1"});
	  $pdescnogroup =~ s/$pdfontheader/$brfontheader/ie;
	  $pdescnogroup =~ s/$pdfontender/$brfontender/ie;

	  print $pdescnogroup;

      #print $descrip_to_print;
	  print "<BR>";
    }

    $lastrank = $rank;
  }
}

sub print_xml {
	my(%dir_info) = &get_dir_attribs($directory);
	my $db = $database[0];
	my $temp = "";
	my $check = "\Q$db\E";
	my $now = &get_yyyymmdd_hhmmss();
	my $smpid = $dir_info{"SampleID"};
	my $smp = $dir_info{"Sample"};

	my $filename = "report_$smpid\_$directory\_$now.xml";

	my $checkbox_state_file = "checkbox_state_$filename";
	&save_checkbox_state("$tempdir/$checkbox_state_file");

	foreach $val (@database) {
		next if ($val =~ m!^($check)$!);
		$temp .= " $val";
		$check .= "|\Q$val\E";
	}
	my $mtime = (stat("$dbdir/$db"))[9];
	my ($t, $t, $t, $day, $month, $year) = localtime($mtime);

	$db =~ s!\.FASTA!!i;
	$year %= 100;
	$month++;			# it comes in the range 0-11
	$day = &precision ($day, 0, 2);
	$month = &precision ($month, 0, 2);
	$year = &precision ($year, 0, 2);
	$dbdate = "$month/$day/$year";
	$db .= " ($dbdate)";

	$stripped_samp = $dir_info{"Sample"};
	$stripped_samp =~ s/_.*//g;

	$FORM{"sort"} = "consensus";
	@orderedouts = &do_sort_outs (keys %selected);
	my $dbavail = &openidx("$dbdir/$database[0]") ? 1 : 0;

    ($file_string) = $outs[0] =~ m!^([^\.]*)!;
    $temp = "";
    $check = "\Q$file_string\E";

    foreach $file (@outs) {
      next if ($file =~ m!^($check)\.!); # quote to protect it
      $file =~ m!^([^\.]*)!;
      $temp .= " $1";
      $check .= "|\Q$1\E";
    }

    $file_string .= $temp if ($temp);
	my ($mods, $lastmods, $modstring);
	foreach $file (@orderedouts) {
		$mods = $mods[ $number{$file} ];
		if ((defined $lastmods) && $mods ne $lastmods) {
			$mods = -1;
			last;
		}
		$lastmods = $mods;
	}

	if ($mods != -1) {
		$mods =~ s!Enzyme.*!!;
		my $modtxt;
		my @mods = ("\\\*", "\\\#", "\\\@", "\\\^", "\\\+", "\\\$");
		foreach $mod (@mods) {
			# If we have a number for this mod...
			if ($mods =~ s!\(.*?$mod ([\+\-]?\d+\.?\d*)\)!!) {
				my $modnum = $1;
				# ...get rid of any 0s after the tens place...
				$modnum =~ s|(\.\d[^0]*)0{1,}|$1|;
				# ...and then add it to $modtxt.
				if ($modtxt) { $modtxt .= ", "; }
				$modtxt .= (substr($mod, -1) . " = $modnum");
			}
		}
		if ($modtxt) {
			$modtxt =~ s!,([^,]*)$!, and/or$1!;
			$modstring .= "$modtxt modification of preceding amino acid. ";
		}
		if ($mods =~ m!\S!) { # any non-whitespace chars? Then print out the info
		  $modstring .= ("$mods"); 
		}
	}



    ## check all enzymes
    ($enzyme) = $mods[0] =~ m!Enzyme:\s*(\S+)!;
  
    $check = "\Q$enzyme\E";
    my $no_enz = 0;

    if ($enzyme eq "") {
      $enzyme = "None";
      $check = "";
      $no_enz = 1;
    }
    $temp = "";


    foreach $mod (@mods) {
      next if ($mod =~ m!Enzyme:\s*($check)\W!); # match end of word
      if ($mod =~ m!Enzyme:\s*(\S+)!) {
        $temp .= " $1";
        $check .= "|\Q$1\E";
      } else {
        next if $no_enz;

        $no_enz = 1;
        $temp .= " None";
      }
    }
    $enzyme .= " and" . $temp if ($temp);


	## XML CODE: (not ready for use yet)
	my %report_data = (	sample		=> {name => $stripped_samp, id => $dir_info{SampleID}},
						user		=> "$dir_info{LastName}, $dir_info{Initial}.",
						db			=> $db,
						sampledir	=> $dir_info{Sample},
						directory	=> $directory,
						files		=> "$file_string ($date_string)",
						maxrank		=> $MAX_RANK,
						enzyme		=> $enzyme,
						operator	=> $dir_info{"Operator"},
						bpmode		=> $BP_mode,
						modtext		=> $modstring,
	);

	my $xml = &create_xml_report(\%report_data, &consensus_data());		# a side effect of &consensus_data is that it creates the @all_bericht_seqs array

	my $R = scalar @all_bericht_seqs;
	my $D = 0;
	my %already_found_one = ();
	foreach $seq (@all_bericht_seqs) {		# calculate $D
		$seq =~ s/[#\*]//g;
		$D++ if ($already_found_one{$seq});
		$already_found_one{$seq} = 1;
	}


	open(RFILE,">$tempdir/$filename");
	print RFILE $xml;
	close(RFILE);

	select(STDOUT);

	
		&redirect("$webtempdir/$filename");
	
	return;




}


sub consensus_data {
	my ($file, $rank, $group_letter, $ref, $i, $num, $dataline);
	my @consensus = ();
	my %rankings = ();
	my @all_bericht_seqs = ();
	foreach $file (@orderedouts) {
		my $i = $number{$file};
		$rank = $ranking[$i];
		$rankings{$rank} = [] unless exists $rankings{$rank};

		if ($rank != -1) {
			$ref = $consensus_groupings[$rank];
			$num = $level_in_file{"$i:$ref"};
		} else {
			$num = -1;
		}
		my @a = (index => "$i:$num", rank => $rank);
		push (@a, "preferred_ref" => $ref) unless $rank == -1 || $rank eq "";

		$dataline = &return_one_dataline(@a);
		$R += 1 unless $rank == -1;
		## need to do:
		#unless ($empty{$file} || $rank != -1) {
		#	$dataline->{description} = &some_get_description_function_like_printdescrip_but_without_the_html($ref("$i:1"});
		#}
		
		push @{$rankings{$rank}}, $dataline;
	}

	my ($parseref, $refline, $refstuff, $description, @linedata, @reflines);
	foreach $rank (keys %rankings) {
		my %group = ();
		$description = "";
		$group_letter = &get_group_letter($rank);
		$group{letter} = $group_letter;
		if ($rank eq "") {
			$group{letter} = "No Group";
			$group{reference} = {id => -1, description => ""};
		}

		if ($rank != -1 && $rank ne "") {
			$ref = $consensus_groupings[$rank];
			$parseref = &parseentryid($ref);
			$refline = &lookupdesc($parseref);
			($refstuff, @linedata) = split(/\s/, $refline);

			## get the ref description:  (similar to &printdescrip)
			if ($refline ne "") {
				$description = "@linedata";
			} else {
				@reflines = @{$refdata{$parseref}};
				if ($reflines[0] ne "") {
					foreach $i (0..$#reflines) {
						$reflines[$i] =~ s/\s$//;
					}
					$refline = join '', @reflines;
					$description = "*$refline";
				}
			}
			$group{reference} = {id => $ref, description => $description};
		} 
		$group{spectra} = $rankings{$rank};		# an arrayref to the spectra hashrefs
		push @consensus, \%group;
	}
	return \@consensus;
}

sub create_xml_report {
	my $report = shift;
	my $consensus = shift;
	my ($xml, $refinfo, $consensus_data);
	
	### NOTE: use spaces, not tabs, for indenting this XML code ###

	$xml = <<HEAD;
<?xml version="1.0" encoding="ISO-8859-1"?>
<?xml-stylesheet type="text/xsl" href="/xml/summaryreport.xsl"?>
<report>
  <sample name="$report->{sample}{name}" id="$report->{sample}{id}"/>
  <user>$report->{user}</user>
  <operator>$report->{operator}</operator>
  <db>$report->{db}</db>
  <directory>$report->{directory}</directory>
  <sampledir>$report->{sampledir}</sampledir>
  <files>$report->{files}</files>
  <maxrank>$report->{maxrank}</maxrank>
  <enzyme>$report->{enzyme}</enzyme>
  <bpmode>$report->{bpmode}</bpmode>
  <modtext>$report->{modtext}</modtext>
  <runname></runname>
  <charge></charge>
HEAD
	my ($c, $group);
	my ($nogroupitem);

	my @list = sort {$b->{letter} cmp $a->{letter}} @{$consensus};
	
	# We have to do all of this to make sure groups with 2 letters sort after groups with one letter
	my @multiLetterGroups;
	my $count = 0;
	while (@list) {
		$item = shift @list;
		if (length($item->{letter}) > 1) {
			$multiLetterGroups[$count] = $item;
			$count++;
		} elsif ($item->{letter} eq "No Group") {
			$nogroupitem = $item;
		} else {
			unshift @newlist, $item;
		}
	}

	# Since the list is pushed one at a time, it ends up backwards so reverse it to end straight
	@multiLetterGroups = reverse @multiLetterGroups;
	foreach my $group (@multiLetterGroups) {
		push @newlist, $group;
	}

	# Put no group at the end of the list
	push @newlist, $nogroupitem;

	foreach $c (@newlist) {
		next unless $c->{letter} ne "";
		$xml .= <<DATA;
  <consensus group="$c->{letter}">
DATA
		if ($c->{reference}{id} != -1) {
			$xml .= <<REF;
    <reference id="$c->{reference}{id}">
      <description>$c->{reference}{description}</description>
    </reference>
REF
		}
		foreach $group (@{$c->{spectra}}) {
			# Do some stuff in case it is a no group
			if ($c->{reference}{id} == -1) {
				my $ref = $group->{ref};
				$parseref = &parseentryid($ref);
				$refline = &lookupdesc($parseref);
				($refstuff, @linedata) = split(/\s/, $refline);
				$noGroupDescription = "\n      <ngdescription>@linedata</ngdescription>";
			} else {
				$noGroupDescription = "";
			}

			$xml .= <<GROUP;
    <spectrum>
      <filenumber>$group->{filenumber}</filenumber>
      <sequence>$group->{sequence}</sequence>
      <ions>$group->{ions}</ions>
      <ref>$group->{ref}</ref>
      <refmore>$group->{refmore}</refmore>
      <scans>$group->{scanname}</scans>
      <mass>$group->{mass}</mass>
      <delm>$group->{delm}</delm>
      <xcorr>$group->{xcorr}</xcorr>
      <deltacn>$group->{deltacn}</deltacn>
      <sp>$group->{sp}</sp>
      <rsp>$group->{rsp}</rsp>
      <bp>$group->{bp}</bp>$noGroupDescription
    </spectrum>
GROUP
		}
		$xml .= <<DATA;
  </consensus>
DATA
	}
	
	$xml .= <<END;
</report>
END

	return $xml;
}


sub normal_header {
	my $addlheaders = shift;
	my $heading = qq(heading=<span style="color:#0080C0">Sequest</span> <span style="color:#0000FF">Summary</span>);
	if ($addlheaders) {
		&MS_pages_header("Sequest Summary", 0 , $heading , "newhttpheaders", $addlheaders, $docache);
	} else {
		&MS_pages_header("Sequest Summary", 0 , $heading , $docache);
	}
}

sub small_header {
# create header unique to sequest summary -- smaller than the standard include header
    print <<HEADER;
Content-type: text/html

<html>
<head>
$docache
<title>Sequest Summary</title>
$stylesheet_html
</head>
<BODY BGCOLOR="#FFFFFF" marginheight=5 topmargin=5>



<TABLE WIDTH=100% BORDER=0 CELLSPACING=0 CELLPADDING=0>
<TR VALIGN=middle>
<td align=left nowrap><span ID="header" style="font-family:times,serif; font-size:20pt; font-weight:bold"><span style="color:#0080C0">Sequest</span> <span style="color:#0000FF">Summary</span></span></td>
</tr></table>
HEADER
#<TD nowrap><A HREF="$setupdirs" target="_top" class=smallheading style="color:#808080; text-decoration:none">Setup</A></TD>
#<TD nowrap><A HREF="$create_dta" target="_top" class=smallheading style="color:#808080; text-decoration:none">CreateDTA</A></TD>
#<TD nowrap><A HREF="$VuDTA" target="_top" class=smallheading style="color:#808080; text-decoration:none">VuDTA</A></TD>
#<TD nowrap><A HREF="$seqlaunch" target="_top" class=smallheading style="color:#808080; text-decoration:none">RunSequest</A></TD>
#<TD nowrap><A HREF="$seqstatus" target="_top" class=smallheading style="color:#808080; text-decoration:none">Status</A></TD>
#<TD nowrap><A HREF="$createsummary" target="_top" class=smallheading style="color:#808080; text-decoration:none">Summary</A></TD>
#<!--<td nowrap><A HREF="$UTILS"  target="_top" class=smallheading style="color:#808080; text-decoration:none">Utilities</A></td>-->
#<td nowrap><a href= "$HOMEPAGE"  target="_top" class=smallheading style="color:#808080; text-decoration:none">Home</a></td>
#</TR>
#</TABLE>
#-->
#HEADER

}


sub post_checkbox_js {

	print <<EOF;

<script language="Javascript">
<!--
EOF
	if (scalar(@checkbox_BPs) == 1) {
		print <<EOF;
var BP = $checkbox_BPs[0];
EOF
	} elsif (scalar(@checkbox_BPs) > 1) {
		print "var BP = new Array(" . join(",",@checkbox_BPs) . ");\n";
	}
	print <<EOF;

//-->
</script>

EOF

}


##########################################################
# print form and Javascript code to control DTA VCR window
sub dta_vcr_code {

	# create a unique name for the dta_vcr window (includes both pid and start time of this Perl process)
	$dta_vcr_name = "dtavcr" . $$ . $^T;

	my $linkvalue = join("<DTAVCR>", @dtavcr_links);
	my $infovalue = join("<DTAVCR>", @dtavcr_infos);
	my $includeifvalue = join("<DTAVCR>", @dtavcr_include_ifs);

	# Must translate all mod characters out of the pep cgi value for flicka to work
	$infovalue =~ s/(flicka.pl.*?Pep=.*?)[\*\#\@\^\~\$]/$1/g;

	# get rid of line breaks
	foreach ($linkvalue,$infovalue,$includeifvalue) {
		s/\n/ /g;
	}

	#$legend = "    #       TIC                File           z       dM         MH+     XCorr    dCn         Sp       RSp       Ions               Ref                           ()   Sequence";
	#$legend =~ s/ /&nbsp;/g;
	# modified 10/24/99 to prevent major Javascript and caching problems on large pages:
	# instead of including a huge amount of info in hidden form elements on the page, put it in a temp file
	$vcr_file = "$tempdir/$dta_vcr_name.txt";
	open(VCRFILE, ">$vcr_file");
	print VCRFILE "DTAVCR:link=$linkvalue\n";
	print VCRFILE "DTAVCR:info=$infovalue\n";
	print VCRFILE "DTAVCR:include_if=$includeifvalue\n" if ($boxtype ne "HIDDEN");
	close VCRFILE;

	# use a hidden form element to tell DTA VCR window where that file is
	print qq(<input type=hidden name="DTAVCR:tempfile" value="$vcr_file">);
	print qq(<input type=hidden name="DTAVCR:legend" value="$legend">);
	print <<EOF;
<script language="Javascript">
<!--

	// declare reference to DTA-VCR window as a global variable
	var dta_vcr;
	var oldaction;
	var oldtarget;
	
	function openDTA_VCR()
	{
		if (dta_vcr && !dta_vcr.closed) {

			dta_vcr.focus();

		} else {

			oldaction = document.mainform.action;
			oldtarget = document.mainform.target;

			document.mainform.action="$webcgi/dta_vcr.pl";
			document.mainform.target="$dta_vcr_name";
			
			dta_vcr = open("javascript:opener.document.mainform.submit()","$dta_vcr_name","resizable");

			//mywindows.length++;
			//mywindows[mywindows.length-1] = dta_vcr;

		}

	}
	function DTA_VCR_revert() {
		document.mainform.action = oldaction;
		document.mainform.target = oldtarget;
	}
/*
	function DTA_VCR_cleanup()
	{
		// put things back as they were
		document.mainform.action = oldaction;
		document.mainform.target = oldtarget;
		dta_vcr.onfocus = null;
	}
*/
	function vcr_update_opener(idx)
	{
		var i, j;

		if (!document.mainform.selected)
			return;
		
		// idx # refers to the DTA's position among DTAs with checkboxes only
		// if some DTAs are filtered out, we need to skip them (they'll be input type=hidden)
		if (document.mainform.selected.length) {
			for (i = 0, j = 0; i < document.mainform.selected.length; i++) {
				if (document.mainform.selected[i].type == "checkbox") {
					if (j == idx) {
						cousin = document.mainform.selected[i];
						break;
					} else {
						j++;
					}
				}
			}
		} else {
			cousin = document.mainform.selected;
		}
		
		if (dta_vcr.middleframe.infoframe.document.forms[0].selected)
			cousin.checked = dta_vcr.middleframe.infoframe.document.forms[0].selected.checked;
	}
	// this function is called by the vcr window itself when middle frame is updated
	function vcr_update_info(idx)
	{
		if (!document.mainform.selected)
			return;

		// idx # refers to the DTA's position among DTAs with checkboxes only
		// if some DTAs are filtered out, we need to skip them (they'll be input type=hidden)
		if (document.mainform.selected.length) {
			for (i = 0, j = 0; i < document.mainform.selected.length; i++) {
				if (document.mainform.selected[i].type == "checkbox") {
					if (j == idx) {
						cousin = document.mainform.selected[i];
						break;
					} else {
						j++;
					}
				}
			}
		} else {
			cousin = document.mainform.selected;
		}

		if (dta_vcr.middleframe.infoframe.document.forms[0].selected)
			dta_vcr.middleframe.infoframe.document.forms[0].selected.checked = cousin.checked;
	}
//-->
</script>
EOF
}
#######################
# end of dta_vcr_code #
#######################



sub error {
  print <<EOF;
<HR>
<P>

$ICONS{'error'}@_
</body></html>
EOF
 exit();
}


# dmitry 3/8/99
sub showLogRunAndBericht
{
	my $berichtName = $_[0];
	my $time = $_[1];
	my $runs = $_[2];
	my $dups = $_[3];
	my $use_xml = $_[4];
	my ($sampleID, $sample, %dir_info, $instrument, $suffix, $oper, $dir);
	%dir_info = &get_dir_attribs("$directory");
	$sampleID  = $dir_info{"SampleID"};
	$sample = $dir_info{"Sample"};
	$sample =~ s/_.*//g;
	$oper = $operator;				# global variable
	$dir = $directory;				# global variable

	#if($outs[0] =~ m!^[0-9]{4}Z!) {
	#	$instrument = "SZQ";
	#} else {
	#	$instrument = "LCQ";
	#}

	$outs[0] =~ m!^([0-9]{4})([ZQF])?!; # If instruments are added or deleted, add letter inside of [ZQF]
	if ($2 eq "Z") {
		$instrument = "SZQ";
	} elsif ($2 eq "Q") {
		$instrument = "BBQ";
	} elsif ($2 eq "F") {
		$instrument = "QTF";
	} else {
		$instrument = "LCQ"; 
	}

	if($database[0] =~ m/^nr/i)		 { $suffix = "snr"; }
	elsif($database[0] =~ m/est/i)	 { $suffix = "sest"; }
	elsif($database[0] =~ m/yeast/i) { $suffix = "ssc"; }
	else							 { $suffix = "s"; }

	my $use_xml_str = ($use_xml) ? "&usexml=yes" : "";

	print <<EOF;
Content-type: text/html

<html>
<head>
<title>Summary Report</title>
$stylesheet_html
</head>

<frameset rows=280,*>
	<frame name="logrun" src="logrun.pl?sample_id=$sampleID&sample=$sample&instrument=$instrument&runs=$runs&dups=$dups&suffix=$suffix&oper=$oper&directory=$dir&time=$time$use_xml_str"></frame>
	<frame name="bericht" src="$berichtName"></frame>
</frameset>
</html>

EOF
}

#11/13/01
sub wait_for_sf{										
	delete $FORM{"wait_for_sf"};
	my($total_wait_time);
	until(-e "$seqdir/$dir/seq_score_combiner.txt"){
		sleep(0.2);
		$total_wait_time += 0.2;
		last if( $total_wait_time > 20);
	}
	# Now that the file exists, wait for it to be completed.
	sleep(2.5);
}

sub build_and_submit_form {
	# HACK
	#
	# so: we want, as much as possible, to preserve form input state (checkbox state, mostly) when navigating away from
	# the page and returning via the 'back' button
	#
	# Internet Explorer will frequently re-request (thus destroying form input state) pages generated via a 
	# cgi GET, but is much more reluctant to do so with page generated via a POST
	#
	# so, if the page wasn't generated with a form POST, we do it here.
	#
	# ick, ick, ick.

	my $thetime = time;

	print <<EOF;
Content-type: text/html

<html>
<body>
<form method=post name=mainform action="$ourname">
EOF

	foreach $var (keys %FORM) {
		print qq(<input type=hidden name="$var" value="$FORM{$var}">);
	}

print <<EOF;
<input name="thetime" value="$thetime" type=hidden>
</form>
</body>
</html>
EOF
}


sub readSigcalcFile{
	open PROBFILE, "$seqdir/$dir/probability.txt" or $NO_PROB_FILE = 1;
	my($thisFile,$thisSeq,$thisScore);
	while( <PROBFILE>){
		($thisFile,$thisSeq,$thisScore) = split / /;
		$thisScore =~ s/\s//;			#chop off any whitespace
		$probscores{"$thisFile $thisSeq"} = $thisScore;
		$probscoresByFile{"$thisFile"} = $thisScore unless exists $probscoresByFile{"$thisFile"};  # use this 'unless' to hash the probability for the first sequence in each file - without it, the last
	}
	close PROBFILE;
}

# preserve consensus group expand/collapse state even when viewing in non-consensus mode
#
# there must be a better way to do this.
sub print_hidden_expand_state_inputs {
	foreach $argname (keys %FORM) {
		if ($argname =~ m!^expand_!) {
			print qq(<input type=hidden name="$argname" value="$FORM{$argname}">);
		}
	}
}


##PERLDOC##
# Function : get_deletions_from_logfile
# Argument : a sequest directory name
# Globals  : none
# Returns  : a space-separated string containing numbers of dta sets deleted according to the log file for this directory
# Descript : 
# Notes    : 
##ENDPERLDOC##
sub get_deletions_from_logfile {
	my $dir = shift;
	open(LOGFILE, "$seqdir/$dir/$dir.log") or return "";
	my @deletionlines = grep /^deletion\d/i, <LOGFILE>;
	close(LOGFILE);
	@deletionlines = splice @deletionlines, 0, 3;
	my @results;
	my @refdirs;
	my $delindex;
	my $i = 0;
	foreach (@deletionlines) {
		m/deletion(\d)/i;
		$delindex = $1;
		while ($i < $delindex) {		# handle missing entrys by substituting dashes
			push @results, "-";
			push @refdirs, "---";
			$i++;
		}
		m/(\d+)\s+DTA/i;		# note: these regexps may need to be changed if the format for these lines in the log file changes
		push @results, $1;
		m/refdir=(\S+)/i;
		push @refdirs, $1;
		$i++;
	}

	return (join ' ', @results), (join ' | ', @refdirs);
}

