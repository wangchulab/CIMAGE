#!/usr/local/bin/perl

#-------------------------------------
#	FuzzyIons,
#	(C)1999-2002 Harvard University
#	
#	C. J. Taubman / B. L. Miller
#	B. Guaraldi  / W. S. Lane
#
#	v3.1a
#	
#	licensed to Finnigan
#
#-------------------------------------


#-------------------------------------------------------------------
# fuzzyions.pl:
# Perl file that outputs all the HTML for Fuzzyions.
# Requires fuzzycore.exe to draw and transmit the fuzzy gif.
#
# Includes what was once fuzzyeft.pl, written by C. J. Taubman.
#-------------------------------------------------------------------

###################################################################################################
# Some notes about Fuzzy, from Ben Miller and Ben Guaraldi:
#
# Fuzzyions is best thought of as three separate components or programs interacting together:
# the Perl component, the Javascript (or DHTML) component, and the C (or executable) component.
# This last component is compiled into fuzzycore.exe, and is really the guts of Fuzzy.
#
# This file contains the Perl component and the Javascript component.  That is, it is a Perl 
# program that outputs a Javascript program.
#
# The Perl component gets information from the URL about which .dta file is being examined as well 
# as any special options.  Then it outputs a relatively simple Javascript program, which you can 
# see by doing View, Source on a fuzzyions.pl page.
#
# One interesting tidbit on the Javascript program: the topmost frame is divided in half is a
# one-pixel frame.  The left half loads fuzzycore.exe, which enables most of the functionality of 
# the program.  The right half resubmits to fuzzyions.pl, which allows us to do things on the perl
# side without reloading the program.  The only feature that is implemented that way is runsequest.
#
# Some info on the C or executable component, a.k.a. fuzzycore.exe:
# It gets all the specific information it requires via GET, does calculations, draws and saves 
# a new gif reflecting these calculations, and outputs an HTML page with Javascript code that 
# changes the source of the main image tag and otherwise communicates with the Perl-generated
# Javascript program (i.e., the JS created by this page).
#
# Fuzzycore.exe is quite similar to the original Fuzzy (see NB below).  Mostly it differs its
# output.  Originally, it printed the whole page; now it just prints some javascript.
#
# Key C files: fuzzyions.c, fuzzyoptions.c, gd.c, gdfontmb.c, gdfonts.c, imagehandler.c, 
# massdata.c, mtables.c, processdata.c, util.c, definitions.h and the .h files that correspond
# to all the c files above.  fuzzycore is checked into the VSS database.
#
# As of 2/24, Fuzzy also uses proteinmenus.js for the menus.
#
# NB: fuzzyions.exe is an earlier, entirely compiled version of Fuzzy.  We keep it around because 
# it's purported to work with Netscape.  This version doesn't at all--rather, it forwards the user
# to fuzzyions.exe.
#
###################################################################################################
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
###################################################################################################

&cgi_receive;	# put cgi data in $FORM

if ($FORM{"runsequest"}) { &runsequest(); }

&initialize();	# initialize variables

if (!(-e $dtafile)) { &error("Cannot find dta $dtafile.  Sorry.");  }

&header();		# print standard html header
&javascript();	# print javascript functions
&frameset();	# print frameset html
&tail();		# print standard html tail
exit(0);		# done

###################################################################################################
##PERLDOC##
# Function : initialize
# Argument : none
# Globals  : a whole lot
# Returns  : none
# Descript : creates the variables used by the rest of Fuzzy
##ENDPERLDOC##

