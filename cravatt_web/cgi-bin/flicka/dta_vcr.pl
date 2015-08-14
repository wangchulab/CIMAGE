#!/usr/local/bin/perl

#-------------------------------------
#	DTA VCR,
#	(C)1998 Harvard University
#	
#	W. S. Lane/C. M. Wendl
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


################################################
# find and read in standard include file
{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################

$DEFAULT_PROGRAM = "$displayions?Dta=";

# DTA VCR can be used as a stand-alone program, but it is more often used as a "feature" of other
# programs such as RunSummary and VuDTA.  it provides a "VCR-like" method of scrolling (rewinding, fast-forwarding)
# through any list of links that's derived from a list of DTA or OUT files.

# EXPLANATION OF CGI INPUT
#
# the program creates a frameset, in which the bottom frame is the link specified by the calling program,
# and other frames are written by different instances of this program:
#
# $FORM{"frame"} determines which frame the program will write when it's run.  if not specified, it writes the whole frameset.
# (the so-called "info-frame" (middle-left) is written by Javascript code from the frameset output.)
#
# most other CGI variables have names starting with "DTAVCR:", since they often come from forms in other programs
# that may have other purposes unrelated to DTAVCR (i.e. we don't want to confuse the other programs with our parameters)
#
# $FORM{"DTAVCR:link"} and $FORM{"DTAVCR:link#"} -- the list of URLs to be displayed in the bottom frame
# $FORM{"DTAVCR:info"} and $FORM{"DTAVCR:info#"} -- the list of HTML text to be displayed in the info-frame (middle-left)
# $FORM{"DTAVCR:include_if"} and $FORM{"DTAVCR:include_if#"} -- used in tandem with the $FORM{"include_array"} option, see below
#
# NEW AS OF 10/24/99: since the contents of the above three variables can get extremely long, we may opt to retrieve the info
# from a temp file instead.  in that case we don't receive those parameters as CGI input, but instead we receive this:
# $FORM{"DTAVCR:tempfile"} -- specifies the full pathname of a file in the temp directory that we can read to get the very long
# contents of certain variables (usually DTAVCR:link, DTAVCR:info and DTAVCR:include_if) (this is used by runsummary.pl).
#
# $FORM{"DTAVCR:include_array"} -- this is used, for example, to limit the set of links that are displayed when the program
# is called by VuDTA: the value passed is the string "selected", meaning that we should expect to receive another CGI variable
# called $FORM{"selected"}; that is a list of DTA files (in more general terms, it lets us define an arbitrary array), and
# we know that for each entry in the DTAVCR:link list, we must only display it if the corresponding entry in the DTAVCR:include_if
# list is present in $FORM{"selected"}.  in the case of VuDTA, that means a URL is only put in the list of URLs to be scrolled
# through if its corresponding DTA was checked on the VuDTA page.
# if $FORM{"DTAVCR:include_array"} is not defined, the $FORM{"DTAVCR:include_if"} list is ignored.
#
# $FORM{"DTAVCR:conserve_space"}: if true, the frameset passes the argument $FORM{"conserve_space"} to the control (top) frame,
# which then saves space by not printing the standard header.
#
# $FORM{"DTAVCR:display_eject"}: if true, the frameset passes the argument $FORM{"display_eject"} to the control (top) frame,
# which then displays the "eject" button in the center (a link to the start page of the stand-alone program).  this option
# is specified by the stand-alone version of DTA VCR, but will not be needed in most other circumstances.
#
# for an example of how to insert a DTA VCR button on another web page that doesn't require checkbox interactivity, see dtafinder.pl.
# for the more complicated case in which checkbox interactivity is required, see runsummary.pl or dta_chromatogram.pl.
#
# -cmw (8/30/99, updated 10/24/99)


&cgi_receive();

&output_controls if ($FORM{"frame"} eq "controls");
&output_middle if ($FORM{"frame"} eq "middle");
&output_counter if ($FORM{"frame"} eq "counter");


# this defines an array of values that determine which links should be displayed and which should be skipped
# (used in tandem with the checkboxes in RunSummary and VuDTA)
if ($name = $FORM{"DTAVCR:include_array"}) {
	@include_array = split /, /, $FORM{$name};
}

# added 10/24/99 by cmw: if the CGI parameter "DTAVCR:tempfile" is specified, get very long values from a temp file 
# instead of directly from CGI variables
if ($tempfile = $FORM{"DTAVCR:tempfile"}) {
	open(TEMPFILE,"<$tempfile") || &error("Cannot open $tempfile.");
	while (<TEMPFILE>) {
		chop;
		s/^([^=]+)=//;
		$FORM{$1} = $_;		# from now on we can pretend it was actually CGI input
	}
	close(TEMPFILE);
}

@linklist_array = &get_array("link");
@info_array = &get_array("info");
@include_if_array = &get_array("include_if");


@linklist = @realindex = @info = ();
for $i (0..$#linklist_array) {

	unless (($condition = $include_if_array[$i]) && (!grep(($condition eq $_), @include_array))) {

		push(@linklist, $linklist_array[$i]);
		push(@realindex,$i);

		# make info-string safe to put between quotes in a line of Javascript code
		$info_array[$i] =~ s/\r//g;
		$info_array[$i] =~ s/\\([^n])/\\\\$1/g;
		$info_array[$i] =~ s/\n/\\n/g;
		$info_array[$i] =~ s/"/\\"/g;
		$info_array[$i] =~ s/'/\\'/g;
		$info_array[$i] =~ s/>/\\>/g;
		$info_array[$i] =~ s/</\\</g;
		#$info_array[$i] =~ s/ /&nbsp;/g;
		#$info_array[$i] =~ s/<a&nbsp;/<a /g;
		$info_array[$i] =~ s/^\s*//g;

		push(@info, $info_array[$i]);
	}
}

if (@linklist) {

   &create_main_frame;

} elsif (@linklist_array) {

	# a list of links was sent, but all were excluded (probably because no DTAs selected on calling page)
	&error("No links to display. (No files are selected?)");

} elsif ($dir = $FORM{"directory"}) {

   # if $dir is defined then create the main frame of dta_vcr 
   # using all the dtas in $dir with $displayions as executable
   opendir(MYDIR,"$seqdir/$dir");
   @dtas = grep /\.dta$/, readdir(MYDIR);
   closedir MYDIR;

   @linklist = map(("$DEFAULT_PROGRAM" . &url_encode("$seqdir/$dir/$_")), @dtas);
   @info = map "", @linklist;
   @realindex = (0..$#linklist);

   &create_main_frame;

} else {
   # output form if directory not defined and need to choose a directory
   &output_form;
}


################## END OF BODY ##################


# this takes CGI input and places it in a convenient array form
# the input may come in three forms, either
# (1) as a single form element called "DTAVCR:$string", with separate entries delimited by the string "<DTAVCR>"
#     or
# (2) as a set of form elements called "DTAVCR:$string0", "DTAVCR:$string1", "DTAVCR:$string2" etc...
#     or
# the former option is preferable in cases like RunSummary, where there are already more than enough form elements as it is.
sub get_array {

	my $string = shift;
	my (@ret_array, $i, $value);

	if ($FORM{"DTAVCR:$string"}) {
		# the entire array could be passed in a single form element...
		@ret_array = split("<DTAVCR>", $FORM{"DTAVCR:$string"});
	} else {
		# or it could be passed in several form elements...
		for ($i = 0; ($value = $FORM{"DTAVCR:$string$i"}); $i++) {
			push(@ret_array, $value);
		}
	}
	return @ret_array;
}



#
# create the main frame from the list of given links, where the links must
# be stored in @linklist as full URLs
#
sub create_main_frame {

	$conserve_space = $FORM{"DTAVCR:conserve_space"};
	$display_eject = $FORM{"DTAVCR:display_eject"};
	$display_legend = $FORM{"DTAVCR:legend"};
	if ($display_legend ne "") {
		$display_legend = "<span class=smallheading>" . $display_legend . "</span>";
	}

	$topframe_height = ($conserve_space) ? 45 : 95;
	$topframe_marginheight = ($conserve_space) ? 5 : 0;

	$numlinks = scalar(@linklist);

	print <<EOF;
Content-type: text/html

<HTML>
<HEAD><TITLE>DTA VCR</TITLE></HEAD>
EOF

#print qq("$display_legend");

print <<EOF;
<SCRIPT LANGUAGE="Javascript">
<!--

var current_idx = 0;
var linklist = new Array($#linklist + 1);
var realindex = new Array($#linklist + 1);
var info = new Array($#linklist + 1);
var legend = "$display_legend";

EOF

foreach $i (0..$#linklist) {
	print qq(linklist[$i] = "$linklist[$i]";\n);
	print qq(realindex[$i] = $realindex[$i];\n);
	print qq(info[$i] = "$info[$i]";\n);
}


print <<EOF;

function gotoLink(idx)
{

	if (idx >= linklist.length)
		return;
	if (idx < 0)
		return;
	current_idx = idx;

	// update URL link frame
	self.linkframe.location.replace(linklist[current_idx]);

	// update counter in middle-right frame
	self.middleframe.counterframe.location.replace("$ourname?frame=counter&index=" + (current_idx + 1) + "&total=$numlinks")

	// update info in middle-left frame
	update_info(current_idx);
}

function update_info(idx)
{
	self.middleframe.infoframe.document.open();
	self.middleframe.infoframe.document.writeln("<html><head><title>Info</title>");
	self.middleframe.infoframe.document.writeln("$stylesheet_javascript");
	self.middleframe.infoframe.document.writeln("<base target=_blank></head>");
	if (legend) {
		self.middleframe.infoframe.document.writeln("<body bgcolor=#FFFFFF><tt><nobr><form>" + legend + "<BR>" + info[idx] + "</form></nobr></tt></body></html>");
	} else {
	self.middleframe.infoframe.document.writeln("<body bgcolor=#FFFFFF><div><nobr><form>" + info[idx] + "</form></nobr></div></body></html>");
	}	
	self.middleframe.infoframe.document.close();

	// this bit is needed for interaction with runsummary when there are checkboxes:
	if (top.opener) {
		if (top.opener.vcr_update_info)
			top.opener.vcr_update_info(realindex[idx]);
	}
}
function summaryRevert() {
	if (top.opener && top.opener.DTA_VCR_revert) top.opener.DTA_VCR_revert();
}

function return_blank()
{
	return "<html></html>";
}

function ShowOut(dtafile) {
EOF
	$dbdirsafe = &url_encode("$dbdir/");
	$dirsafe = &url_encode("$seqdir/$directory/");
print <<EOM;
	thisurl = "$showout?OutFile=$dirsafe" + dtafile + ".out&dbdir=$dbdirsafe";
	open (thisurl, $uniqueid + windows);
	windows++;
}

function Flicka(ref, otherinfo, peptide, masstype) {
	thisurl = "$retrieve?Ref=" + ref + "&Pep=" + peptide + "&Dir=$dirsafe&Db=$dbdirsafe";
	thisurl += otherinfo + "&Masstype=" + masstype;
	open (thisurl, $uniqueid + windows);
	windows++;
}

function DisplayIons (peptide, otherinfo, file, masstype, iseries) {	
	thisurl = "$displayions?Pep=" + peptide + "&Dta=$dirsafe" + file + ".dta";
	thisurl += otherinfo + "&MassType=" + masstype + "&ISeries=" + iseries + "&NumAxis=1";
	open (thisurl, $uniqueid + windows);
	windows++;
}

function WebBlast (otherinfo, peptide) {
    thisurl = "$localblast?Db=$dbdirsafe" += otherinfo += "&Pep=" += peptide;
	open (thisurl, $uniqueid + windows);
	windows++;
}

function NRBST (peptide) {	
	var thisurl = "$remoteblast?$sequence_param=";
	thisurl += peptide;
	
	// our default parameters for display and significance:
	thisurl += "&$db_prg_aa_aa_nr&$word_size_aa&$expect&$defaultblastoptions";

	open (thisurl, $uniqueid + windows);	
	windows++;
}

function Fuzzified (file) {	
	thisurl = "$webseqdir/$directory/" + file + ".fuz.html";
	open (thisurl, $uniqueid + windows);	
	windows++;
}

function IonQuest (file, reffile) {
	thisurl = "$thumbnails?Dta=$seqdir/$ionquest_dir/" + file + ".dta&Dta=$seqdir/$ionquest_refdir/" + reffile;
	open (thisurl, $uniqueid + windows);	
	windows++;
}

//-->
</SCRIPT>

<FRAMESET ROWS="$topframe_height,60,*" BORDER=0 onLoad="summaryRevert(); update_info(0)">
<FRAME NAME="controls" SRC="$ourname?frame=controls&conserve_space=$conserve_space&display_eject=$display_eject" SCROLLING=no MARGINHEIGHT=$topframe_marginheight MARGINWIDTH=10>
<FRAME NAME="middleframe" SRC="$ourname?frame=middle&total=$numlinks" SCROLLING=no MARGINHEIGHT=0 MARGINWIDTH=0>
<FRAME NAME="linkframe" SRC="$linklist[0]" MARGINHEIGHT=0 MARGINWIDTH=0>
</FRAMESET>
</HTML>

EOM
   exit;
}


# 
# this is the top frame of DTA VCR
#
sub output_controls {

	$conserve_space = $FORM{"conserve_space"};
	$display_eject = $FORM{"display_eject"};
	$display_legend = $FORM{"DTAVCR:legend"};

	if ($conserve_space) {
		print <<EOF;
Content-type: text/html

<html>
<head>
<title>DTA VCR</title>
$stylesheet_html
<base target=_top>
</head>
<body bgcolor=#FFFFFF>
EOF
	} else {
		&MS_pages_header("DTA VCR", "880000", "<base target=_top>");
	}
	print <<EOF;
<center>
<nobr>
<form>
<a href="javascript:top.gotoLink(0)"><image src="$webimagedir/vcr_to_beginning.gif" width=30 height=30 border=0></a>&nbsp;&nbsp;
<a href="javascript:top.gotoLink(top.current_idx - 1)"><image src="$webimagedir/vcr_back.gif" width=50 height=30 border=0></a>&nbsp;&nbsp;
EOF
	print qq(<a href="$ourname"><image src="$webimagedir/vcr_eject.gif" width=30 height=30 border=0></a>&nbsp;&nbsp;\n) if ($display_eject);
	print <<EOF;
<a href="javascript:top.gotoLink(top.current_idx + 1)"><image src="$webimagedir/vcr_forward.gif" width=50 height=30 border=0></a>&nbsp;&nbsp;
<a href="javascript:top.gotoLink(top.linklist.length - 1)"><image src="$webimagedir/vcr_to_end.gif" width=30 height=30 border=0></a>
</form>
</nobr>
</center>
</body></html>
EOF

	exit;
}



# 
# this is initial frameset in middle frame (including two frames side by side)
#
sub output_middle {
# size of counterframe was initially 120

	$total = $FORM{"total"};
	print <<EOF;
Content-type: text/html

<html>
<FRAMESET COLS="*,100" BORDER=0>
<FRAME NAME="infoframe" SRC="javascript:top.return_blank()" MARGINHEIGHT=0 MARGINWIDTH=10>
<FRAME NAME="counterframe" SRC="$ourname?frame=counter&index=1&total=$total" SCROLLING=no MARGINHEIGHT=0 MARGINWIDTH=10>
</FRAMESET>
EOF

   exit;
}



# 
# this is the content of the middle-right frame (# of #)
#
sub output_counter {

	$index = $FORM{"index"};
	$total = $FORM{"total"};
	print <<EOF;
Content-type: text/html

<html>
<head>
$stylesheet_html
</head>
<body bgcolor=#FFFFFF><div align="right"><b>$index of $total</b></div></body></html>
EOF

   exit;
}



#
# output form if directory not defined and need to choose a directory
#
sub output_form {

	&MS_pages_header("DTA VCR", "880000");
	print "<P><HR><P>\n";

	print "<FORM ACTION=\"$ourname\" METHOD=get>";

	&get_alldirs;
	print <<EOF;
<TABLE><TR><TD VALIGN=top>
<span class="dropbox"><SELECT NAME="directory">
EOF
	foreach $dir (@ordered_names) {
		print qq(<option value="$dir">$fancyname{$dir}\n);
	}
	print <<EOF;
</select></span></TD>
<TD VALIGN=top>
<input type=image src="$webimagedir/vcr_play.gif" border=0 width=40 height=24>
</TD></TR></TABLE>
<input type=hidden name="DTAVCR:display_eject" value=1>
</form></body></html>
EOF
	exit 0;
}


sub error {

	&MS_pages_header("DTA VCR", "880000");
	print "<br><hr><br>\n";
	print "<h3>Error</h3>\n";
	print "<div>$_[0]</div>";

	exit;

}
