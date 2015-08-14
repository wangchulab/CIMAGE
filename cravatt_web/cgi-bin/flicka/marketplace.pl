#!/usr/local/bin/perl

#-------------------------------------
#	Marketplace,
#	(C)1999 Harvard University
#	
#	C. J. Taubman/W. S. Lane/M. A. Baker
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
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
 
&cgi_receive;

$dif_tolerance = 1.0;

&MS_pages_header ("Marketplace", "#F74F78");

print "<P><HR><P>\n";

$dirname = $FORM{"directory"};

&setup_js;
&output_form;
&tail;
exit;

#
# Setup the javascript function that handles calling the utility
#
sub setup_js {
print <<FORMPAGE;
<SCRIPT LANGUAGE="Javascript">
<!--

function launchUtil(utilName, utilOptions)
{
// utilName -- the name of the utility to be called
// utilOptions -- any other options other than the directory to be specified

var selected = document.forms[0].directory.options.selectedIndex;
var gotoDir = document.forms[0].directory.options[selected].value;
var gotoURL = utilName + "?directory=" + gotoDir + utilOptions;

location.href=gotoURL;
}

//-->
</SCRIPT>
FORMPAGE
}

sub output_form {
 ##
 ## subroutine from microchem_include.pl
 ## that gets all the directory information
 ##
  &get_alldirs;
$launch = qq(\"javascript:launchUtil\(\');
$normal = qq(\', \'\'\)\">);
print <<EOF;

<center>
<FORM ACTION="$ourname" METHOD=POST>
<TABLE ALIGN=center CELLPADDING=0 CELLSPACING=0 BORDER=0>
<TR align=center>

<TD width=225 height=100 valign=bottom ALIGN=right NOWRAP>
<a HREF=${launch}fuzzylauncher.pl${normal}
<img border=0 src="$webimagedir/marketplace/banana.gif">
<span class=smallheading> Fuzzylauncher</span></a><br>
<img border=0 src="$webimagedir/marketplace/arrowupleft.gif">

<TD valign=bottom width=225 height=100>
<a HREF=${launch}runsummary.pl${normal}
<img border=0 src="$webimagedir/marketplace/pineapple.gif"><br>
<span class=smallheading>Sequest Summary</span></a><br>
<img border=0 src="$webimagedir/marketplace/arrowup.gif">

<TD valign=bottom width=225 height=100>
<a HREF=${launch}sequest_launcher.pl${normal}
<img border=0 src="$webimagedir/marketplace/apple.gif"><br>
<span class=smallheading>Sequest Launcher</span></a><br>
<img border=0 src="$webimagedir/marketplace/arrowup.gif">

<TD valign=bottom align=left width=225 height=100>
<a HREF=${launch}dta_chromatogram.pl\', \'&labels=checked&show=show\')\")>
<span class=smallheading>DTA Chromatogram </span>
<img border=0 src="$webimagedir/marketplace/cherries.gif" width=50 height=50></a><br>
<img border=0 src="$webimagedir/marketplace/arrowupright.gif">

<TR><TD align=right width=225 height=100>
<a HREF=${launch}neutral_loss_finder.pl${normal}
<img border=0 src="$webimagedir/marketplace/france.gif" width=50 height=50>
<span class=smallheading>Neutral Loss Finder</span></a>
<img border=0 src="$webimagedir/marketplace/arrowleft.gif">

<TD align=center COLSPAN=2 ROWSPAN=3>
<b>Choose a directory:</b><br>
<span class=dropbox><SELECT name=\"directory\">\n
EOF

 foreach $directory (@ordered_names) {
	if ($directory eq $dirname) {
	    $selected = "SELECTED";
	}
	else {
	    $selected = "";
	}
		print "<OPTION VALUE = \"$directory\" $selected>$fancyname{$directory}\n";
 }

print <<EOF;
</span><br>
<table><img border=0 src="$webimagedir/marketplace/cornucopia.gif"></table>
</TD>

<TD width=225 height=100>
<img border=0 src="$webimagedir/marketplace/arrowright.gif">
<a HREF=${launch}create_dta.pl${normal}
<span class=smallheading>Create-DTA</span> 
<img border=0 src="$webimagedir/marketplace/peppers.gif" width=75 height=50>

<TR><TD align=right width=225 height=100>
<a HREF=${launch}inspector.pl${normal}
<img border=0 src="$webimagedir/marketplace/wine.gif" width=35 height=75>
<span class=smallheading> Inspector</span>
<img border=0 src="$webimagedir/marketplace/arrowleft.gif">

<TD width=225 height=100>
<img border=0 src="$webimagedir/marketplace/arrowright.gif">
<span class=smallheading><a HREF=${launch}deleteadir.pl${normal}
Sim Dir <img border=0 src="$webimagedir/marketplace/basket.gif"></a></span>

<TR><TD align=right width=225 height=100>
<a HREF=${launch}difbrowser.pl${normal}
<img border=0 src="$webimagedir/marketplace/mushrooms.gif" width=50 height=50>
<span class=smallheading> Difbrowser</span>
<img border=0 src="$webimagedir/marketplace/arrowleft.gif">

<TD width=225 height=100>
<img border=0 src="$webimagedir/marketplace/arrowright.gif">
<a HREF=${launch}dta_banisher.pl${normal}
<span class=smallheading>DTA Banisher </span>
<img border=0 src="$webimagedir/marketplace/squash.gif" width=50 height=50>

<TR><TD align=right valign=top width=225 height=100>
<img border=0 src="$webimagedir/marketplace/arrowdownleft.gif"><br>
<a HREF=${launch}view_info.pl${normal}
<img border=0 src="$webimagedir/marketplace/broccoli.gif" width=50 height=50>
<span class=smallheading> View Info</span>

<TD valign=top align=center width=225 height=100><br><br>
<img border=0 src="$webimagedir/marketplace/arrowdown.gif"><br>
<a HREF=${launch}q-cool.pl${normal}
<span class=smallheading>Q-Cool</span><br>
<img border=0 src="$webimagedir/marketplace/cauliflower.gif" width=50 height=50>

<TD valign=top align=center width=225 height=100><br><br>
<img border=0 src="$webimagedir/marketplace/arrowdown.gif"><br>
<a HREF=${launch}masslist.pl${normal}
<span class=smallheading>Masslist</span><br>
<img border=0 src="$webimagedir/marketplace/orange.gif" width=75 height=50>

<TD valign=top align=left width=225 height=100>
<img border=0 src="$webimagedir/marketplace/arrowdownright.gif"><br>
<a HREF=${launch}dta_vcr.pl${normal}
<span class=smallheading>DTA VCR </span>
<img border=0 src="$webimagedir/marketplace/corn.gif" width=50 height=50></a>
</FORM>
</TABLE>
EOF

}

sub tail {
  print ("</body></html>\n");
}