sub initialize {

$incoming = "";
foreach $formkey (keys %FORM) {
	($key,$value) = ($formkey,$FORM{$formkey});
	foreach ($key, $value) {
		$_ = &url_encode($_) if (/[:# <>\"]/);
	}
	$incoming .= "&" if ($incoming);
	$incoming .= "$key=$value";
}

@initial_mpc_alts = ("oxidmet", "phosphate"); #, "CAM"
$initial_mpc_col = "blu";
$white = "#FFFFFF";
$dif_tolerance = 1.0;

# Source scripts/executables/files for links out of fuzzy
$fullview_binary = "$webcgi/fullview.exe";
$ionlist_binary = "$webcgi/seq_ionlist.exe";
$zoom_binary = "$webcgi/zoomdisplay.exe";
$scratchpad_binary = "$webcgi/edit_scratchpad.pl";
$dtacontrol_binary = "$webcgi/dta_control.pl";
$gap_binary = "$webcgi/gap.pl";

# Information necessary to load the image files into memory
$fuzzy_image_dir = "${webimagedir}/fuzzybuts";
@letters = ("G", "A", "S", "P", "V", "T", "C", "I", "L", "N", "D", "Q", "K", "E", "M", "H", "F", "R", "Cp", "Y", "Cpp", "W", "J");
@coloursEnglish = ("blu", "pur", "org", "red");
@mpcs = ("Msx", "PO4"); #, "CAM"
@mpc_colours = ("blu", "red");

# Names of the frames
$exe_fname = "exeFrame";
$perl_fname = "perlFrame";
$main_fname = "mainFrame";
$header_fname = "headerFrame";
$workspace_fname = "workspaceFrame";
$bottom_fname = "bottomFrame";

# Sources of this document and frames
$our_source = "$webcgi/fuzzyions.pl";
$fuzzy_source = "fuzzycore.exe"; 

# Style sheet for fuzzy buttons
# For some reason, if you use the statement below, it causes all sorts of Javascript errors.
# $fuzzy_buts = "$webincdir/fuzzyions.css";
$fuzzy_buts = "
<style type='text/css'>

.fuzzybutton {
	border:solid 2px;
	padding-top:1px;
	text-align:center;
	vertical-align:middle;
	cursor:hand;
	font-family:Arial;
	font-size:11;
	font-weight:bold;
	color:#ffffff;
}
.littlefuzzybutton {
	border:solid 2px;
	padding-top:1px;
	text-align:center;
	vertical-align:middle;
	cursor:hand;
	color:#ffffff;
}
.blu {
	background-color:#0080c0;
	border-color:#80c0e0 #004060 #004060 #80c0e0;
}
.red {
	background-color:#FF0000;
	border-color:#FF8080 #800000 #800000 #FF8080;
}
.org {
	background-color:#FF7F00;
	border-color:#FFBF80 #804000 #804000 #FFBF80;
}
.pur {
	background-color:#800080;
	border-color:#C080C0 #400040 #400040 #C080C0;
}
.blu-inverted {
	background-color:#0080c0;
	border-color:#006040 #80c0e0 #80c0e0 #006040;
}
.lightblu {
	background-color:#40a0d0;
	border-color:#a0d0e8 #205068 #205068 #a0d0e8;
}
.lightblu-inverted {
	background-color:#40a0d0;
	border-color:#205068 #a0d0e8 #a0d0e8 #205068;
}
.red-inverted {
	background-color:#FF0000;
	border-color:#800000 #FF8080 #FF8080 #800000;
}
.midblu {
	background-color:#4682b4;
	border-color:#a3c1da #23415a #23415a #a3c1da;
}
.midblu-inverted{
	background-color:#4682b4;
	border-color:#23415a #a3c1da #a3c1da #23415a;
}
.darkblu {
	background-color:#191970;
	border-color:#8c8cb8 #0d0d38 #0d0d38 #8c8cb8;
}
.darkblu-inverted{
	background-color:#191970;
	border-color:#0d0d38 #8c8cb8 #8c8cb8 0d0d38;
}
.lightpur {
	background-color:#8a2be2;
	border-color:#c595f1 #451671 #451671 #c595f1;
}
.highlight {
	background-color:#dc143c;
	border-color:#ee8a9e #6e0a1e #6e0a1e #ee8a9e;
}
</style>
";

$Ctermspace =		(defined $FORM{"Ctermspace"} ?			$FORM{"Ctermspace"} :		"");
$Ntermspace =		(defined $FORM{"Ntermspace"} ?			$FORM{"Ntermspace"} :		"");
$Total_MHplus = 	(defined $FORM{"Total_MHplus"} ?		$FORM{"Total_MHplus"} :		"0.0");
$numaxis =			(defined $FORM{"NumAxis"} ?				$FORM{"NumAxis"} :			1 );
$mzman =			(defined $FORM{"mzman"} ?				$FORM{"mzman"} :			"" );
$massmin =			(defined $FORM{"massmin"} ?				$FORM{"massmin"} :			0 );
$massmax =			(defined $FORM{"massmax"} ?				$FORM{"massmax"} :			0 );
$massj =			(defined $FORM{"MassJ"} ?				$FORM{"MassJ"} :			0 );
$customminormass =	(defined $FORM{"customminormass"} ?		$FORM{"customminormass"} :	0 );
$aions =			(defined $FORM{"aions"} ?				$FORM{"aions"} :			"checked" );
$bions =			(defined $FORM{"bions"} ?				$FORM{"bions"} :			"checked" );
$yions =			(defined $FORM{"yions"} ?				$FORM{"yions"} :			"checked" );
$doublycharged =	(defined $FORM{"doublycharged"} ?		$FORM{"doublycharged"} :	"" );
$triplycharged =	(defined $FORM{"triplycharged"} ?		$FORM{"triplycharged"} :	"" );
$quadruplycharged =	(defined $FORM{"quadruplycharged"} ?	$FORM{"quadruplycharged"} :	"" );
$ladders =			(defined $FORM{"ladders"} ?				$FORM{"ladders"} :			"" );
$ladders2 =			(defined $FORM{"ladders2"} ?			$FORM{"ladders2"} :			"" );
$ladders3 =			(defined $FORM{"ladders3"} ?			$FORM{"ladders3"} :			"" );
$ion_to_jump_to =	(defined $FORM{"ion_to_jump_to"} ?		$FORM{"ion_to_jump_to"} :	"Y" );
$side_to_walk =		(defined $FORM{"side_to_walk"} ?		$FORM{"side_to_walk"} :		"Cterm" );
$minor_ions =		(defined $FORM{"minor_ions"} ?			$FORM{"minor_ions"} :		"" );
$whichminor =		(defined $FORM{"whichminor"} ?			$FORM{"whichminor"} :		"water" );
$cys_alkyl =		(defined $FORM{"cys_alkyl"} ?			$FORM{"cys_alkyl"} :		"CAM" );
$interior_ions_on =	(defined $FORM{"interior_ions_on"} ?	$FORM{"interior_ions_on"} :	"" );
$interior_ions =	(defined $FORM{"interior_ions"} ?		$FORM{"interior_ions"} :	"PH" );
$expand_space =		(defined $FORM{"expand_space"} ?		$FORM{"expand_space"} :		"75" );
$tolerance =		(defined $FORM{"tolerance"} ?			$FORM{"tolerance"} :		"3.0" );
$MassType =			(defined $FORM{"MassType"} ?			$FORM{"MassType"} :			"1" );
$abpair =			(defined $FORM{"abpair"} ?				$FORM{"abpair"} :			"" );
$abthresh =			(defined $FORM{"abthresh"} ?			$FORM{"abthresh"} :			$DEFS_FUZZY{"a/b threshhold"} );
$penaltydiv =		(defined $FORM{"penaltydiv"} ?			$FORM{"penaltydiv"} :		$DEFS_FUZZY{"missed peak score penalty divisor"} );
$lossesdiv =		(defined $FORM{"lossesdiv"} ?			$FORM{"lossesdiv"} :		$DEFS_FUZZY{"losses score divisor"} );

$Cterm_box =		($side_to_walk eq "Cterm" ?		"checked" : "" );
$Nterm_box =		($side_to_walk eq "Nterm" ?		"checked" : "" );
$abpair_box =		($abpair == 1 ?					"checked" : "" );

$dtafile = $FORM{"Dta"} || $FORM{"dtafile"};	# the name of the data file -- backwards compatible
$dtafile =~ s|\S%3A%2FSequest|$seqdir|;			# Hack the file name to the correct place -- Ben 5/6/02
$dtafile =~ s|\S:/Sequest|$seqdir|;

$incoming =~ s|\S%3A%2FSequest|$seqdir|;		# Make sure the querystring points there, too

($ignore, $dtaname) = split /$seqdir/, $dtafile;
($dtaname, $ignore) = split /.dta/, $dtaname;
($ignore, $dtaname) = split /^\/.*\//, $dtaname;

$dtafilename = $dtaname . ".dta";
$dtafile =~ m!.*[\\/](.*)[\\/]+!;
$directory = $1;
$dtaname =~ m!\.(\d)$!;
$z = $1;

$dtaformarg = &url_encode($dtafilename);
$dirformarg = &url_encode($directory);

# Only display zooms if we have a zta.  This doesn't actually work, though, as the
# C code adds a link--but now we're doing it differently, so we could make it work...
$displayzooms = 0;
$dtafile =~ m/^(.*)\//;
opendir ZOOM, $1;
@zoomdir = readdir ZOOM;
closedir ZOOM;
foreach $possible_zoom (@zoomdir) {
	if ($possible_zoom =~ m/\.zta/) {
		$displayzooms = 1;
		last;
	}
}
$zoomurl = ($displayzooms ? qq|"$webcgi/zoomdisplay.exe?Dta=$dtafile" target="_blank"| : "alert");

$muquesturl = "$webcgi/muquest.pl?dtafile=$dtaformarg&directory=$dirformarg";
$qtercoolurl = "$webcgi/qter-cool.pl?directory=$dirformarg&execute=1";

$numaxisstring = "NumAxis=" . &url_encode($numaxis);
$dtastring = "Dta=" . &url_encode($dtafile);
$username = &url_encode($FORM{"username"});
$comments = $FORM{"comments"};

$fuzzy_source = "$fuzzy_source?progname=$our_source&$incoming&penaltydiv=$penaltydiv&lossesdiv=$lossesdiv";

# Add the a/b threshhold if we've got a/b pairing switched on.
if ($abpair) { $fuzzy_source .= "&abthresh=$abthresh"; }

# The aarulers are off by default (as we assume we've already been sequencing) (bill wants it this way 2/2/01)
$aaruler_selected = 0;

# If we have not already started sequencing...
if (!($Ctermspace || $Ntermspace)) {
	$ladders = "checked";
}

# Account for viewlog
if ($ladders) { $aaruler_selected = 4; }
if ($ladders2) { $aaruler_selected += 2; }
if ($ladders3) { $aaruler_selected += 1; }
	
$ions_show = 0;
if ($aions) { $ions_show += 4; }
if ($bions) { $ions_show += 2; }
if ($yions) { $ions_show += 1; }
if ($abpair) { $ions_show += 8; }

$ions_selected = 0;
if ($doublycharged) { $ions_selected += 1; }
if ($triplycharged) { $ions_selected += 2; }
if ($quadruplycharged) { $ions_selected += 4; }

if ($ion_to_jump_to eq "special") {
	$next_select = 0;
} elsif ($ion_to_jump_to eq "B") {
	$next_select = 1;
} else {
	$next_select = 2;
}

$Ctermspace =~ s/ //g;
$Ntermspace =~ s/ //g;

}

###################################################################################################
##PERLDOC##
# Function : header
# Descript : prints an html header
# Notes    : probably doesn't need to be a separate function
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub header {
print <<EOF;
Content-type: text/html

<html>
<head>
<title>FuzzyIons</title>
EOF

print $stylesheet_html;

}

###################################################################################################
##PERLDOC##
# Function : frameset
# Descript : prints the frameset for the page
# Notes    : The fuzzy frame is only one pixel tall and
#			 the same colour as the background of the main frame, so it is virtually invisible. It only
#			 exists as a vehicle to load fuzzycore.exe, which creates the gif image and some javascript to
#			 to change the image as appropriate.
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub frameset {

print <<MAINPAGE;
<FRAMESET ROWS="1, 755" BORDER=0 FRAMEBORDER="no" onLoad="init()">	
	<FRAMESET COLS="*,*">
		<FRAME NAME="$exe_fname" src="$fuzzy_source" SCROLLING=no NORESIZE>
		<FRAME NAME="$perl_fname" src="javascript:parent.emptyPage()" SCROLLING=no NORESIZE>
	</FRAMESET>
	<FRAMESET ROWS="55, 700">
		<FRAME NAME="$header_fname" src="javascript:parent.headerPage()" marginwidth=0 marginheight=0 scrolling=no NORESIZE>
		<FRAMESET COLS="219, *">
			<FRAMESET ROWS="265, *">
				<FRAME NAME="$workspace_fname" src="javascript:parent.workspacePage()" marginwidth=0 marginheight=0 SCROLLING=no NORESIZE>
				<FRAME NAME="$bottom_fname" src="javascript:parent.bottomPage()" marginwidth=0 marginheight=0 NORESIZE>
			</FRAMESET>
			<FRAME FRAMEBORDER="yes" BORDERCOLOR="000000" BORDER=1 NAME="$main_fname" src="javascript:parent.mainPage()" marginwidth=0 marginheight=0 SCROLLING=auto NORESIZE>
		</FRAMESET>
	</FRAMESET>
</FRAMESET>
MAINPAGE

}

###################################################################################################
##PERLDOC##
# Function : tail
# Descript : prints the end html tag
# Notes    : probably doesn't need to be a separate function;
# Argument : no arguments or returns
##ENDPERLDOC##

sub tail {
print <<EOF;
</html>
EOF
}

###################################################################################################
##PERLDOC##
# Function : javascript
# Descript : prints the Javascript code that handles all of the more mundane aspects of Fuzzy
# Notes    : huge, eh?  calls the load_..._images functions and create_frame_javascript
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub javascript {

# Create a unique name for the NCBI window (includes both pid ($$) and start time ($^T) of this Perl process)
$NCBIsuffix = $$ . $^T;

print <<EOF;
<script language="Javascript">
<!--
	var windowcount = 0;
	var matchArray = new Array();
	var mpcmatchArray = new Array();
	var buttonArray = new Array();
	var mpcArray = new Array();
	var selectedButNum = 0;
	var aaruler_selectedButNum = $aaruler_selected;
	var ions_selectedButNum = $ions_selected;
	var show_selectedButNum = $ions_show;
	//var send_selectedButNum = 0;
	var next_selectedButNum = $next_select;
	var blastSeq = new String("");
	var bCheckExists = false;
	var yCheckExists = false;
	var mainLoaded = false;
	var dtafile = "$dtafile";
	var fullviewbinary = "$fullview_binary";
	var ionlistbinary = "$ionlist_binary";
	var zoombinary = "$zoom_binary";
	var scratchpadbinary = "$scratchpad_binary";
	var dtacontrolbinary = "$dtacontrol_binary";
	var mpcNames = new Array("oxidmet", "phosphate");//, "CAM"
	var logWindow;
	var logWindowUp = false;

	var realMHplus;
	var ProteinMenuInitialized;
	var fullviewurl, controlurl, scratchurl, viewlogrun;
	var qtercoolurl = "$qtercoolurl";
	var muquesturl  = "$muquesturl";
	var zoomrun     = "parent.open('" + $zoomurl + "');";
	var ionlisturl  = "$webcgi/seq_ionlist.exe?Dta=${dtafile}&amp;MassType=1&amp;Pep=&amp;NumAxis=1&amp;MassC=160.1";

/*************************************************************************************************/
EOF

&load_buttons();

print <<EOF;

/*************************************************************************************************/
// LITTLE HELPER FUNCTIONS

	// fuzzyions.pl doesn't work in Netscape, so repoint to fuzzyions.exe.
	function init() {
		if (navigator.appName == "Netscape") {
			document.location.href = "$webcgi/fuzzyions.exe?$incoming";
		}
		setTimeout("next_submit();", 100);
	}

	// Writes a message to the status bar.
	function setMsg(msg) {
		window.status = msg;
		return true;
	}

	// Set the values in the main form that hold the coordinates of a picture click to null.
	function disable_xy() {
		var the_form = window.${main_fname}.document.mainform;

		the_form.x.value = "";
		the_form.y.value = "";
	}

	// Set the sequence used by the blast link to seq.
	function set_blastseq(seq) {
		blastSeq = seq;
	} 

	// Returns the index value from matchArray, with some error checking.
	function match(index) {
		if (matchArray[index]) {
			return matchArray[index] % 4;
		} else {
			return 0;
		}
	}

	// Returns the index value from mpcmatchArray, with some error checking.
	function mpcmatch(index) {
		if (mpcmatchArray[index]) {
			return mpcmatchArray[index] % 4;
		} else {
			return 0;
		}
	}

	// Highlights leftui button "num"
	function leftui_but_highlight(num) {
		var buttonId = "leftui" + num;
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		if (button.className != "littlefuzzybutton blu-inverted smallheading") {
			button.className = "littlefuzzybutton highlight smallheading";
		}
	}

	// Unhighlights leftui button "num"
	function leftui_but_unhighlight(num) {
		var buttonId = "leftui" + num;
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		if (button.className != "littlefuzzybutton blu-inverted smallheading") {
			button.className = "littlefuzzybutton blu smallheading";
		}
	}
		
	// Inverts leftui button "num"
	function leftui_but_invert(num) {
		var buttonId = "leftui" + num;
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		if (button.className == "littlefuzzybutton blu-inverted smallheading") {
			button.className = "littlefuzzybutton blu smallheading";
		} else {
			button.className = "littlefuzzybutton blu-inverted smallheading"
		}
	}

	//Unhighlights lcd button "num"
	function lcd_but_unhighlight(num) {
		var buttonId = "lcdbut" + num;
		var button = window.${header_fname}.document.getElementById(buttonId);
		button.className = buttonArray[match(num)];
	}


	//Unhights mpc button "num"
	function mpc_but_unhighlight(num) {
		var buttonId = "mpcbut" + num;
		var button = window.${header_fname}.document.getElementById(buttonId);
		button.className = mpcArray[mpcmatch(num)];
	}


	// Highlights axis button "num"
	function axis_but_highlight(num) {
		if(num != selectedButNum) {
			var buttonId = "NumAxis" + num;
			var button = window.${header_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton highlight";
		}
	}

	// Unhighlights axis button "num"
	function axis_but_unhighlight(num) {
		if(num != selectedButNum) {
			axis_but_revert(num);
		}
	}

	// Inverts axis button "num"
	function axis_but_invert(num) {
		var buttonId = "NumAxis" + num;
		var button = window.${header_fname}.document.getElementById(buttonId);
		button.className = "fuzzybutton lightblu-inverted";
	}

	// Makes axis button "num" unhighlighted and uninverted
	function axis_but_revert(num) {
		var buttonId = "NumAxis" + num;
		var button = window.${header_fname}.document.getElementById(buttonId);
		button.className = "fuzzybutton lightblu";
	}


	// Highlights mark next button "num"
	function next_but_highlight(num) {
		if(num != next_selectedButNum) {
			var buttonId;
			if (num == 0) {
				buttonId = "nextspecial";
			}
			else if (num == 1) {
				buttonId = "nextb";
			}
			else if (num == 2) {
				buttonId = "nexty";
			}
			var button = window.${workspace_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton highlight";
		}
	}
	// Unhighlights mark next button "num"
	function next_but_unhighlight(num) {
		if(num != next_selectedButNum) {
			next_but_revert(num);
		}
	}

	// Makes mark next button "num" unhighlighted and uninverted
	function next_but_revert(num) {
		var buttonId;
		if (num == 0) {
			buttonId = "nextspecial";
		}
		else if (num == 1) {
			buttonId = "nextb";
		}
		else if (num == 2) {
			buttonId = "nexty";
		}
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		button.className = "fuzzybutton midblu";
	}


	// Highlights ions button "num"
	// ions_selectedButNum is between 0-7, with each bit corresponding to each button.
	// (For example, if 2+ and 4+ are selected, ions_selectedButNum = 1 + 4, or 5.)
	function ions_but_highlight(num) {
		if(((num == 2) && (ions_selectedButNum != 4) && (ions_selectedButNum != 5) &&
						  (ions_selectedButNum != 6) && (ions_selectedButNum != 7)) ||
		   ((num == 1) && (ions_selectedButNum != 2) && (ions_selectedButNum != 3) &&
						  (ions_selectedButNum != 6) && (ions_selectedButNum != 7)) ||
		   ((num == 0) && (ions_selectedButNum != 1) && (ions_selectedButNum != 3) &&
						  (ions_selectedButNum != 5) && (ions_selectedButNum != 7)))
		{
			var number = num +2;
			var buttonId = "ions" + number + "+";
			var button = window.${workspace_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton highlight";
		}
	}

	// Unhighlights ions button "num"
	// See above for info about ions_selectedButNum.
	function ions_but_unhighlight(num) {
		if(((num == 2) && (ions_selectedButNum != 4) && (ions_selectedButNum != 5) &&
						  (ions_selectedButNum != 6) && (ions_selectedButNum != 7)) ||
		   ((num == 1) && (ions_selectedButNum != 2) && (ions_selectedButNum != 3) &&
						  (ions_selectedButNum != 6) && (ions_selectedButNum != 7)) ||
		   ((num == 0) && (ions_selectedButNum != 1) && (ions_selectedButNum != 3) &&
						  (ions_selectedButNum != 5) && (ions_selectedButNum != 7)))
		{
			ions_but_revert(num);
		}
	}

	// Makes send button "num" unhighlighted and uninverted
	function ions_but_revert(num) {
			var number = num + 2;
			var buttonId = "ions" + number + "+";
			var button = window.${workspace_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton midblu";
	}


	// Highlights aaruler button "num"
	// aaruler_selectedButNum works like ions_selectedButNum.  See above.
	function aaruler_but_highlight(num) {
		if(((num == 0) && (aaruler_selectedButNum != 4) && (aaruler_selectedButNum != 5) &&
						  (aaruler_selectedButNum != 6) && (aaruler_selectedButNum != 7)) ||
		   ((num == 1) && (aaruler_selectedButNum != 2) && (aaruler_selectedButNum != 3) &&
						  (aaruler_selectedButNum != 6) && (aaruler_selectedButNum != 7)) ||
		   ((num == 2) && (aaruler_selectedButNum != 1) && (aaruler_selectedButNum != 3) &&
						  (aaruler_selectedButNum != 5) && (aaruler_selectedButNum != 7)))
		{
			var number = num + 1;
			var buttonId = "aaruler" + number + "+";
			var button = window.${workspace_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton highlight";
		}
	}

	// Unhighlights aaruler button "num"
	// aaruler_selectedButNum works like ions_selectedButNum.  See above.
	function aaruler_but_unhighlight(num) {
		if(((num == 0) && (aaruler_selectedButNum != 4) && (aaruler_selectedButNum != 5) &&
						  (aaruler_selectedButNum != 6) && (aaruler_selectedButNum != 7)) ||
		   ((num == 1) && (aaruler_selectedButNum != 2) && (aaruler_selectedButNum != 3) &&
						  (aaruler_selectedButNum != 6) && (aaruler_selectedButNum != 7)) ||
		   ((num == 2) && (aaruler_selectedButNum != 1) && (aaruler_selectedButNum != 3) &&
						  (aaruler_selectedButNum != 5) && (aaruler_selectedButNum != 7)))
		{
			var number = num + 1;
			var buttonId = "aaruler" + number + "+";
			var button = window.${workspace_fname}.document.getElementById(buttonId);
			button.className = "fuzzybutton darkblu";
		}
	}


	// Highlights show button "num"
	// show_selectedButNum works like ions_selectedButNum.  See above.
	function show_highlight(num) {
		if(((num == 0) && (show_selectedButNum != 4) && (show_selectedButNum != 5) &&
						  (show_selectedButNum != 6) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 12) && (show_selectedButNum != 13) &&						  
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)) ||
		   ((num == 1) && (show_selectedButNum != 2) && (show_selectedButNum != 3) &&
						  (show_selectedButNum != 6) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 10) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)) ||
		   ((num == 2) && (show_selectedButNum != 1) && (show_selectedButNum != 3) &&
						  (show_selectedButNum != 5) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 9) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 13) && (show_selectedButNum != 15)) ||
		   ((num == 3) && (show_selectedButNum != 8) && (show_selectedButNum != 9) &&
						  (show_selectedButNum != 10) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 12) && (show_selectedButNum != 13) &&
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)))
		{
			var button = window.${workspace_fname}.document.getElementById(getshowid(num));
			button.className = "fuzzybutton highlight";
		}
	}		

	// Unhighlights show button "num"
	// show_selectedButNum works like ions_selectedButNum.  See above.
	function show_unhighlight(num) {
		if(((num == 0) && (show_selectedButNum != 4) && (show_selectedButNum != 5) &&
						  (show_selectedButNum != 6) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 12) && (show_selectedButNum != 13) &&						  
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)) ||
		   ((num == 1) && (show_selectedButNum != 2) && (show_selectedButNum != 3) &&
						  (show_selectedButNum != 6) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 10) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)) ||
		   ((num == 2) && (show_selectedButNum != 1) && (show_selectedButNum != 3) &&
						  (show_selectedButNum != 5) && (show_selectedButNum != 7) &&
						  (show_selectedButNum != 9) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 13) && (show_selectedButNum != 15)) ||
		   ((num == 3) && (show_selectedButNum != 8) && (show_selectedButNum != 9) &&
						  (show_selectedButNum != 10) && (show_selectedButNum != 11) &&
						  (show_selectedButNum != 12) && (show_selectedButNum != 13) &&
						  (show_selectedButNum != 14) && (show_selectedButNum != 15)))
		{
			var button = window.${workspace_fname}.document.getElementById(getshowid(num));
			button.className = "fuzzybutton midblu";
		
		}
	}

	function getshowid(num) {
		if (num == 0) {
			return "ion_a";
		}
		else if (num == 1) {
			return "ion_b";
		}
		else if (num == 2){
			return "ion_y";
		}
		else if (num == 3){
			return "abpair";
		}
	}

/*************************************************************************************************/
// COMMUNICATE

	// This function connects the forms in the different frames to each other.  It is called after
	// most button clicks and value changes and such.
	function communicate() {
		var maindoc = window.${main_fname}.document.mainform;
		var headerdoc = window.${header_fname}.document;
		var workspacedoc = window.${workspace_fname}.document;

		maindoc.seqlink.value =				workspacedoc.workspaceform.seqlink.value;		
		maindoc.aions.value =				workspacedoc.workspaceform.aions.value;		
		maindoc.doublycharged.value =		workspacedoc.workspaceform.doublycharged.value;		
		maindoc.triplycharged.value =		workspacedoc.workspaceform.triplycharged.value;		
		maindoc.quadruplycharged.value =	workspacedoc.workspaceform.quadruplycharged.value;		
		maindoc.ladders.value =				workspacedoc.workspaceform.ladders.value;		
		maindoc.ladders2.value =			workspacedoc.workspaceform.ladders2.value;		
		maindoc.ladders3.value =			workspacedoc.workspaceform.ladders3.value;		
		maindoc.ion_to_jump_to.value =		workspacedoc.workspaceform.ion_to_jump_to.value;		
		maindoc.massmin.value =				workspacedoc.workspaceform.massmin.value;		
		maindoc.massmax.value =				workspacedoc.workspaceform.massmax.value;
		maindoc.customminormass.value =		workspacedoc.workspaceform.customminormass.value;
		maindoc.expand_space.value =		workspacedoc.workspaceform.expand_space.value;
		maindoc.MassType.value =			workspacedoc.workspaceform.MassType.value;
		maindoc.interior_ions.value =		workspacedoc.workspaceform.interior_ions.value;
		maindoc.interior_ions_on.value =	workspacedoc.workspaceform.interior_ions_on.value;
		maindoc.tolerance.value =			workspacedoc.workspaceform.tolerance.value;
		maindoc.Ctermspace.value =			headerdoc.headerform.Ctermspace.value;		
		maindoc.Ntermspace.value =			headerdoc.headerform.Ntermspace.value;		
		maindoc.NumAxis.value =				headerdoc.headerform.NumAxis.value;
		maindoc.Total_MHplus.value =		headerdoc.headerform.Total_MHplus.value;
		maindoc.MassJ.value =				headerdoc.headerform.MassJ.value;
		maindoc.cys_alkyl.value =			workspacedoc.workspaceform.cys_alkyl[workspacedoc.workspaceform.cys_alkyl.selectedIndex].value;

		if (workspacedoc.workspaceform.minor_ions.value == "1") {
			maindoc.minor_ions.value = "1";
			maindoc.whichminor.value = workspacedoc.workspaceform.whichminor[workspacedoc.workspaceform.whichminor.selectedIndex].value;
		} else {
			maindoc.minor_ions.value = "";
		}

		maindoc.$initial_mpc_alts[0].value = headerdoc.headerform.$initial_mpc_alts[0].value;
		maindoc.$initial_mpc_alts[1].value = headerdoc.headerform.$initial_mpc_alts[1].value;
	}

/*************************************************************************************************/
// EVENT HANDLERS
	
	// This function handles the clicking of the main image.
	// It determines the position of the mouse click relative to the top left of the main image.
	// Then it passes that onto fuzzycore.exe.
	function handle_image_click() {
		var evt = window.$main_fname.event;
		var the_form = window.${main_fname}.document.mainform;

		communicate();
		the_form.x.value = evt.offsetX;
		the_form.y.value = evt.offsetY;
		
		the_form.submit();
		return;
	}

	function leftui_handle(num) {
		var workspaceform = window.${workspace_fname}.document.workspaceform;
		var mainform = window.${main_fname}.document.mainform;

		if (num == 1) {
			leftui_but_invert(num);
			if (workspaceform.minor_ions.value != "") {
				workspaceform.minor_ions.value = mainform.minor_ions.value = "";
			} else {
				workspaceform.minor_ions.value = mainform.minor_ions.value = "1";
			}
			log_handle();
		} else if (num == 2) {
			mass_handle();
		} else if (num == 3) {
			window.${workspace_fname}.document.all.advanced.style.visibility  = "visible";
			window.${workspace_fname}.document.all.regular.style.visibility  = "hidden";
		} else if (num == 4) {
			leftui_but_invert(num);
			if (workspaceform.interior_ions_on.value != "") {
				workspaceform.interior_ions_on.value = mainform.minor_ions.value = "";
			} else {
				workspaceform.interior_ions_on.value = mainform.minor_ions.value = "1";
			}
		} else if (num == 6) {
			window.${workspace_fname}.document.all.customminordiv.style.visibility  = "hidden";
		} else if (num == 10) {
			mzhandle();
		} else if (num == 11) {
			window.${workspace_fname}.document.all.regular.style.visibility  = "visible";
			window.${workspace_fname}.document.all.advanced.style.visibility  = "hidden";
		}

		if (num > 3) {
			communicate();
			parent.${main_fname}.document.mainform.submit();
		}
	}

	// Put letter in Ctermspace or Ntermspace depending on the status of the side_to_walk radio buttons and
	// submit the main form.
	function lcd_handle(letter) {
		if (letter == "...") {
			if (window.${header_fname}.document.all.massjdiv.style.visibility == "visible") {
				window.${header_fname}.document.all.massjdiv.style.visibility = "hidden";
			} else {
				window.${header_fname}.document.all.massjdiv.style.visibility = "visible";
			}
			return;
		}

		if(window.${header_fname}.document.headerform.side_to_walk[0].checked) {
			window.${header_fname}.document.headerform.Ntermspace.value += letter;
		}
		else {
			window.${header_fname}.document.headerform.Ctermspace.value = letter + window.${header_fname}.document.headerform.Ctermspace.value;
		}
		communicate();

		window.${main_fname}.document.mainform.submit();
	}

	// Update colours of lcd buttons according the the data in matchArray.
	function refreshButs() {

EOF

for($i = 0; $i < 24; $i++) {
		print qq (		window.$header_fname.document.all.lcdbut$i.className = buttonArray[match($i)];\n);
}

print <<EOF;
		window.$header_fname.document.all.mpcbut0.className = mpcArray[mpcmatch(0)];
		window.$header_fname.document.all.mpcbut1.className = mpcArray[mpcmatch(1)];
	}


	// Do NCBI blast search.
	function do_blast() {
		var i, opt, choice, newurl;

		if (window.${workspace_fname}.document.workspaceform.seqlink.value == "nrblast") {
			newurl = "$remoteblast?$sequence_param=" + blastSeq + "&$db_prg_aa_aa_nr&$expect&$word_size_aa&$defaultblastoptions";
		}
		else if (window.${workspace_fname}.document.workspaceform.seqlink.value == "estblast") {
			newurl = "$remoteblast?$sequence_param=" + blastSeq + "&$db_prg_aa_nuc_dbest&$expect&$word_size_nuc&$defaultblastoptions";
		}
		else {
			newurl = "$gap_binary?type_of_query1=0&peptide1=" + blastSeq;
		}
		window.open(newurl,'mywindow'+$NCBIsuffix+windowcount);
		windowcount++;
	}

	// Handles the pressing of Msx and PO4 and those buttons.  Lord knows why they're called MPCs.
	function mpc_handle(num) {
		var the_form = window.$main_fname.document.mainform;
		var butfield = eval("window.$header_fname.document.headerform." + mpcNames[num]);
		
		if(butfield.value == "") {
			butfield.value = "true";
		}
		else {
			butfield.value = "";
		}		
		communicate();
		the_form.submit();
	}

	function getridofdialogs() {
		window.${header_fname}.document.all.massjdiv.style.visibility = "hidden";
/*
		window.${workspace_fname}.document.all.regular.style.visibility  = "visible";
		window.${workspace_fname}.document.all.advanced.style.visibility  = "hidden";
//		window.${workspace_fname}.document.all.customminordiv.style.visibility  = "hidden";
*/
	}

	// Changes the MHplus.  Used to hold onto the first MHplus value without opening the dta file (as the C code
	// is already mucking about in there).
	function assertMHplus(MHplus) {
		window.${header_fname}.document.headerform.Total_MHplus.value = MHplus;
		window.${header_fname}.document.headerform.Total_MHplus.defaultValue = MHplus;
		if (!realMHplus) {
			realMHplus = MHplus;
		}
	}
	
	// Changes the max and min.
	function assertminmaxmass(manmin, manmax, automin, automax) {
		window.${workspace_fname}.document.all.massmin.value = manmin;
		window.${workspace_fname}.document.all.massmax.value = manmax;
		window.${workspace_fname}.document.all.massmin_span.innerHTML = automin;
		window.${workspace_fname}.document.all.massmax_span.innerHTML = automax;
		if (parent.${main_fname}.document.mainform.mzman.value == 1) {
			window.${workspace_fname}.document.all.mzman.style.visibility =  "";
			window.${workspace_fname}.document.all.mzauto.style.visibility = "hidden";
		} else {
			window.${workspace_fname}.document.all.mzauto.style.visibility = "";
			window.${workspace_fname}.document.all.mzman.style.visibility =  "hidden";
		}
	}
	
	// Tells the appropriate axis button to be depressed. <snicker>
	// As far as I can tell, this is only used by axis_click_handle.
	// I would remove it, but that would involve recompiling the C code.  -- BLG 5/7/02
	function assert_axis(num) {
		if(selectedButNum != num) {
			axis_but_revert(selectedButNum);
			axis_but_invert(num);
			selectedButNum = num;

			window.${header_fname}.document.headerform.NumAxis.value = num + 1;
		}
	}

	// Handles clicking of an axis button--or rather, tells fuzzycore.exe to handle it...
	function axis_click_handle(num) {		
		if(selectedButNum != num) {
			assert_axis(num);
			communicate();		
			window.${main_fname}.document.mainform.submit();
		}
	}

	// Shows the three Sps.
	function setscore(seqSp, optSp, allSp) {
		window.${workspace_fname}.document.all.seqscore.innerHTML = seqSp;
		window.${workspace_fname}.document.all.optscore.innerHTML = optSp;
		window.${workspace_fname}.document.all.allscore.innerHTML = allSp;
	}

	// Pop up the Sp in a new window.
	function displayscore(which) {
		var theform = window.${main_fname}.document.mainform;
		var oldtarget = theform.target;
		communicate();
		theform.target = "_blank";
		theform.displayscore.value = which;
		theform.submit();
		theform.displayscore.value = "";
		theform.target = oldtarget;
	}

	// Change the MH+ by the chargestate.
	function changeMHplus(new_z) {
		var newMHplus = (realMHplus - $Mono_mass{"Hydrogen"}) / $z;
		newMHplus = newMHplus * new_z + $Mono_mass{"Hydrogen"};
		window.${header_fname}.document.headerform.Total_MHplus.value = newMHplus;
		window.${header_fname}.document.all.z.innerText = new_z;
		communicate();		
		window.${main_fname}.document.mainform.submit();
	}

	// Run sequest and incorporate the results into the page.
	function runsequest() {
		communicate();
		var theform = window.${main_fname}.document.mainform;
		var oldtarget = theform.target;
		var oldaction = theform.action;

		theform.target = "$perl_fname";
		theform.action = "$ourname";
		theform.runsequest.value = "1";
		theform.submit();

		theform.runsequest.value = "";
		theform.action = oldaction;
		theform.target = oldtarget;
		setTimeout("next_submit();", 100);

	}

	// Javascript undo--cheap!
	function undo() {
		window.$exe_fname.history.back();
	}
	
	// Change the focus to the log window.
	function focus_log_window(dest) {
		if(!logWindowUp) {
			logWindow = window.open(dest, "viewLog");
			logWindowUp = true;
		}
		if(logWindow.closed) {
			logWindow = window.open(dest, "viewLog");
		}
		logWindow.focus();
	}

	// Refresh the log window.
	function refresh_log_window() {
		if(logWindowUp) {
			if(!logWindow.closed) {
				logWindow.location.reload(true);
			}
		}
	}

	// Updates most of the links in the main document. In Navigator the main image is a link,
	// while in explorer it is not, so the appropriate link count is hard coded into link_start.
	// Not that we support Navigator *at all*, but whatever.
	function update_links(massType, seq, massC, prettySeq, viewlogLink, zoomLink) {
		var java = /javascript/;
		var dtabuffer = "?Dta=" + escape(dtafile);
		var scratch;

		scratch = dtabuffer + "&NumAxis=1&MassType=" + escape(massType) + "&Pep=" + escape(seq) + "&MassC=" + escape(massC);
		fullviewurl = fullviewbinary + scratch;
		ionlisturl = ionlistbinary + scratch;
		scratchurl = scratchpadbinary + dtabuffer + "&Pep=" + escape(seq) + "&PrettySeq=" + escape(prettySeq);
		controlurl = dtacontrolbinary + "?dtafile=" + escape(dtafile);

		if(viewlogLink == "alert") {
			viewlogrun = "parent.alert('There are no log entries');";
		} else {
			viewlogrun = "parent.focus_log_window('" + viewlogLink + "');";
		}

		if(zoomLink == "alert") {
			zoomrun = "parent.alert('No ztas to zoom on');";
		} else {
			zoomrun = "parent.open('" + zoombinary + "?Dta=" + escape(zoomLink) + "');";
		}

	}

	// Go ahead onto the next page.
	function next_submit() {
		communicate();
		window.${main_fname}.document.mainform.submit();
	}
		  

	// Handles sending the sequence to NCBI's blast.
	function send_sequence_handle(num) {
		if (num == 0) {
			parent.${workspace_fname}.document.workspaceform.seqlink.value = "nrblast";
		} else if (num == 1) {
			parent.${workspace_fname}.document.workspaceform.seqlink.value = "estblast";
		} else {
			parent.${workspace_fname}.document.workspaceform.seqlink.value = "gapblast";
		}
		communicate();
		do_blast();
		parent.mainFrame.document.mainform.submit();
	}


	// Handles clicking on the aaruler buttons.  See above for info on aaruler_selectedButNum.
	function aaruler_handle(num) {
		
		if (num == 0) {
  			if (parent.${workspace_fname}.document.workspaceform.ladders.value == "checked") {
  				parent.${workspace_fname}.document.workspaceform.ladders.value = "";
				aaruler_selectedButNum -= 4;
			} else {
				parent.${workspace_fname}.document.workspaceform.ladders.value = "checked";
				aaruler_selectedButNum += 4;
			}
  		} else if (num == 1) {
  			if (parent.${workspace_fname}.document.workspaceform.ladders2.value == "checked") {
  				parent.${workspace_fname}.document.workspaceform.ladders2.value = "";
				aaruler_selectedButNum -= 2;
			} else {
				parent.${workspace_fname}.document.workspaceform.ladders2.value = "checked";
				aaruler_selectedButNum += 2;
			}
  		} else {
  			if (parent.${workspace_fname}.document.workspaceform.ladders3.value == "checked") {
  				parent.${workspace_fname}.document.workspaceform.ladders3.value = "";
				aaruler_selectedButNum -= 1;
			} else {
				parent.${workspace_fname}.document.workspaceform.ladders3.value = "checked";
				aaruler_selectedButNum += 1;
			}
  		}	
		communicate();
		var number = num + 1;
		var buttonId = "aaruler" + number + "+";
		var button = window.${workspace_fname}.document.getElementById(buttonId);

		if (button.className == "fuzzybutton darkblu-inverted") {
			button.className = "fuzzybutton darkblu";
		} else {
			button.className = "fuzzybutton darkblu-inverted";
		}
		parent.mainFrame.document.mainform.submit();
  	}


	// Handles clicking on the show buttons.  See above for info on show_selectedButNum.
  	function show_handle(num) {	
		var buttonId;
		if (num == 0) {
			buttonId = "ion_a";
  			if (parent.${workspace_fname}.document.workspaceform.aions.value == "checked") {
				parent.${workspace_fname}.document.workspaceform.aions.value = "";
				show_selectedButNum -= 4;
			} else {
				parent.${workspace_fname}.document.workspaceform.aions.value = "checked";
				show_selectedButNum += 4;
			}
		} else if (num == 1) {
			buttonId = "ion_b";
			if (parent.${workspace_fname}.document.workspaceform.bions.value == "checked") {
  				if (parent.${workspace_fname}.document.workspaceform.yions.value == "checked") {  			
					parent.${workspace_fname}.document.workspaceform.bions.value = "";			
					show_selectedButNum -= 2;
				} else {
					return;
					window.${workspace_fname}.document.all.ion_b.className = "fuzzybutton midblu";
					parent.${workspace_fname}.document.workspaceform.yions.value = "checked";
					window.${workspace_fname}.document.all.ion_y.className = "fuzzybutton midblu";
					show_selectedButNum += 1;
				}
			} else {
					parent.${workspace_fname}.document.workspaceform.bions.value = "checked";			
					show_selectedButNum += 2;
				}
		} else if (num == 2) {
			buttonId = "ion_y";
  			if (parent.${workspace_fname}.document.workspaceform.yions.value == "checked") {
				if (parent.${workspace_fname}.document.workspaceform.bions.value == "checked") {
					parent.${workspace_fname}.document.workspaceform.yions.value = "";
					show_selectedButNum -= 1;
				} else {
					return;
					window.${workspace_fname}.document.all.ion_y.className = "fuzzybutton midblu";
					parent.${workspace_fname}.document.workspaceform.bions.value = "checked";
					window.${workspace_fname}.document.all.ion_b.className = "fuzzybutton midblu";
					show_selectedButNum += 2;
				}
			} else {
				parent.${workspace_fname}.document.workspaceform.yions.value = "checked";
				show_selectedButNum += 1;
			}
		} else {
			buttonId = "abpair";
  			if (parent.${workspace_fname}.document.workspaceform.abpair.value == "1") {
				parent.${workspace_fname}.document.workspaceform.abpair.value = "0";
				show_selectedButNum -= 8;
			} else {
				parent.${workspace_fname}.document.workspaceform.abpair.value = "1";
				show_selectedButNum += 8;
			}
		}
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		if (button.className == "fuzzybutton midblu-inverted") {
			button.className = "fuzzybutton midblu";
		} else {
			button.className = "fuzzybutton midblu-inverted";
		}
		communicate();		
		window.${main_fname}.document.mainform.aions.value = parent.${workspace_fname}.document.workspaceform.aions.value;
		window.${main_fname}.document.mainform.bions.value = parent.${workspace_fname}.document.workspaceform.bions.value;
		window.${main_fname}.document.mainform.yions.value = parent.${workspace_fname}.document.workspaceform.yions.value;
		window.${main_fname}.document.mainform.abpair.value = parent.${workspace_fname}.document.workspaceform.abpair.value;
		parent.mainFrame.document.mainform.submit();
  	}

	// Handles clicking on the ion buttons.  See above for info on ions_selectedButNum.
  	function ion_handle(num) {				
		if (num == 0) {
  			if (parent.${workspace_fname}.document.workspaceform.doublycharged.value == "checked") {
				parent.${workspace_fname}.document.workspaceform.doublycharged.value = "";
				ions_selectedButNum -= 1;
			} else {
				parent.${workspace_fname}.document.workspaceform.doublycharged.value = "checked";
				ions_selectedButNum += 1;
			}
		} else if (num == 1) {
  			if (parent.${workspace_fname}.document.workspaceform.triplycharged.value == "checked") {
				parent.${workspace_fname}.document.workspaceform.triplycharged.value = "";			
				ions_selectedButNum -= 2;
			} else {
				parent.${workspace_fname}.document.workspaceform.triplycharged.value = "checked";			
				ions_selectedButNum += 2;
			}
		} else {
  			if (parent.${workspace_fname}.document.workspaceform.quadruplycharged.value == "checked") {
				parent.${workspace_fname}.document.workspaceform.quadruplycharged.value = "";
				ions_selectedButNum -= 4;
			} else {
				parent.${workspace_fname}.document.workspaceform.quadruplycharged.value = "checked";
				ions_selectedButNum += 4;
			}
		}
		var number = num +2;
		var buttonId = "ions" + number + "+";
		var button = window.${workspace_fname}.document.getElementById(buttonId);
		if (button.className == "fuzzybutton midblu-inverted") {
			button.className = "fuzzybutton midblu";
		} else {
			button.className = "fuzzybutton midblu-inverted";
		}
		communicate();		
		window.${main_fname}.document.mainform.doublycharged.value = parent.${workspace_fname}.document.workspaceform.doublycharged.value;
		window.${main_fname}.document.mainform.triplycharged.value = parent.${workspace_fname}.document.workspaceform.triplycharged.value;
		window.${main_fname}.document.mainform.quadruplycharged.value = parent.${workspace_fname}.document.workspaceform.quadruplycharged.value;
		parent.mainFrame.document.mainform.submit();
  	}

	// Handles clicking on the mark next buttons.  See above for info on next_selectedButNum.
  	function mark_next_handle(num) {
  		next_but_revert(next_selectedButNum);
		next_selectedButNum = num;
		
		if (num == 0) {
  			parent.${workspace_fname}.document.workspaceform.ion_to_jump_to.value = "special";
			window.${workspace_fname}.document.all.nextspecial.className = "fuzzybutton midblu-inverted";
			window.${workspace_fname}.document.all.nextb.className = "fuzzybutton midblu";
			window.${workspace_fname}.document.all.nexty.className = "fuzzybutton midblu";
  		} else if (num == 1) {
  			parent.${workspace_fname}.document.workspaceform.ion_to_jump_to.value = "B";
			window.${workspace_fname}.document.all.nextb.className = "fuzzybutton midblu-inverted";
 			window.${workspace_fname}.document.all.nextspecial.className = "fuzzybutton midblu";
 			window.${workspace_fname}.document.all.nexty.className = "fuzzybutton midblu";
 		} else {
  			parent.${workspace_fname}.document.workspaceform.ion_to_jump_to.value = "Y";
			window.${workspace_fname}.document.all.nexty.className = "fuzzybutton midblu-inverted";
 			window.${workspace_fname}.document.all.nextspecial.className = "fuzzybutton midblu";
 			window.${workspace_fname}.document.all.nextb.className = "fuzzybutton midblu";
		}
		window.${main_fname}.document.mainform.ion_to_jump_to.value = parent.${workspace_fname}.document.workspaceform.ion_to_jump_to.value;
  	}

	// Handles changing the side which we're adding amino acids to from the H2N to COOH or reverse.
	function side_to_walk(num) {
		communicate();
		if (num == 0) {
			parent.${header_fname}.document.headerform.side_to_walk.value = "Nterm";
		} else {
			parent.${header_fname}.document.headerform.side_to_walk.value = "Cterm";
		}
		parent.${main_fname}.document.mainform.side_to_walk.value = parent.${header_fname}.document.headerform.side_to_walk.value;
		
		window.${main_fname}.document.mainform.submit();	
	}

	// Handles clicking the Mono/Avg button.
	function mass_handle() {
		communicate();
		if (window.${workspace_fname}.document.workspaceform.MassType.value == 0) {
			window.${workspace_fname}.document.workspaceform.MassType.value = window.${main_fname}.document.mainform.MassType.value = 1;
			window.${workspace_fname}.document.all.leftui2.innerText = "Mono";
		} else {
			window.${workspace_fname}.document.workspaceform.MassType.value = window.${main_fname}.document.mainform.MassType.value = 0;
			window.${workspace_fname}.document.all.leftui2.innerText = "Avg";
		}
		parent.mainFrame.document.mainform.submit();
	}

	// Handles clicking of the m/z button.
	function mzhandle() {
		communicate();
		if (parent.${main_fname}.document.mainform.mzman.value == 1) {
			parent.${main_fname}.document.mainform.mzman.value = 0;
			window.${workspace_fname}.document.all.leftui10.innerText = "Auto";
		} else {
			parent.${main_fname}.document.mainform.mzman.value = 1;
			window.${workspace_fname}.document.all.leftui10.innerText = "Man";
		}
		parent.mainFrame.document.mainform.submit();
	}

	// This function submits the form for a wide variety of different form elements.
	function log_handle() {
		var myform  = window.${workspace_fname}.document.workspaceform;
		var mydiv   = window.${workspace_fname}.document.all.customminordiv;
		if ((myform.whichminor.selectedIndex == 7) && (myform.minor_ions.value == "1")) {
			mydiv.style.visibility  = "visible";
		} else {
			mydiv.style.visibility  = "hidden";
		}
		communicate();
		parent.mainFrame.document.mainform.submit();
	}

	// Handles pressing the set mass button when a custom minor is selected.
	function setminormass_handle() {
		window.${workspace_fname}.document.all.customminordiv_hides.style.visibility='visible';
		window.${workspace_fname}.document.all.customminordiv.style.visibility='hidden';
		communicate();
		parent.mainFrame.document.mainform.submit();
	}

	// Handles pressing the set j mass button.
	function setmassj_handle() {
		window.${header_fname}.document.all.massjdiv.style.visibility = 'hidden';
		var jbut = window.${header_fname}.document.all.lcdbut22;
		if (window.${header_fname}.document.headerform.MassJ.value > 0) {
			jbut.className = "fuzzybutton blu";
			jbut.style.width = "20";
			jbut.style.height = "20";
			jbut.innerHTML = "J";
			communicate();
			parent.mainFrame.document.mainform.submit();
		} else {
			jbut.className = "";
			jbut.style.width = "0";
			jbut.style.height = "0";
			jbut.innerHTML = "";
		}
	}

	// Pops up the gd copyright window.
	function copyright_popup() {

		var cWindow;
		
		cWindow = open("","cWindow","width=350,height=50");
		cWindow.document.open();
		cWindow.document.writeln('<HTML>');
		cWindow.document.writeln('<HEAD><TITLE>Copyright Information</TITLE>$stylesheet_javascript</HEAD>');
		cWindow.document.writeln('<BODY BGCOLOR=#FFFFFF>');
		cWindow.document.writeln('<CENTER><span class=normaltext>');
		cWindow.document.writeln('Uses <a href="http://www.boutell.com/gd/" target="_blank">gd 1.2</a> &#169; 1994, 1995, Quest Protein Database Center, Cold Spring Harbor Labs.');
		cWindow.document.writeln('</span></CENTER>');
		cWindow.document.writeln('</BODY>');
		cWindow.document.writeln('</HTML>');
	}

/*************************************************************************************************/

EOF

&create_frame_javascript();

print <<EOF;
//-->
</script>
</head>
EOF
}

###################################################################################################
##PERLDOC##
# Function : load_buttons
# Descript : prints the html that loads the main amino buttons into buttonArray
# Notes    : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub load_buttons {

$i = 0;

foreach $colEng (@coloursEnglish) {
	print qq|	buttonArray[$i] = "fuzzybutton $colEng"; \n|;
	$i++;


}

$i = 0;

foreach $col (@mpc_colours) {
	print qq|	mpcArray[$i] = "fuzzybutton $col"; \n|;
	$i++;
	print qq|	mpcArray[$i] = "fuzzybutton ${col}-inverted"; \n|;
	$i++;


}

}


###################################################################################################
##PERLDOC##
# Function : create_frame_javascript
# Descript : writes perl that writes javascript that writes html
# Notes    : Needed so that we don't have to keep track of all of the frames 
#			 in separate html files.
#			 Uses a really tricky foreach to write the functions for the pages--
#			 check out the Perl and then the JS and then the HTML!
#			 Calls create_frame_strings.
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub create_frame_javascript {

print <<EOF;

// Return a blank page
function blank() {
	return "<HTML></HTML>";
}

EOF

&create_frame_strings();

foreach $frame ("header", "workspace", "main", "bottom", "empty") {
	$framePage = $frame . "Page";
	$framestring = $frame . "string";
	$frameframe = $frame . "frame";

	print qq|// Return the $frame page \n|;
	print qq|function $framePage() { \n|;
	print qq|	$framestring = ""; \n|;

	$$frameframe =~ s/\"/\\\"/g;

	foreach $line (split /\n/, $$frameframe) {
		print qq|$framestring += "$line\\n"; \n|;
	}

	print qq|	return $framestring;\n|;
	print qq|}\n\n|;

}

}

###################################################################################################
##PERLDOC##
# Function : create_frame_strings
# Descript : writes the html for the various frames into variables,
#			 which are mucked about with in create_frame_javascript
# Notes    : calls add_buttons_to_header_frame
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub create_frame_strings {

###################################################################################################
# print out headerframe

$headerframe .= <<EOF;
<html>
<head>
<title>FuzzyIons</title>
<link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
<link rel="stylesheet" type="text/css" href="$stylesheet_IE">
$fuzzy_buts
</head>

<body bgcolor="$white">
<FORM NAME="headerform" ACTION="$fuzzy_source" TARGET="$exe_fname" METHOD=GET onSubmit="parent.main_submit_handle()">
<TABLE VALIGN=TOP BORDER=0 CELLPADDING=0 CELLSPACING=0>
<TR>
<TD rowspan=2 VALIGN=middle ALIGN=center NOWRAP width=217>
<img src="$webimagedir/FuzzyIons2.gif">&nbsp;</TD>
<TD align=center NOWRAP><span class=smallheading>H<SUB>2</SUB>N</span><INPUT TYPE=RADIO NAME="side_to_walk" VALUE="Nterm" $Nterm_box onClick="javascript:parent.side_to_walk(0)"><INPUT NAME="Ntermspace" VALUE="$Ntermspace" SIZE=33><INPUT NAME="Ctermspace" VALUE="$Ctermspace" SIZE=33 STYLE="text-align: right;"><INPUT TYPE=RADIO NAME="side_to_walk" VALUE="Cterm" $Cterm_box onClick="javascript:parent.side_to_walk(1)"><span class=smallheading>COOH</span></TD>
<TD align=right NOWRAP>
&nbsp;&nbsp;
<span class=smallheading>MH<span style="font-size:10pt"><sup>+</sup></span>:</span><INPUT NAME="Total_MHplus" SIZE=6 VALUE="$Total_MHplus">
&nbsp;&nbsp;
<span class=smallheading>z: </span><span id="z" class="smallheading">$z</span>
&nbsp;&nbsp;
<INPUT TYPE=HIDDEN NAME="NumAxis" VALUE="1">
<INPUT TYPE=HIDDEN NAME="x" VALUE="">
<INPUT TYPE=HIDDEN NAME="y" VALUE="">
<INPUT TYPE=HIDDEN NAME="aions" VALUE="$aions"> 
<INPUT TYPE=HIDDEN NAME="doublycharged" VALUE="">
<INPUT TYPE=HIDDEN NAME="triplycharged" VALUE="">
<INPUT TYPE=HIDDEN NAME="seqlink" VALUE="nrblast">
</TD>
<TD>&nbsp;</TD>
</TR>
<TR><TD colspan=10>
EOF

&add_buttons_to_headerframe();

$headerframe .= <<EOF;
<DIV ID="massjdiv" CLASS="smallheading" STYLE="position:absolute; left:680px; top: 0px; vertical-align: middle; whitespace: nowrap; background-color:#ffffff; layer-background-color:#ffffff; border:solid 1px #ffffff; visibility: hidden;">
<SPAN STYLE="vertical-align: middle;">
	&nbsp;&nbsp;&nbsp;
	Set up misc. amino acid ("J") with mass:
</SPAN><SPAN STYLE="vertical-align: middle;">
	<INPUT SYLE="position:absolute; left:0px; top:0px;" NAME="MassJ" VALUE="0.0" SIZE=5>
</SPAN><SPAN STYLE="vertical-align: middle;">
	<SPAN SYLE="position:absolute; left:47px; top:0px;" ID="setmassj" title="set j mass" class="fuzzybutton darkblu" style="width:15; height:20;" onmouseover="this.className='fuzzybutton highlight'" 
		onmouseout="this.className='fuzzybutton darkblu'" onclick="parent.setmassj_handle();">Set</span>
	&nbsp;&nbsp;&nbsp;
</SPAN></DIV>
</FORM>

</BODY>
</HTML>

EOF

#######################################################################################
# print out workspace frame

# Decide whether various buttons are inverted or not.
my $invertlosses =		($minor_ions ?					"-inverted" : "");
my $invertintions =		($interior_ions_on ?			"-inverted" : "");

my $invertaaone =		($ladders ?						"-inverted" : "");
my $invertaatwo =		($ladders2 ?					"-inverted" : "");
my $invertaathree =		($ladders3 ?					"-inverted" : "");

my $invertaions =		($aions ?						"-inverted" : "");
my $invertbions =		($bions ?						"-inverted" : "");
my $invertyions =		($yions ?						"-inverted" : "");

my $invertabpair =		($abpair ?						"-inverted" : "");
my $invertdoubly = 		($doublycharged ?				"-inverted" : "");
my $inverttriply =		($triplycharged ?				"-inverted" : "");
my $invertquadruply =	($quadruplycharged ?			"-inverted" : "");

my $invertnextzoom =	($ion_to_jump_to eq "special" ?	"-inverted" : "");
my $invertnextb =		($ion_to_jump_to eq "B" ?		"-inverted" : "");
my $invertnexty =		($ion_to_jump_to eq "Y" ?		"-inverted" : "");

# The C prime select box.
my $cprimeselectboxoptions;
foreach ("free", "CM", "CAM", "PE", "CAP", "PA") {
	$cprimeselectboxoptions .= qq(<OPTION VALUE="$_");
	if ($_ eq $cys_alkyl) {
		$cprimeselectboxoptions .= " SELECTED";
	}
	$cprimeselectboxoptions .= qq(>$_);
}

# The minor ions select box.
my $minorionsselectboxoptions;
%whichminors = ("water" => "H2O", "doublewater" => "2H2O", "ammonia" => "NH3", "doubleammonia" => "2NH3", 
				"hypophosphite80" => "HPO3", "phosphate98" => "H3PO4", "msx" => "Msx", "custom" => "custom");
foreach ("water", "doublewater", "ammonia", "doubleammonia", "hypophosphite80", "phosphate98", "msx", "custom") {
	$minorionsselectboxoptions .= qq(<OPTION VALUE="$_");
	if ($_ eq $whichminor) {
		$minorionsselectboxoptions  .= " SELECTED";
	}
	$minorionsselectboxoptions .= qq(>$whichminors{$_}\n);
}

$workspaceframe .= <<EOF;
<html>
<head>
<title>FuzzyIons</title>
<script language="JavaScript" src="/js/proteinmenus.js"></script>
<link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
<link rel="stylesheet" type="text/css" href="/incdir/intrachem_theme.css">
<link rel="stylesheet" type="text/css" href="$stylesheet_IE">
$fuzzy_buts
</head>

<body bgcolor="$white">
<FORM NAME="workspaceform" ACTION="$fuzzy_source" TARGET="$exe_fname" METHOD=GET>
<center>
<TABLE WIDTH=210 BORDER=1 BORDERCOLOR="black" CELLPADDING=1 CELLSPACING=0>
<TR ALIGN=CENTER VALIGN=MIDDLE>
<TD COLSPAN=5 NOWRAP>
	<center>
	<span class=link style="cursor:hand" onclick="parent.open('/intrachem.html');">&nbsp;Home&nbsp;&nbsp;&nbsp;</span>
	<span class=link style="cursor:default" onmouseover="openmenu = 'viewmenu'; showProteinMenu('viewmenu', 0)" onmouseout="hideProteinMenu()">&nbsp;View&nbsp;&nbsp;&nbsp;</span>
	<span class=link style="cursor:default" onmouseover="openmenu = 'appsmenu'; showProteinMenu('appsmenu', 0)" onmouseout="hideProteinMenu()">&nbsp;Apps&nbsp;&nbsp;&nbsp;</span>
	<span class=link style="cursor:default" onmouseover="openmenu = 'blastmenu'; showProteinMenu('blastmenu', 0)" onmouseout="hideProteinMenu()">&nbsp;Blast&nbsp;&nbsp;</span>
	</center>
	<div id="viewmenu" onmouseout="hideProteinMenu()" maxheight=83 style="position:absolute; width:82; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.fullviewurl);" onmouseover="openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Full View</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.ionlisturl);" onmouseover="openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">List View</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.qtercoolurl);" onmouseover="openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Qcool</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.scratchurl)" onmouseover="openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">ScratchPad</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.eval(parent.zoomrun);" onmouseover="openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Zoom View</span><br>
	</div>
	<div id="appsmenu" onmouseout="hideProteinMenu()" maxheight=100 style="position:absolute; width:82; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onmouseover="showProteinMenu('MHplussubmenu', 'appsmenu'); openmenu = 'viewmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Change MH+</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open('$webcgi/aacombos.pl');" onmouseover="openmenu = 'appsmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Combos</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.controlurl)" onmouseover="openmenu = 'appsmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Control</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.send_sequence_handle(2);" onmouseover="openmenu = 'appsmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Gap</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open(parent.muquesturl);" onmouseover="openmenu = 'appsmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">MuQuest</span><br>
		<span class=actbutton style="width:80; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.runsequest()" onmouseover="openmenu = 'appsmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Sequest</span><br>
	</div>
	<div id="blastmenu" onmouseout="hideProteinMenu()" maxheight=50 style="position:absolute; width:52; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.send_sequence_handle(0);" onmouseover="openmenu = 'blastmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">NR</span><br>
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.send_sequence_handle(1);" onmouseover="openmenu = 'blastmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">EST</span><br>
		<span class=actbutton style="width:50; text-align:left; padding-left:3px" onclick="hideProteinMenu(); parent.open('http://www.ncbi.nlm.nih.gov/BLAST/');" onmouseover="openmenu = 'blastmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">Blast</span>
	</div>
	<div id="MHplussubmenu" onmouseout="hideProteinMenu()" onclick="hideProteinMenu()" maxheight=100 style="position:absolute; width:27; height:1; overflow:hidden; visibility:hidden; border:solid #0000cc 1px; background-color:#ffffff">
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(1);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">1+</span><br>
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(2);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">2+</span><br>
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(3);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">3+</span><br>
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(4);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">4+</span><br>
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(5);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">5+</span><br>
		<span class=actbutton style="width:25; text-align:left; padding-left:3px" onclick="parent.changeMHplus(6);" onmouseover="openmenu = 'MHplussubmenu'; this.className='actbuttonover';" onmouseout="this.className='actbutton';" onmousedown="this.className='actbuttondown';" onmouseup="this.className='actbuttonover';" onselectstart="return false">6+</span><br>
	</div>
</TD>
</TR>
</TABLE>

<TABLE WIDTH=210 BORDER=2 BORDERCOLOR="black" CELLPADDING=0 CELLSPACING=0>
<TR>
<TD align=right BGCOLOR="$white"><span class=smallheading>Show:</span></TD>
	
<TD><span id="ion_a" title="Show a Ions" class="fuzzybutton midblu$invertaions" style="width:20; height:20;" onMouseOver="parent.show_highlight(0); return parent.setMsg('show: a')"
		onMouseOut="parent.show_unhighlight(0); return parent.setMsg('')" onclick="javascript:parent.show_handle(0)">a</span>
</td>

<TD><span id="ion_b" title="Show b Ions" class="fuzzybutton midblu$invertbions" style="width:20; height:20;" onMouseOver="parent.show_highlight(1); return parent.setMsg('show: b')"
		onMouseOut="parent.show_unhighlight(1); return parent.setMsg('')" onclick="javascript:parent.show_handle(1)">b</span>
</td>

<TD><span id="ion_y" title="Show y Ions" class="fuzzybutton midblu$invertyions" style="width:20; height:20;"  onMouseOver="parent.show_highlight(2); return parent.setMsg('show: y')"
		onMouseOut="parent.show_unhighlight(2); return parent.setMsg('')" onclick="javascript:parent.show_handle(2)">y</span>
</td>

<TD><span id="abpair" title="Turn off a/b pairs" class="fuzzybutton midblu$invertabpair" style="width:25; height:20;" onMouseOver="parent.show_highlight(3); return parent.setMsg('Mark: abpair')"
		onMouseOut="parent.show_unhighlight(3); return parent.setMsg('')" onclick="javascript:parent.show_handle(3)">a/b</span>
</td>
<TD><span id="ions2+" title="Show 2+ Ions" class="fuzzybutton midblu$invertdoubly" style="width:20; height:20;" onMouseOver="parent.ions_but_highlight(0); return parent.setMsg('Ions: 2+')"
		onMouseOut="parent.ions_but_unhighlight(0); return parent.setMsg('')" onclick="javascript:parent.ion_handle(0)">2+</span>
</td>
<TD><span id="ions3+" title="Show 3+ Ions" class="fuzzybutton midblu$inverttriply" style="width:20; height:20;" onMouseOver="parent.ions_but_highlight(1); return parent.setMsg('Ions: 3+')"
		onMouseOut="parent.ions_but_unhighlight(1); return parent.setMsg('')" onclick="javascript:parent.ion_handle(1)">3+</span>
</td>	

<TD><span id="ions4+" title="Show 4+ Ions" class="fuzzybutton midblu$invertquadruply" style="width:20; height:20;" onMouseOver="parent.ions_but_highlight(2); return parent.setMsg('Ions: 4+')"
		onMouseOut="parent.ions_but_unhighlight(2); return parent.setMsg('')" onclick="javascript:parent.ion_handle(2)">4+</span>
</td>	
	
</TR><TR>
<TD align=right BGCOLOR="$white"><span class=smallheading>Mark:</span></TD>

<TD><span id="nextspecial" title="Mark Zoom" class="fuzzybutton midblu$invertnextzoom" style="width:20; height:20;" onMouseOver="parent.next_but_highlight(0); return parent.setMsg('Mark: Zoom')"
		onMouseOut="parent.next_but_unhighlight(0); return parent.setMsg('')" onclick="javascript:parent.mark_next_handle(0)"><></span>
</td>	

<TD><span id="nextb" title="Mark Next B" class="fuzzybutton midblu$invertnextb"	style="width:20; height:20;" onMouseOver="parent.next_but_highlight(1); return parent.setMsg('Mark: Next B')"
		onMouseOut="parent.next_but_unhighlight(1); return parent.setMsg('')" onclick="javascript:parent.mark_next_handle(1)">b</span>
</td>	

<TD><span id="nexty" title="Mark Next Y" class="fuzzybutton midblu$invertnexty" style="width:20; height:20;" onMouseOver="parent.next_but_highlight(2); return parent.setMsg('Mark: Next Y')"
		onMouseOut="parent.next_but_unhighlight(2); return parent.setMsg('')" onclick="javascript:parent.mark_next_handle(2)">y</span>
</td>	
	
<TD align=right BGCOLOR="$white"><span class=smallheading>Ruler:</span></TD>

<TD><span id="aaruler1+" title="1+ AA ruler" class="fuzzybutton darkblu$invertaaone" style="width:20; height:20;" onMouseOver="parent.aaruler_but_highlight(0); return parent.setMsg('AA Ruler: 1+')"
		onMouseOut="parent.aaruler_but_unhighlight(0); return parent.setMsg('')" onclick="javascript:parent.aaruler_handle(0)">1+</span>
</td>

<TD><span id="aaruler2+" title="2+ AA ruler" class="fuzzybutton darkblu$invertaatwo" style="width:20; height:20;" onMouseOver="parent.aaruler_but_highlight(1); return parent.setMsg('AA Ruler: 2+')"
		onMouseOut="parent.aaruler_but_unhighlight(1); return parent.setMsg('')" onclick="javascript:parent.aaruler_handle(1)">2+</span>
</td>

<TD><span id="aaruler3+" title="3+ AA ruler" class="fuzzybutton darkblu$invertaathree" style="width:20; height:20;" onMouseOver="parent.aaruler_but_highlight(2); return parent.setMsg('AA Ruler: 3+')"
		onMouseOut="parent.aaruler_but_unhighlight(2); return parent.setMsg('')" onclick="javascript:parent.aaruler_handle(2)">3+</span>
</td>
</tr></TABLE>

<tt style="text-align: center; font-size:9pt;" ID="sequenceText">---</tt>

<HR STYLE="height: 1px; border-style: none;">

<TABLE CELLSPACING=0 CELLPADDING=0>
<TR><TD ALIGN=RIGHT>
	<span class=smallheading><nobr>Seq Sp:&nbsp;</nobr></span>
</TD><TD ALIGN=RIGHT>	
	<A HREF='javascript:parent.displayscore(1);'>
	<span class=smalltext ID="seqscore">0</span>
	</A>
</TD>
	<TD ROWSPAN=3 WIDTH="15%">&nbsp;</TD>
<TD ALIGN=RIGHT>
	<span class=smallheading>Ions:&nbsp;</span>
</TD><TD><nobr>
	<span class=smalltext ID="ions"></span>
</nobr></TD></TR>
<TR><TD ALIGN=RIGHT>
	<span class=smallheading><nobr>Opt Sp:&nbsp;</nobr></span>
</TD><TD ALIGN=RIGHT>	
	<A HREF='javascript:parent.displayscore(2);'>
	<span class=smalltext ID="optscore">0</span>
	</A>
</TD><TD ALIGN=RIGHT>
	<span class=smallheading>Leng:&nbsp;</span>
</TD><TD><nobr>
	<span class=smalltext ID="lengthText">0</span>
</nobr></TD></TR>
<TR><TD ALIGN=RIGHT>
	<span class=smallheading><nobr>Full Sp:&nbsp;</nobr></span>
</TD><TD ALIGN=RIGHT>
	<A HREF='javascript:parent.displayscore(3);'>
	<span class=smalltext ID="allscore">0</span>
	</A>
</TD><TD ALIGN=RIGHT>
	<span class=smallheading>Rem:&nbsp;</span>
</TD><TD>	
	<span class=smalltext ID="remainingText"></span>
</TD></TR></TABLE>

<HR STYLE="height: 1px; border-style: none;">

<span id="advanced" style="position: absolute; visibility: hidden;">
<TABLE CELLSPACING=0 CELLPADDING=2 WIDTH=200 BORDER=0>
<TR><TD WIDTH=35>
<span id="leftui10" title="Set limits to automatic or manual" class="littlefuzzybutton blu smallheading" 
onMouseOver="parent.leftui_but_highlight(10); return parent.setMsg('Set limits to automatic or manual')"
onMouseOut="parent.leftui_but_unhighlight(10); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(10)"
style="width:35; height:20;">Auto</span>
</TD><TD VALIGN="middle">
<span id="mzauto" CLASS="smallheading" STYLE="position: absolute; top: 4;">
<span id="massmin_span">$massmin</span> - <span id="massmax_span">$massmax</span>
</span>
<span id="mzman" CLASS="smalltext" STYLE="white-space: nowrap; visibility: hidden;">
<INPUT CLASS="smalltext" TYPE=TEXT SIZE=3 LENGTH=7 NAME="massmin" VALUE="$massmin"> -
<INPUT CLASS="smalltext" TYPE=TEXT SIZE=6 LENGTH=7 NAME="massmax" VALUE="$massmax">&nbsp;
</span>
</TD><TD ALIGN=RIGHT>
<span id="leftui11" title="Advanced options" class="littlefuzzybutton blu smallheading" 
onMouseOver="parent.leftui_but_highlight(11); return parent.setMsg('Advanced options')"
onMouseOut="parent.leftui_but_unhighlight(11); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(11)"
style="width:35; height:20;">Back</span>
</TD></TR>
<TR><TD COLSPAN=3 CLASS="smallheading" STYLE="white-space: nowrap;">
	Mark zoom amount:
	<INPUT NAME="expand_space" CLASS="smalltext" VALUE="$expand_space" SIZE=2 MAXLENGTH=3>
	<span class=smallheading>&plusmn;</span><INPUT TYPE=TEXT CLASS="smalltext" SIZE=3 LENGTH=7 NAME="tolerance" VALUE="$tolerance">
</TD></TR>
</TABLE>
</span>

<span id="regular" style="visibility: visible;">
<TABLE WIDTH=200>
<TR><TD ALIGN=RIGHT>
<span id="leftui1" title="Turn losses on or off" class="littlefuzzybutton blu$invertlosses smallheading" 
onMouseOver="parent.leftui_but_highlight(1); return parent.setMsg('Turn losses on or off')"
onMouseOut="parent.leftui_but_unhighlight(1); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(1)"
style="width:35; height:20;">NL:</span>
</TD><TD NOWRAP COLSPAN=3>
<TABLE WIDTH="100%" CELLSPACING=0 CELLPADDING=0><TR><TD NOWRAP>
<SELECT CLASS="smalltext" STYLE="height:20;" NAME="whichminor" onChange="if (minor_ions.value == '1') javascript:parent.log_handle()">
$minorionsselectboxoptions
</SELECT>
&nbsp;&nbsp;
</TD><TD NOWRAP ALIGN=RIGHT>
<span id="leftui2" title="Set mass to mono or average" class="littlefuzzybutton blu smallheading" 
onMouseOver="parent.leftui_but_highlight(2); return parent.setMsg('Set mass to mono or average')"
onMouseOut="parent.leftui_but_unhighlight(2); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(2)"
style="width:35; height:20;">Mono</span>
<span id="leftui3" title="Advanced options" class="littlefuzzybutton blu smallheading" 
onMouseOver="parent.leftui_but_highlight(3); return parent.setMsg('Advanced options')"
onMouseOut="parent.leftui_but_unhighlight(3); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(3)"
style="width:35; height:20;">Adv</span>
</TD></TR></TABLE>
</TD></TR>
<TR><TD ALIGN=RIGHT NOWRAP>
<span id="leftui4" title="Turn interior ions on or off" class="littlefuzzybutton blu$invertintions smallheading" 
onMouseOver="parent.leftui_but_highlight(4); return parent.setMsg('Turn interior ions on or off')"
onMouseOut="parent.leftui_but_unhighlight(4); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(4)"
style="width:35; height:20;">Int:</span>
</TD><TD>
<INPUT CLASS=smalltext TYPE=TEXT SIZE=7 MAXLENGTH=30 NAME="interior_ions" VALUE="$interior_ions">
</TD><TD ALIGN=MIDDLE NOWRAP>
<A CLASS=smalltext HREF="javascript:parent.copyright_popup();">gd &copy</A>
</TD><TD ALIGN=RIGHT NOWRAP>
<span class=smallheading>C':</span>
<SELECT CLASS=smalltext NAME="cys_alkyl" onChange="javascript:parent.log_handle()">
$cprimeselectboxoptions
</SELECT>
</TD></TR>
<TR HEIGHT="7"><TD><SPAN STYLE="font-size: 1pt;">&nbsp;</SPAN></TD></TR>
</TABLE>
</span>

<div class="smalltext" style="color: blue;">$dtafilename</div>

<HR STYLE="height: 1px; border-style: none;">

<INPUT TYPE=HIDDEN NAME="browser" VALUE="IE">
<INPUT TYPE=HIDDEN NAME="interior_ions_on" VALUE="$interior_ions_on">
<INPUT TYPE=HIDDEN NAME="minor_ions" VALUE="$minor_ions">
<INPUT TYPE=HIDDEN NAME="MassType" VALUE="1">
<INPUT TYPE=HIDDEN NAME="abpair" VALUE="$abpair">
<INPUT TYPE=HIDDEN NAME="abthresh" VALUE="$abthresh">
<INPUT TYPE=HIDDEN NAME="penaltydiv" VALUE="$penaltydiv">
<INPUT TYPE=HIDDEN NAME="lossesdiv" VALUE="$lossesdiv">
<INPUT TYPE=HIDDEN NAME="aions" VALUE="$aions">
<INPUT TYPE=HIDDEN NAME="bions" VALUE="$bions">
<INPUT TYPE=HIDDEN NAME="yions" VALUE="$yions">
<INPUT TYPE=HIDDEN NAME="doublycharged" VALUE="$doublycharged">
<INPUT TYPE=HIDDEN NAME="triplycharged" VALUE="$triplycharged">
<INPUT TYPE=HIDDEN NAME="quadruplycharged" VALUE="$quadruplycharged">
<INPUT TYPE=HIDDEN NAME="NumAxis" VALUE="1">
<INPUT TYPE=HIDDEN NAME="Ctermspace" VALUE="$Ctermspace">
<INPUT TYPE=HIDDEN NAME="Ntermspace" VALUE="$Ntermspace">
<INPUT TYPE=HIDDEN NAME="seqlink" VALUE="nrblast">
<INPUT TYPE=HIDDEN NAME="ladders" VALUE="$ladders">
<INPUT TYPE=HIDDEN NAME="ladders2" VALUE="$ladders2">
<INPUT TYPE=HIDDEN NAME="ladders3" VALUE="$ladders3">
<INPUT TYPE=HIDDEN NAME="ion_to_jump_to" VALUE="Y">
</CENTER>
<DIV ID="customminordiv" CLASS="smalltext" STYLE="position:absolute; top: 215px; left:82px; white-space: nowrap; background-color:#ffffff; layer-background-color:#ffffff; border:solid 1px #ffffff; visibility: hidden;">
<span style="height: 20px;">
<INPUT CLASS=smalltext NAME="customminormass" VALUE="0.0" SIZE=5>&nbsp;
</span><span id="leftui6" title="Set custom loss mass" class="littlefuzzybutton blu$invertintions smallheading" 
onMouseOver="parent.leftui_but_highlight(6); return parent.setMsg('Set custom loss mass')"
onMouseOut="parent.leftui_but_unhighlight(6); return parent.setMsg('')"
onclick="javascript:parent.leftui_handle(6)"
style="width:75; height:20;">Set Loss Mass</span>
</DIV>

</FORM>
</BODY>
</HTML>

EOF

###################################################################################################
# print out bottom frame

$bottomframe .= <<EOF;
<html>
<head>
<title>FuzzyIons</title>
<link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
<LINK REL="stylesheet" TYPE="text/css" HREF="$stylesheet_IE">
</head>
<body bgcolor="$white">
<form name="bottomform">
<center>
<DIV CLASS=smalltext ID="bottomText"></DIV>
</center>
</form>
</BODY>
</HTML>
EOF

###################################################################################################
# print out main frame

$mainframe .= <<EOF;
<html>
<head>
<title>FuzzyIons</title>
<link rel="stylesheet" type="text/css" href="/incdir/intrachem.css">
<link rel="stylesheet" type="text/css" href="$stylesheet_IE">
$fuzzy_buts
</head>

<body bgcolor="#eeeeee">
	<FORM NAME="mainform" ACTION="$fuzzy_source" TARGET="$exe_fname" METHOD=GET>
	<IMG NAME="mainImage" SRC="" ALT="mass spectrum" WIDTH=785 HEIGHT=543 BORDER=2 BORDERCOLOR="black"
	onClick="parent.handle_image_click()"
	onMouseOver="return parent.setMsg('Select Ion')" 
	onMouseOut="return parent.setMsg('')"><BR>

<TABLE BORDER=1 BORDERCOLOR="black" WIDTH="789">
<TR><TD BGCOLOR="#FFFFFF"><span class=smallheading>&nbsp;Initials: <INPUT NAME="username" VALUE="$username" SIZE=4 MAXLENGTH=8>
</span></TD>
<TD BGCOLOR="#FFFFFF"><span class=smallheading>&nbsp;Comments: <INPUT MAXLENGTH=250  SIZE=50 NAME="comments" VALUE="$comments"></span></TD>
<TD BGCOLOR="#FFFFFF" align=center><INPUT TYPE=submit NAME="APPEND_TO_FILE"  title="Log Interpretation" class="fuzzybutton darkblu" style="height:20;width=120" value="Log Interpretation"
onMouseOver="return parent.setMsg('Append Interpretation to Log')" onMouseOut="return parent.setMsg('')" onClick="parent.log_handle();"></TD>
<TD BGCOLOR="#FFFFFF" align=center><INPUT TYPE=submit NAME="VIEW_LOG"  title="View Log" class="fuzzybutton darkblu" style="height:20;width=60" value="View Log"
onMouseOver="return parent.setMsg('View the Log')" onMouseOut="return parent.setMsg('')" onClick="parent.eval(parent.viewlogrun);"></TD>

<INPUT TYPE=HIDDEN NAME="Dta" VALUE="$dtafile">
<INPUT TYPE=HIDDEN NAME="seqlink" VALUE="">
<INPUT TYPE=HIDDEN NAME="aions" VALUE="$aions">
<INPUT TYPE=HIDDEN NAME="bions" VALUE="$bions">
<INPUT TYPE=HIDDEN NAME="yions" VALUE="$yions">
<INPUT TYPE=HIDDEN NAME="doublycharged" VALUE="$doublycharged">
<INPUT TYPE=HIDDEN NAME="triplycharged" VALUE="$triplycharged">
<INPUT TYPE=HIDDEN NAME="quadruplycharged" VALUE="$quadruplycharged">
<INPUT TYPE=HIDDEN NAME="ladders" VALUE="$ladders">
<INPUT TYPE=HIDDEN NAME="ladders2" VALUE="$ladders2">
<INPUT TYPE=HIDDEN NAME="ladders3" VALUE="$ladders3">
<INPUT TYPE=HIDDEN NAME="ion_to_jump_to" VALUE="$ion_to_jump_to">
<INPUT TYPE=HIDDEN NAME="side_to_walk" VALUE="$side_to_walk">
<INPUT TYPE=HIDDEN NAME="Ctermspace" VALUE="$Ctermspace">
<INPUT TYPE=HIDDEN NAME="Ntermspace" VALUE="$Ntermspace">
<INPUT TYPE=HIDDEN NAME="minor_ions" VALUE="$minorions">
<INPUT TYPE=HIDDEN NAME="whichminor" VALUE="$whichminor">
<INPUT TYPE=HIDDEN NAME="cys_alkyl" VALUE="$cysalkyl">
<INPUT TYPE=HIDDEN NAME="interior_ions_on" VALUE="$interior_ions_on">
<INPUT TYPE=HIDDEN NAME="interior_ions" VALUE="$interior_ions">
<INPUT TYPE=HIDDEN NAME="expand_space" VALUE="$expand_space">
<INPUT TYPE=HIDDEN NAME="tolerance" VALUE="$tolerance">
<INPUT TYPE=HIDDEN NAME="MassType" VALUE="$MassType">
<INPUT TYPE=HIDDEN NAME="NumAxis" VALUE="$numaxis">
<INPUT TYPE=HIDDEN NAME="notfirst" VALUE="true">
<INPUT TYPE=HIDDEN NAME="layerone" VALUE="">
<INPUT TYPE=HIDDEN NAME="layertwo" VALUE="">
<INPUT TYPE=HIDDEN NAME="x" VALUE="">
<INPUT TYPE=HIDDEN NAME="y" VALUE="">
<INPUT TYPE=HIDDEN NAME="progname" VALUE="$our_source">
<INPUT TYPE=HIDDEN NAME="Total_MHplus" VALUE="$Total_MHplus">
<INPUT TYPE=HIDDEN NAME="abpair" VALUE="$abpair">
<INPUT TYPE=HIDDEN NAME="abthresh" VALUE="$abthresh">
<INPUT TYPE=HIDDEN NAME="penaltydiv" VALUE="$penaltydiv">
<INPUT TYPE=HIDDEN NAME="lossesdiv" VALUE="$lossesdiv">
<INPUT TYPE=HIDDEN NAME="massmin" VALUE="$massmin">
<INPUT TYPE=HIDDEN NAME="massmax" VALUE="$massmax">
<INPUT TYPE=HIDDEN NAME="mzman" VALUE="$mzman">
<INPUT TYPE=HIDDEN NAME="MassJ" VALUE="$massj">
<INPUT TYPE=HIDDEN NAME="customminormass" VALUE="$customminormass">
<INPUT TYPE=HIDDEN NAME="$initial_mpc_alts[0]" VALUE="">
<INPUT TYPE=HIDDEN NAME="$initial_mpc_alts[1]" VALUE="">
<INPUT TYPE=HIDDEN NAME="displayscore" VALUE="">
<INPUT TYPE=HIDDEN NAME="runsequest" VALUE="">
</TABLE></TD></TR>
</TABLE>
</FORM>
</body>
</html>
EOF

###################################################################################################
# print out an empty frame

$emptyframe .= <<EOF;
<html>
<head>
<title>FuzzyIons</title>
</head>

<body bgcolor="#ffffff">
</body>
</html>
EOF

}

###################################################################################################
##PERLDOC##
# Function : add_buttons_to_headerframe
# Descript : writes the html for the many headerframe buttons
# Notes    : called by create_frame_strings
# Argument : no arguments or returns; probably bunches of globals
##ENDPERLDOC##

sub add_buttons_to_headerframe {

my $massimage = ($MassType == 0 ? "Avg" : "Mono");

$headerframe .= <<EOF;
<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 ALIGN=LEFT>
<TR>
EOF

$headerframe .= <<EOF;
	<TD width=15>&nbsp;</TD>
	<TD BGCOLOR="$white">
		<span id="NumAxis0" class="fuzzybutton lightblu-inverted" style="width:20; height:20;" onmouseover="parent.axis_but_highlight(0);return parent.setMsg('Display on 1 Axis')" 
			onmouseout="parent.axis_but_unhighlight(0);return parent.setMsg('')" onclick="javascript:parent.axis_click_handle(0)">1</span>
	</td>
EOF

for($i = 1; $i < 5; $i++) { 
	$j = $i + 1;
	$headerframe .= <<EOF;
	<TD BGCOLOR="$white">
		<span id="NumAxis$i" class="fuzzybutton lightblu" style="width:20; height:20;" onmouseover="parent.axis_but_highlight($i);return parent.setMsg('Display on $j Axis')" 
			onmouseout="parent.axis_but_unhighlight($i);return parent.setMsg('')" onclick="javascript:parent.axis_click_handle($i)">$j</span>
	</td>
EOF
}

$headerframe .= <<EOF;
	<TD width=75>&nbsp;</TD>
	<TD BGCOLOR="$white">
		<span class="fuzzybutton darkblu" style="width:40; height:20;" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('Next Step')"  
			onmouseout="this.className='fuzzybutton darkblu';return parent.setMsg('')" onclick="javascript:parent.next_submit()">Next</span>
	</TD>	
	<TD BGCOLOR="$white">
		<span class="fuzzybutton darkblu" style="width:40; height:20;" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('Undo last step')"  
			onmouseout="this.className='fuzzybutton darkblu';return parent.setMsg('')" onclick="javascript:parent.undo()">Undo</span>
		<input type=hidden name="undobut"></td>
EOF

$i = 0;
foreach $amino (@letters)  {
	# If it's Cp or Cpp, we just want to use C in the handling and the Next Step hover.  Else, use the amino acid letter.
	my $tempamino = ($amino =~ /^Cp/ ? "C" : $amino);
	if ($amino eq "Cp") {
		$aminotext = "C\'";
	} elsif ($amino eq "Cpp") {
		$aminotext = "C\"";
	} else {
		$aminotext = $amino;
	}

	unless ($amino eq "J") {
		$headerframe .= <<EOF;
		<TD BGCOLOR="$white">
			<span id="lcdbut$i" class="fuzzybutton blu" style="width:20; height:20;" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('${tempamino} Next Step')"
				onmouseout="javascript:parent.lcd_but_unhighlight($i);return parent.setMsg('')" onclick="javascript:parent.lcd_handle('${tempamino}')">$aminotext</span>
		</td>
EOF
	} else {
		my $j = $i + 1;
		$headerframe .= <<EOF;
		<TD BGCOLOR="$white"><NOBR>
			<span id="jdiv"><span id="lcdbut$i" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('J Next Step (use ... button to set J mass)')"
				onmouseout="javascript:parent.lcd_but_unhighlight($i);return parent.setMsg('')" onclick="javascript:parent.lcd_handle('J')"></span>
			<span id="lcdbut$j" class="fuzzybutton blu" style="width:20; height:20;" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('Set up misc. amino acid')"
				onmouseout="javascript:parent.lcd_but_unhighlight($j);return parent.setMsg('')" onclick="javascript:parent.lcd_handle('...')">...</span>
			</span>
		</NOBR></td>
EOF
	}
	$i++;
}

$i = 0;
foreach $src (@mpcs) {

		$headerframe .= <<EOF;
		<TD BGCOLOR="$white">
		<span id="mpcbut$i" class="fuzzybutton blu" style="width:40; height:20;" onmouseover="this.className='fuzzybutton highlight';return parent.setMsg('Show $src')" 
			onmouseout="javascript:parent.mpc_but_unhighlight($i);return parent.setMsg('')" onclick="javascript:parent.mpc_handle($i)">$src</span>
		<input type=hidden name="$initial_mpc_alts[$i]"></td>
EOF

	$i++;
}
	
$headerframe .= <<EOF;
	<TD width=20></TD>
	<TD BGCOLOR="$white">
		&nbsp;
	</TD>
</TR></TABLE></TD>
</TR></TABLE>
EOF

}

###################################################################################################
##PERLDOC##
# Function : error
# Argument : the error encountered
# Returns  : doesn't return; exits
# Descript : the stereotypical error routine
# Notes    : only called if the dta cannot be found
##ENDPERLDOC##
sub error {

	print <<EOF;
Content-type: text/html

<html>
<head>
<title>FuzzyIons</title>
</head>
<body>
<B>Error:</B> @_<BR>
</body>
</html>
EOF

	exit;

}

sub runsequest {

	# Get the important variables.
	
	my $dtafile = $FORM{"Dta"} || $FORM{"dtafile"};	# the name of the data file -- backwards compatible
	$dtafile =~ s|\S%3A%2FSequest|$seqdir|;			# Hack the file name to the correct place, from above
	$dtafile =~ s|\S:/Sequest|$seqdir|;

	my $dtaname;
	($ignore, $dtaname) = split /$seqdir/, $dtafile;
	($dtaname, $ignore) = split /.dta/, $dtaname;
	($ignore, $dtaname) = split /^\/.*\//, $dtaname;

	$dtafile =~ m!.*[\\/](.*)[\\/]+!;
	my $directory = $1;

	my $dtafilename = $dtaname . ".dta";

	# Create our sequence, and then look through it for mods, recording them and removing them.

	my $sequence = $FORM{"Ntermspace"} . $FORM{"Ctermspace"};
	my %mods, $modlist;

	while ($sequence =~ s/([A-Z]?)\[(.*?)\]/$1/) {
		$mods{$1} = $2;
		$modlist .= $1;
	}
	
	$sequence =~ s/\[.*?\]//g;

	(my $newdtaname = $dtaname) =~ s/^.*?\.//;
	$newdtaname = $sequence . "tmp." . $newdtaname;

	# Copy the DTA and create the fasta and params files.  The fasta contains Nterm + Cterm.
	# The params file (called fuzzy.params) is a copy of the default fuzzy.params file, with 
	# only the mods changed.

	my $dir = "$seqdir/$directory";
	chdir($dir);
	&copyfiles ($dtafilename, "$newdtaname.dta");

	open (FASTA, ">fuzzy.fasta");
	print FASTA ">$sequence from fuzzy\n$sequence\n\n";
	close FASTA;

	open PARAMSIN,  "<$etcdir/fuzzy.params";
	open PARAMSOUT, ">$dir/fuzzy.params";

	while (<PARAMSIN>) {
		my $line = $_;
		# Look for the diff_search_options line...
		if (m/^diff_search_options/) {
			# ... and rewrite it.
			$line = "diff_search_options =";
			my $count = 6;
			while ($modlist) {
				# Put all of the mods in.
				$modlist =~ s/^(.)//;
				my $mod = $1;
				$line .= " " . sprintf("%.4f", $mods{$mod}) . " $mod";
				$count--;
			}
			# We want to put a minimum of 6 mods in.
			if ($count > 0) { $line .= (" 0.000 X" x $count); }
			$line .= "\n";
		}
#	Will need to copy $modlist for this to run properly.  Doesn't seem to be needed, though.
#		if (m/^add_([A-Z])_/) {
#			my $mod = $1;
#			if ($modlist =~ m/$mod/) {
#				$line =~ m/^(\D*)[\d\.]*(.*)$/;
#				$line = $1 . sprintf("%.4f", $mods{$mod}) . $2 ."\n";
#			} else {
#				$line =~ m/^(\D*)[\d\.]*(.*)$/;
#				$line = $1 . "0.0000" . $2 ."\n";
#			}
#		}
		print PARAMSOUT $line;
	}

	close PARAMSIN;
	close PARAMSOUT;

	# Run sequest!  $jsline allows us to alert if there's been a problem.

	my $procobj = &run_in_background("$sequest -D$dir/fuzzy.fasta -Pfuzzy.params $newdtaname.dta");

	if ($procobj) {
		$procobj->SetPriorityClass(IDLE_PRIORITY_CLASS);
		until ($procobj->Wait(1000)) {
			# This is to prevent infinite loops.  "last" exits out of the loop.
			$uhoh++;
			if ($uhoh > 10000) { last; }
		}
		$jsline = qq|window.open("$webcgi/showout.pl?OutFile=| . &url_encode("$dir/$newdtaname.out") . 
													"&dbdir=" . &url_encode("$dbdir") . qq|", "");|;
	} else {
		$jsline = qq|parent.alert("Failed to launch Sequest.");|;
	}

print <<EOF;
Content-type: text/html

<html>
<title>FuzzyIons</title>
<script language="Javascript">
<!--

$jsline

//-->
</script>
</head>
<body>
</body>
</html>
EOF

# And delete the files.
unlink "fuzzy.params";
unlink "fuzzy.fasta";

exit(0);

}