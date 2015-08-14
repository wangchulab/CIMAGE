#!/usr/local/bin/perl

#-------------------------------------
#	DTA Chromatogram,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
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
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
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

$sort_def{$DEFS_VUDTA{"Sort"}} = " SELECTED";
$sort_def{"Reverse"} = ($DEFS_VUDTA{"Ascending"} eq "yes") ? " CHECKED" : "";

# added by cmwendl (3/27/98)
# a default directory for the dropbox can be specified in CGI input with def_dir:
$def_dir = $FORM{"def_dir"};


##
## $maxZ is the highest charge state that we list on the first page
## It is grouped with all charge states greater than it for automatic
## deselection (at the user's request)
##
## NB. If this is greater than or equal to 10 (unlikely), the regexp logic
## in &get_selection_defaults will need to be altered.
##
$maxZ = 5;

## 
## Color definitions
##
$intencolor = "ff7f00"; # coral
$masscolor = "9932CD"; # Dark Orchid 
$mzcolor = "6B4226"; # semi-sweet chocolate
$commentcolor = "ff0000"; # bright red
$dircolor = "000080"; # dark blue

# charge stat colors: dark blue for +1, dark green for +2, dark red for higher
@zcolors = qw(000080 008000 640000);


# decide if we are "zoom" or "dta" chromatogram
# see if zoom is in our name
# $zoom is true if we are zoom, false otherwise
$zoom = ($ourname =~ /zoom/i);

# but also check inherited variables
if (defined $FORM{"arewezoom"}) {
  $zoom = $FORM{"arewezoom"};
}

# "togglezoom" is a push-button, so we set $refresh to 1
# force re-calculation
if ($FORM{"togglezoom"}) {
  $zoom = $zoom ? 0 : 1;
  $refresh = 1;
  $FORM{"display"} = "graph"; # fool list into being off
}
# force $zoom to be either "1" or "0"
$zoom = $zoom ? 1 : 0;

# keep track of reverse switch, rico 9/27/97
$lastreverse = $FORM{"lastreverse"};

# the name of the other personality of this program
$alterEgoName = $zoom ? "VuDta" : "VuZoom";

##
## width and height of images
##
$HSIZE = 725;
$VSIZE = 500;

##
## $display determines whether the graph, the list, or both will be shown
## at refresh time.
## $list and $graph are the individual indicators
##
$display = $FORM{"display"};
if ($display =~ /both/) {
	$list = $graph =  1;
}
if ($display =~ /list/) {
	$list = 1;
}
if ($display =~ /graph/) {
	$graph = 1;
}

if (!$graph and !$list) {
 # force these to be checked
	$graph = 1;
	$list = 1 if (!$zoom);
}
$graph = "CHECKED" if $graph;
$list = "CHECKED" if $list;

##
## let's get some consistent idea of what we're doing here.
##
## $givenlowerbound and $givenupperbound are the bounds
## requested by the user through the form. If undef, no limits
## were specified.
##
## $lowerbound and $upperbound are the ACTUAL bounds, which are
## usually within the given bounds if defined, but may not be
## (for instance, if $givenlowerbound falls within the span of
## some dta, then the whole peak is displayed.)
##

$givenlowerbound = $FORM{"lowerbound"};
$givenupperbound = $FORM{"upperbound"};

##
## Sequest directory
##
$dirname = $FORM{"directory"};

# if no directory defined, this is the first page, so display only the dropdown.
if (!defined $dirname) {
  &print_header;
  &output_autolimits;
  print ("</FORM>\n");
  &tail;
  exit;
}


# $fancyname is used in the graph
$fancyname = $FORM{"fancyname"};
if (!defined $fancyname) {
  ($fancyname) = &get_fancyname ($dirname);
}

# we were called from another program, so set defaults correctly:
if (!defined $FORM{"notforeign"}) {
  $FORM{"labels"} = "CHECKED";
  &set_selection_defaults;
} else {
  &get_selection_defaults;
}


##
## If $DA is true, ignore upper and lower bounds
## 
## setting $refresh to true forces recalculation of the graph and data
##

if ($FORM{"displayall"}) {
  $refresh = 1;
  $givenlowerbound = undef;
  $givenupperbound = undef;
} elsif ($FORM{"show"}) {
  $refresh = 1;
}

##
## Use labels?
##
$LABELSON = $FORM{"labels"};

##
## How the list should be sorted
##
$sorttype = $FORM{"sort"};
$sorttype =~ s/\s//g;
if ((!defined $sorttype) || ($sorttype eq "")) {
  $sorttype = $FORM{"lastsort"};
}

##
## If we're not refreshing, we can use the supplied filenames.
## Otherwise, we will need to generate new ones.
##
if (!$refresh) {
	$pngfile  = $FORM{"graphfile"};
	$textfile = $FORM{"listfile"};
} else {
	$pngfile  = "$ourshortname" . "_$$.png";
	$textfile = "$ourshortname" . "_$$.txt";
}

##
## Write to a file
##
if ($FORM{"write"}) {
    &print_header ("Selected DTAs");
    &write_out_dtas;
    exit;
}

## Header
&print_header;


##
## $NOTok is a global variable that is set true if an error occurs.
## if so, an mesage is put in the variable $errmsg
##

##
## If there is need to generate new images, check parameters, read in
## data, and create the graph.
##
if ($refresh) {

    if ((defined $givenupperbound) and (defined $givenlowerbound)
	and ($givenupperbound < $givenlowerbound) ){
	$NOTok = 1;
	$errmsg = "Last scan is less than first scan.";
    }

    if (!$NOTok) {
	&read_data();
	if ($zoom and !$using_profile) {
          print ("<b>No lcq_profile.txt file found, reverting to normal ",
                 "VuDTA behavior.</b><p>\n");
	}

	&do_graph();
    }
}

if ($NOTok) {
    print ("Error: $errmsg<p>\n");
    exit;
}

##
## Generate appropriate HTML output for the graph
##
if ($graph) {
    print <<IMGDATA;
<IMG ALIGN=TOP SRC="$webtempdir/$pngfile" WIDTH=$HSIZE HEIGHT=$VSIZE
 ALT = "Please wait...loading image...">
<br>
IMGDATA
}

##
## Generate the text listing, if necessary
##
if ($refresh) {
    &do_text();
    &auto_select();
} else {
    &read_textfile();
    &get_selected();
}

&hide_selection_defaults(); # save for possible use later if the user clicks "Defaults"

&table_header();

if (!$list) { # still need to incorporate "selected"
    foreach $file (@dtafiles) {
	next unless $selected{$file};
	print qq(<INPUT TYPE=HIDDEN NAME="selected" VALUE="$file">\n);
    }
} else {
    &do_html;
    &dta_vcr_chr_load();
}
print <<EOM;
</TABLE>
<INPUT TYPE=HIDDEN NAME="oldlowerbound" VALUE="$lowerbound">
<INPUT TYPE=HIDDEN NAME="oldupperbound" VALUE="$upperbound">
</FORM>
EOM

&tail();
exit();

#############################
## end of main program flow #
##                          #
## subroutines follow       #
#############################


##
## &tail
##
##	Prints copyright, attributions, and closing tags
##
sub tail {

    print qq(<div align=left><span style="color:#63968e" class="smalltext">\n);
    &GD_notice;
    print ("</span></div>\n");
    print ("</div></body></html>\n");
}

##
## &print_header
##
##	Prints buttons and dropdown boxes at the top of the page
##
sub print_header {
    my $name = $_[0];

    if ($name) {
	&MS_pages_header ($name, "#63968e");
	return;
    }
    $name = $zoom ? "ZoomMaxScan" : "DTA";

    &MS_pages_header ("$name Chromatogram:", "#63968e");

    print ("<hr><br style=\"font-size:10\">\n");

	print "<div>\n";
    print qq(<FORM ACTION="$ourname" METHOD=POST  style="margin-top:0; margin-bottom:0">\n\n);

    if (!defined $dirname) {
      ##
      ## subroutine from microchem_include.pl
      ## that gets all the directory information
      ##
      &get_alldirs;

      # make dropbox:
	  print <<EOF;
<TABLE cellpadding=0 cellspacing=0 border=0 width=510>
<tr height=30>
	<td align=right class=smallheading bgcolor=#e8e8fa>&nbsp;Directory:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<span class=dropbox><SELECT name="directory">
EOF
	  $helplink = &create_link();
      foreach $dir (@ordered_names) {
	  $selected = ($dir eq $def_dir) ? " SELECTED" : "";   # added by cmwendl (3/27/98)
	  print qq(<OPTION VALUE = "$dir"$selected>$fancyname{$dir}\n);
      }
	  print <<EOF;
</SELECT></span></td>
<INPUT TYPE=HIDDEN NAME="arewezoom" VALUE="$zoom">
<td align=center nowrap>&nbsp;&nbsp;&nbsp;&nbsp;<INPUT TYPE="SUBMIT" CLASS="outlinebutton button" VALUE="Show" NAME="show">&nbsp;&nbsp;&nbsp;$helplink</td>
</tr></table>
<br style="font-size:18">
<TABLE cellpadding=0 cellspacing=0 border=0>
<tr><td valign=top>
<TABLE cellpadding=0 cellspacing=0 border=0 width=300>
<tr><td>
<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
	<td width=20><img src="/images/ul-corner.gif" width=10 height=20></td>
	<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Display</td>
	<td width=20><img src="/images/ur-corner.gif" width=10 height=20></td>
</tr></table>
</td></tr>

<tr><td>
<table cellpadding=0 cellspacing=0 border=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
<tr height=18><td align="right" class=smallheading bgcolor=#e8e8fa>&nbsp;Sort:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<span class="dropbox"><SELECT NAME="sort" style="font-size:12">
		<OPTION $sort_def{"m/z"}>m/z
		<OPTION $sort_def{"MH+"}>MH+
		<OPTION $sort_def{"z"}>z
		<OPTION $sort_def{"scans"}>scans
		<OPTION $sort_def{"inten"}>inten
		<OPTION $sort_def{"ions"}>ions
		<OPTION $sort_def{"Dif"}>Dif
		<OPTION $sort_def{"Description"}>Description
		</SELECT></span>&nbsp;&nbsp;
		<INPUT TYPE=checkbox NAME="reverse" VALUE="yes"$sort_def{"Reverse"}>&nbsp;Ascending&nbsp;&nbsp;
	</td>
</tr>

<tr height=18><td align="right" class=smallheading bgcolor=#e8e8fa>&nbsp;First scan:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;<INPUT NAME="lowerbound" MAXLENGTH=4 SIZE=4
EOF

    print " VALUE=" . ((defined $givenlowerbound) ? $givenlowerbound : "");
    print ">\n";

    print qq(		<span class=smallheading>&nbsp;Last scan:&nbsp;&nbsp;<span><INPUT NAME="upperbound" MAXLENGTH=4 SIZE=4);
    print " VALUE=" . ((defined $givenupperbound) ? $givenupperbound : "");
    print "></td></tr>\n";

	print <<ENDOFLINE;
<tr height=18><td align="right" class=smallheading bgcolor=#e8e8fa>&nbsp;List:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=CHECKBOX NAME="display" VALUE="list" $list></tr>
<tr height=18><td align="right" class=smallheading bgcolor=#e8e8fa>&nbsp;Chromatogram:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=CHECKBOX NAME="display" VALUE="graph" $graph></tr>
ENDOFLINE

    print ("	<tr height=18><td align=\"right\" class=smallheading bgcolor=#e8e8fa>&nbsp;Labels:&nbsp;&nbsp;</td><td class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT TYPE=CHECKBOX NAME=\"labels\"");
    print (" CHECKED") if ($LABELSON || !$dirname);
    print ("></tr>\n");

	print <<ENDOFLINE;
</table></td></tr></table>
</td>

<!-- The following assures us that we were not called from another program using a GET or direct URL-->
<INPUT TYPE=HIDDEN NAME="notforeign" VALUE="TRUE">
ENDOFLINE

	} else { # Revert to old header for the output page
	    print qq(<INPUT TYPE="SUBMIT" CLASS="outlinebutton button" VALUE="Show" NAME="show">&nbsp;);

	    print qq(<span class=smallheading>First scan: </span><INPUT NAME="lowerbound" MAXLENGTH=4 SIZE=4);

	    print " VALUE=" . ((defined $givenlowerbound) ? $givenlowerbound : "");
	    print ">\n";

		print qq(<span class=smallheading>Last scan: </span> <INPUT NAME="upperbound" MAXLENGTH=4 SIZE=4);
		print " VALUE=" . ((defined $givenupperbound) ? $givenupperbound : "");
	    print ">\n";

	    print ("&nbsp;<INPUT TYPE=\"SUBMIT\" CLASS=\"outlinebutton button\" VALUE=\"Display All\" NAME=\"displayall\">\n");
	    print ("&nbsp;\n");

		print qq(&nbsp;<span class=smallheading>List</span><INPUT TYPE=CHECKBOX NAME="display" VALUE="list" $list>);		
		print qq(&nbsp;<span class=smallheading>Chromatogram</span><INPUT TYPE=CHECKBOX NAME="display" VALUE="graph" $graph>);
		print ("&nbsp;<span class=smallheading>Labels</span><INPUT TYPE=CHECKBOX NAME=\"labels\"");
	    print (" CHECKED") if ($LABELSON || !$dirname);
	    print (">\n");

	    print <<ENDOFLINE;
<INPUT TYPE=SUBMIT CLASS=button NAME="togglezoom" VALUE="$alterEgoName">
<INPUT TYPE=HIDDEN NAME="arewezoom" VALUE="$zoom">
<SPACER TYPE=VERTICAL SIZE=6>
<!-- The following assures us that we were not called from another program using a GET or direct URL-->
<INPUT TYPE=HIDDEN NAME="notforeign" VALUE="TRUE">
ENDOFLINE
	}
}

sub table_header {

  # we need to do this to get tables to work consistently
  # tables - can't live with 'em, can't live without 'em
  my $restwidth = $tablewidth - (30 + 65 + 65 + 25 + 85 + 50);

  print <<STARTTABLE;
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dirname">
<INPUT TYPE=HIDDEN NAME="fancyname" VALUE="$fancyname">
<INPUT TYPE=HIDDEN NAME="listfile" VALUE="$textfile">
<INPUT TYPE=HIDDEN NAME="graphfile" VALUE="$pngfile">
<INPUT TYPE=HIDDEN NAME="lastsort" VALUE="$sorttype">

<span class=smallheading> Exclude file: </span><a href="$exclude_link" target=_blank>$exclude_file</a>
<b><a href="$edit_excludes" target=_blank>Edit</a></b>
&nbsp;&nbsp;<span class=smallheading>Tolerance:</span> $exclude_tolerance amu
<p>
<span class=smallheading>Directory:</span> <a href="$webseqdir/$dirname/" target=_blank>$dirname</a>
&nbsp;&nbsp;<b><a href="$webcgi/dta_banisher.pl?directory=$dirname" target=_blank>Banisher</a></b>
&nbsp;&nbsp;<a href="$viewheader?directory=$dirname" target=_blank>Info</a>
&nbsp;&nbsp;<a href="$webseqdir/$dirname/$dirname.log" target=_blank>Log File</a>
<br>
<SPACER TYPE=VERTICAL SIZE=5>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Write List of Selected DTAs to File" NAME="write">&nbsp;
<span class=smallheading>Delete the <i>unselected</i> DTAs?</span>	 <INPUT TYPE=CHECKBOX NAME="delete_unselected">&nbsp;
<span class=smallheading>Op:</span> <INPUT NAME="operator" SIZE=3><br>

<SPACER TYPE=VERTICAL SIZE=15>
<span class=smallheading> $numdtas DTA files, $numsel selected.
&nbsp;Select:</span> <INPUT TYPE=button CLASS=button onClick="checkAll()" VALUE=" All ">
<INPUT TYPE=button CLASS=button onClick="uncheckAll()" VALUE="None">
<INPUT TYPE=button CLASS=button onClick="invertAll()" VALUE=" Inv ">
<INPUT TYPE=submit CLASS=button NAME="selectall" VALUE="Default">



<!-- check/uncheck all boxes, the quick way (cmwendl, 2/27/98) -->
<SCRIPT LANGUAGE="JavaScript">
<!--
    function uncheckAll()
    {
	for (i = 0; i < document.forms[0].elements.length; i++)
	{
	    if (document.forms[0].elements[i].name == "selected")
		document.forms[0].elements[i].checked = 0;
	}
    }
    function checkAll()
    {
	for (i = 0; i < document.forms[0].elements.length; i++)
	{
	    if (document.forms[0].elements[i].name == "selected")
		document.forms[0].elements[i].checked = 1;
	}
    }
	function invertAll()
	{
		for (i = 0; i < document.forms[0].elements.length; i++)
	{
	    if (document.forms[0].elements[i].name == "selected")
		document.forms[0].elements[i].checked = (document.forms[0].elements[i].checked == 0) ? 1 : 0;
	}
	}
//-->
</SCRIPT>

<!-- for toggle sorting, rico, 9/27/97 -->
<SPACER TYPE=HORIZONTAL SIZE=140>
<INPUT TYPE=SUBMIT CLASS=button NAME="reverse" VALUE="Reverse Sort">
<INPUT TYPE="button" CLASS=button NAME="dta_vcr_chr" VALUE="DTA VCR" onClick="opendta_vcr_chr()">
<br>
<SPACER TYPE=VERTICAL SIZE=5>

<TABLE $TABLEWIDTH BORDER=0 CELLSPACING=0 CELLPADDING=0>
<TR ALIGN=CENTER>
<TD WIDTH=30><span class=smallheading>Use</span></TD>
<TD WIDTH=65><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="m/z"></TD>
<TD WIDTH=65><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="MH+"></TD>
<TD WIDTH=25><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE=" z "></TD>
<TD WIDTH=85><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="scans"></TD>
<TD WIDTH=50><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="inten"></TD>
<TD WIDTH=45><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="ions"></TD>
<TD WIDTH=40><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="Dif"></TD>
<!-- <TD WIDTH=35 ALIGN=left>dif</TD> -->
<TD><INPUT TYPE=SUBMIT CLASS=button NAME="sort" VALUE="Description"></TD>
</TR>

<TR>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
<TD><HR></TD>
</TR>

STARTTABLE
}


##
## &write_out_dtas
##
##	Writes a list of .dtas to a file, deleting any not listed (if
##	$delete is set).
##
sub write_out_dtas {
  ## Delete .dta files not explicitly selected if true
  my $delete = $FORM{"delete_unselected"};
  my $temp;
  my (%preserve, %ignore);

  my @dtas = sort (split (", ", $FORM{"selected"}));

  my $filename = "selected_dtas.txt";

  #### this isn't secure but it's flexible ####
  my $file = "$seqdir/$dirname/$filename";

  open (FILE, ">$file") || &write_error ("Could not write to $file");
  foreach $dta (@dtas) {
    print FILE ("$dta\n");
  }
  close FILE;
  chmod (0666, $file);

  if ($delete) {

    $operator = $FORM{"operator"};
    if (!defined $operator) {
	print "<P><B>No files deleted:</B> You must type your initials in the <i>Op.</i> field in order to delete DTAs.";
    } else {

	    $operator =~ tr/A-Z/a-z/;

	    opendir (DIR, "$seqdir/$dirname") || &write_error ("Could not delete files");

	    @alldtas = grep { /\.dta$/ } readdir (DIR);
	    foreach $dta (@dtas) {
      	$preserve{$dta} = 1;
	    }

	    # preserve DTAs with scan values lower than range:
	    if (defined $FORM{"oldlowerbound"}) {
      	foreach $dta (@alldtas) {
	        ($temp) = $dta =~ m!\d{4}\.(\d{4})\.\d.dta!i;
			# added cmw (6/3/00) for alternate filename formats
			$temp = "0000" if (!defined $temp);
      	  $ignore{$dta} = 1 if ($temp < $FORM{"oldlowerbound"});
	      }
	    }

	    # preserve DTAs with scan values higher than range:
	    if (defined $FORM{"oldupperbound"}) {
      	foreach $dta (@alldtas) {
	        ($temp) = $dta =~ m!(\d{4})\.\d{4}\.\d.dta!i;
			# added cmw (6/3/00) for alternate filename formats
			$temp = "0000" if (!defined $temp);
      	  $ignore{$dta} = 1 if ($temp > $FORM{"oldupperbound"});
	      }
	    }
	    foreach $dta (@alldtas) {
	      next if $preserve{$dta};
      	next if $ignore{$dta};
	      if (&delete_files("$seqdir/$dirname/$dta")) {
      	  push (@deleted, $dta);
	      } else {
      	  push (@notdeleted, $dta);
	        if ( -f "$seqdir/$dirname/$dta") {
      	    $whynot{$dta} = "probably a permissions problem";
	        } else {
      	    $whynot{$dta} = "(file already deleted)";
	        }
	      }
	    }
	    &update_selected_dtas($dirname);

	    # logging feature added by cmw, 8-3-98
	    $num_dtas_deleted = @deleted;
	    my $now = localtime();
	    &write_deletionlog($dirname, "VuDTA deleted $num_dtas_deleted DTAs  $now  $operator", \@deleted);
    }
  }

  print qq(<p><span class="largetext"><a href="$seqlaunch">Run Sequest</a></span><p>\n);

  print ("<h3>The following dtas were written to the list $filename.</h3>");
  print ("\n<div><ul>\n");
  foreach $dta (@dtas) {
    print ("<li><tt>$dta</tt>\n");
  }
  print ("</ul></div>\n");

  if ($delete) {
    if (@deleted) {
      print ("<div>The following dtas were deleted successfully.\n<ul>\n");
      foreach $dta (@deleted) {
	print ("<li><tt>$dta</tt>\n");
      }
      print ("</ul></div>\n");
    }
    if (@notdeleted) {
      print ("<div>The following dtas were not deleted.\n<ul>\n");
      foreach $dta (@notdeleted) {
	print ("<li><tt>$dta</tt> - $whynot{$dta}\n");
      }
      print ("</ul></div>\n");
    }
  }
}

##
## &write_error
##
##	Crude error reporting in HTML
##
sub write_error {
	print <<ENDERR;
<H1>Error:</H1>

@_

<p>
ENDERR
	exit;
}

## &do_text writes out the data to a flat text file
##
## if we have just analyzed the *.dta files, we then write out
## the data we use for display to a cache file in the $tempdir directory.
##
## The format is simple: We put the name of the file on one line,
## and then each attribute on its own line thereafter. We repeat
## for all DTA files.
##
## NB. In order to make this work, no attribute may have carriage
## returns in them. The only attribute for which this really matters
## is the %comment associative array.

sub do_text {
    my ($url, $temp);

    # format of this output: each attribute on a line, order matters,
    # we include "$file" because it serves as a unique identifier
    # and facilitates debugging

    open (TEXT, ">$tempdir/$textfile") || die ("Could not open $tempdir/$textfile");

    # mimic data given by read_textfile
    $numdtas = $#dtafiles + 1;

    foreach $f (@dtafiles) {

      $mz{$f} = (($mass{$f} + ($charge{$f} - 1)) / $charge{$f});
      $mz{$f} = &precision ($mz{$f}, 2, 4, "&nbsp;");

      $sum{$f} = &sci_notation ($sum{$f});
      $mass{$f} = &precision ($mass{$f}, 2, 4, "&nbsp;");
      $zcolor{$f} = $zcolors[ ($charge{$f} > 3 ? 2 : $charge{$f} - 1) ];

      $url = "$displayions?dtafile=$dir/$f&numaxis=1";

      if ($firstscan{$f} == $lastscan{$f}) {
	$scanurl{$f} = "<a href=\"$url\" target=_blank>$firstscan{$f}</a>" . "&nbsp;" x 5;
      } else {
	$scanurl{$f} = "<a href=\"$url\" target=_blank>$firstscan{$f}-$lastscan{$f}</a>";
      }
      $temp = join ("\n", $f, $mz{$f}, $mass{$f}, $charge{$f}, $zcolor{$f},
		    $scanurl{$f}, $comment{$f}, $sum{$f}, $numions{$f},
		    $difs{$f}, $ionpercent{$f});
      print TEXT ("$temp\n");
    }
    close TEXT;
}

##
## &read_textfile reads in the data from the cache file
##
## The cache file created in &do_text in the previous invocation of this
## program is read in now. In this way, we needn't re-read all the DTA
## files on every invocation.

sub read_textfile {
    my $file;

    open (TEXT, "$tempdir/$textfile") || die ("Could not open $tempdir/$textfile");
    while (chomp($file = <TEXT>)) {
	chomp ($mz{$file} = <TEXT>);
	chomp ($mass{$file} = <TEXT>);
	chomp ($charge{$file} = <TEXT>);
	chomp ($zcolor{$file} = <TEXT>);
	chomp ($scanurl{$file} = <TEXT>);
	chomp ($comment{$file} = <TEXT>);
	chomp ($sum{$file} = <TEXT>);
	chomp ($numions{$file} = <TEXT>);
	chomp ($difs{$file} = <TEXT>);
	chomp ($ionpercent{$file} = <TEXT>);
	push (@dtafiles, $file);
    }
    close TEXT;
    $numdtas = $#dtafiles + 1;
}

## &read_data analyzes a new set of DTAs afresh
##
## On our first invocation, and on those occasions when the cache file
## can't be used (the user defined new bounds, or wants to see the
## VuZoom data), we analyze the DTA files directly. This is done in this
## subroutine.
##
## In addition, we look in the contaminants' exclude file for matches against our
## mass/charge pair. Such matches are listed, along with data indicating
## how well the spectra matches that of the suspected contaminant, if the suspect is
## a peptide.
##
## Note that this subroutine implements both the original VuDTA behavior and the
## new VuZoom capability (looking at the ZoomScanMaxBP values given in the
## lcq_profile.txt file) depending on how the program was called.

sub read_data {
    # this reads in all the files and sets up the associative arrays
    # for the other routines.

    # all variables not explicitly local are probably used globally,
    # so be careful
    my ($massline, $sum, $line, $mass_charge);
    my ($mass_excl, $charge, $rest, $comment, $graphlabel);
    my ($pep_string, $l, $m, $noise, @sums, $difs, $key);

    die ("No directory given!") if (!defined $dirname);
    $dir = "$seqdir/$dirname";
	my $qtof_exists = ( -f "$dir/qtof_convert.txt");

    $using_profile = 0;
    if ($zoom and open (PROFILE, "$dir/lcq_profile.txt")) {
      my $ZoomScanMaxBP;
      $using_profile = 1;

      $line = <PROFILE>; # throw away column names
      while ($line = <PROFILE>) {
  	    ($file, $dummy, $dummy, $dummy, $ZoomScanMaxBP) = split (' ', $line);

		next unless ($file =~ /.dta$/);
        next unless ( -f "$dir/$file");  # make sure it really exists
		# this bit modified by cmw (6/3/00) to account for alternative filename formats
		if ($file =~ /(\d\d\d\d)\.(\d\d\d\d)\.\d\.dta$/) {
			($firstscan,$lastscan) = ($1,$2);
		} else {
			($firstscan,$lastscan) = ("0000","0000");
		}

        # skip out of bound files
        next if ($lastscan < $givenlowerbound or
                 (defined  $givenupperbound and $firstscan > $givenupperbound));

        $firstscan{$file} = $firstscan;

		# SDR: qtof_convert.txt appears as a result of a new naming convention with 4 digit run sample ids
		# As a result, the naming convention has changed and must be changed in here as well.
		if ($qtof_exists) {
	        $maxscan = &max ($1, $maxscan);
			$lastscan{$file} = $firstscan;
		} else {
	        $maxscan = &max ($2, $maxscan);
			$lastscan{$file} = $lastscan;
		}

        $minscan = ($minscan ? &min ($1, $minscan) : $1);

        $sum{$file} = $ZoomScanMaxBP;
        $maxsum = &max ($ZoomScanMaxBP, $maxsum);
        push (@dtafiles, $file);
      }
      close PROFILE;
    } else {
      opendir (DATADIR, "$dir") || die ("could not opendir $dir");

      while($file = readdir (DATADIR)) {

		next unless ($file =~ /.dta$/);

	# filenames look like "username-sample.0245.0268.1.dta"
	# here, 0245 ms is the start, 0268 ms is the end, of the interval
	# cmw (6-3-00): filenames don't ALWAYS look like that, and i'm changing things to account for it
	if ($file =~ /(\d\d\d\d)\.(\d\d\d\d)\.\d\.dta$/) {

		# skip out of bound files
		next if ($1 < $givenlowerbound or
			 ((defined $givenupperbound) && $1 > $givenupperbound));
		$firstscan{$file} = $1;
		# SDR: qtof_convert.txt appears as a result of a new naming convention with 4 digit run sample ids
		# As a result, the naming convention has changed and must be changed in here as well.
		if ($qtof_exists) {
			$lastscan{$file} = $1;
		} else {
			$lastscan{$file} = $2;
		}
	} else {

		# set scan numbers to 0000 if filenames are in odd format
		$firstscan{$file} = "0000";
		$lastscan{$file} = "0000";

	}

	$maxscan = &max ($lastscan{$file}, $maxscan);
	$minscan = ($minscan ? &min ($firstscan{$file}, $minscan) : $firstscan{$file});

	push (@dtafiles, $file);
      }
      closedir DATADIR;
    }


    @dtafiles = sort { ($firstscan{$a} + $lastscan{$a}) <=>
			   ($firstscan{$b} + $lastscan{$b}) } @dtafiles;

    # if no given upperbound, make the top the maxscan
    # otherwise, make it the greater of $maxscan and $givenupperbound

    if (defined $givenupperbound) {
      $upperbound = &max ($maxscan, $givenupperbound);
    } else {
      $upperbound = $maxscan;
    }

    # similarly for lowerbound: take the lesser of $minscan and 
    # $givenlowerbound if $givenlowerbound exist.

    if (defined $givenlowerbound) {
      $lowerbound = &min ($minscan, $givenlowerbound);
    } else {
      $lowerbound = $minscan;
    }

    $scanlen = $upperbound - $lowerbound;
    if ($scanlen < 0) {
	$NOTok = 1;
	$errmsg = "Nothing in range.";
	return;
    }

    foreach $file (@dtafiles) {
      open (FILE, "$dir/$file") || die ("Could not open $file");
      $mass_charge = <FILE>; # first line is mass and charge info
      chop $mass_charge;

      ($mass{$file}, $charge{$file}) = split (" ", $mass_charge);
      $charge{$file} = "+" . $charge{$file} if ($charge{$file} > 0);

      $numions{$file} = "";

      # skip the counting if we are using the ZoomMaxBP value from
      # lcq_profile.txt
      next if $using_profile;

      $sum = 0;
      while ($line = <FILE>) {
	chomp $line;
	$line =~ /^\d+\.?\d* (\d+\.?\d*)$/ || die ("$file has error in format:\n$line\nstopped ");
	$sum += $1;
	$numions{$file}++;
      }
      close FILE;

      $sum{$file} = $sum; 
      $maxsum = &max ($sum, $maxsum);
    }
    $maxsum = 1 if (!$maxsum); # to prevent divide by zero errors

    ##
    ## Find diffs between masses
    ## traversal of triangular half matrix of @dtafiles x @dtafiles
    ##
    ## this goes into the %difs attribute
    ##

    my $sigdiff;
    my $s1, $s2; # temporary variables to allow for tolerance
    my $top = $#dtafiles;
    my $i, $j;

    foreach $file (@dtafiles) {
      $difs{$file} = "";
    }

    for ($i = 0; $i <= $top; $i++) {
      for ($j = $i + 1; $j <= $top; $j++) { 
	$key = $dtafiles[$i];
	$file = $dtafiles[$j];

	$sigdiff = abs($mass{$file} - $mass{$key});

	# pre-compute these for speed:
	$s1 = $sigdiff - $dif_tolerance;
	$s2 = $sigdiff + $dif_tolerance;

      SIG: {
	# quick shortcut
	last SIG if ($s2 < 16.0 or $s1 > 156.0);

	# check methionines
	(($s2 >= 16.0 and $s1 <= 16.0) or
	 ($s2 >= 32.0 and $s1 <= 32.0)) 
	  and do { $difs{$key} .= "M"; $difs{$file} .= "M"; last SIG; };

	# check cysteines
	(($s2 >= 57.0 and $s1 <= 57.0)  or
	 ($s2 >= 71.0 and $s1 <= 71.0))
	  and do { $difs{$key} .= "C"; $difs{$file} .= "C"; last SIG; };

	# check lysines
	($s2 >= 128.0 and $s1 <= 128.0)
	  and do { $difs{$key} .= "K"; $difs{$file} .= "K"; last SIG; };

	# check arginines
	($s2 >= 156.0 and $s1 <= 156.0)
	  and do { $difs{$key} .= "R"; $difs{$file} .= "R"; last SIG; };
      } # SIG
      } # for
    } # end of mass-diffs loops
  
    ## truncate diffs field
    foreach $file (@dtafiles) {
      $difs{$file} = "" unless $difs{$file};
      if (length($difs{$file}) > 3) {
	substr($difs{$file},2) = "*";
      }
    }

    ##
    ## Here we parse the exclude file to see any DTAs match known
    ## contaminants. We construct URLs to displayions and display
    ## ion match ratios (given by "synopsis") for those matches
    ## that are peptides.
    ##
    ## Format of the exclude file:
    ##     Comments are preceded by a "#" mark.
    ##     Lines that are blank or all comments are ignored.
    ##     The lines have the following format:
    ##
    ##     MH+ z graphlabel SEQUENCE # description after the number sign
    ##
    ##     For example:
    ##     1384.7 2 Casein FFVAPFPEVFGK # bo Casein alpha-S1
    ##
    ##     "graphlabel" will be displayed on the chromatogram, marking
    ##     the peak to which it corresponds. It should be kept short.
    ##
    ##     "SEQUENCE" will be displayed as a hyperlink appended to the description
    ##     put just "X" (without the quotes) for the SEQUENCE if not applicable
    ##
    ##     The description, which is optional, may include whitespace (the other
    ##     fields may not, since whitespace is used to separate them). This 
    ##     can be more descriptive than "graphlabel".
    ##
    ## Notes:
    ##     The first column is the calculated MH+, not the mass to charge ratio
    ##     The list need not be sorted in any way.
    ##     More than one match is possible; all will be listed.
    ##

    open (EXCL, "$exclude_file") || die ("Could not open $exclude_file");

    my $ionpercent;
    while ($line = <EXCL>) {
      chomp $line;
      next if ($line eq "" or $line =~ /^\s*\#/); # skip comments

      ($mass_excl, $charge, $graphlabel, $pep_string, $rest) =
	$line =~ /\s*(\d+\.?\d*)\s+(\d+)\s+(\S+)\s+(\w+)(.*)/;

      ($comment) = $rest =~ /#\s*(.*)/ ;
      # prepare for HTML
      $comment =~ s/&/&amp;/g;
      $comment =~ s/>/&gt;/;
      $comment =~ s/</&lt;/;
      $comment =~ s/\"/&quot;/;
      $comment = "No description" if ($comment eq "");

      foreach $f (@dtafiles) {
	next if ($charge{$f} != $charge);
	next if (abs ($mass{$f} - $mass_excl) > $exclude_tolerance);
	if ($graphlabel{$f}) {
	  $graphlabel{$f} .= "...";
	} else {
	  $graphlabel{$f} = $graphlabel;
	}
			
	if ($comment{$f}) {
	  $comment{$f} .= "<br>";
	  $comment{$f} .= $comment;
	} else {
	  $comment{$f} = $comment;
	}

	if ( $pep_string and $pep_string ne "X" ) {
	  $url = "$displayions?dtafile=$dir/$f&amp;numaxis=1";
	  $url .= "&amp;pep=$pep_string";

	  $comment{$f} .= qq( <a href ="$url" target=_blank>$pep_string</a>);
	  $syn = qx($synopsis "dtafile=$dir/$f" "pep=$pep_string"); 
	  $syn =~ s/Synopsis: //;
	  $syn =~ s/\n//g;

	  ## "Good" hits (>=50%) are in black, which stands out against
	  ## the red text.

	  my ($numerator, $denominator) = $syn =~ m!(\d+)/(\d+)!;
	  $ionpercent = ($denominator == 0 ? 0 : 100 * $numerator/$denominator);
	  $ionpercent{$f} = &max ($ionpercent, $ionpercent{$f});

	  if ($ionpercent >= $maxDIonsPercent) {
	    $comment{$f} .= qq{ <span style="color:black">($syn)</span>};
	  } else {
	    $comment{$f} .= qq{ <span style="color:red">($syn)</span>};
	  }
	} else {
	  # force non-peptide sequence to be unselected	  
	  $ionpercent{$f} = 110;
	}
      }
    }
    close EXCL;
}

# Function to sort data based on different key values.
# New: added toggle sort capability, rico 9/27/97
sub do_html {
  my ($restwidth);
  my %realsort;

    if ($sorttype eq "z") {
      @dtafiles = sort { $charge{$a} <=> $charge{$b} } @dtafiles;

    } elsif ($sorttype eq "inten") {
      @dtafiles = sort { $sum{$a} <=> $sum{$b} } @dtafiles;

    } elsif ($sorttype eq "m/z") {
      foreach $file (@dtafiles) {
	($realsort{$file} = $mz{$file}) =~ s/^(&nbsp;)+//;
      }
      @dtafiles = sort { $realsort{$a} <=> $realsort{$b} } @dtafiles;

    } elsif ($sorttype eq "Description") {
      @dtafiles = sort descriptionsort @dtafiles;

    } elsif ($sorttype eq "ions") {
      foreach $file (@dtafiles) {
	($realsort{$file} = $numions{$file}) =~ s/^(&nbsp;)+//;
	$realsort{$file} =~ s/%//;
      }
      @dtafiles = sort { $realsort{$a} <=> $realsort{$b} } @dtafiles;
    } elsif ($sorttype eq "Dif") {
      @dtafiles =  sort Difsort @dtafiles;
      
    } elsif ($sorttype eq "scans") {
      # already sorted
    } else {    #  $sorttype is "MH+" or unknown
      foreach $file (@dtafiles) {
	    ($realsort{$file} = $mass{$file}) =~ s/^(&nbsp;)+//;
	  }
      @dtafiles = sort { $realsort{$a} <=> $realsort{$b} } @dtafiles;
    }

if ($FORM{"reverse"}) { # add toggle functionality, rico 9/27/97
	if ($FORM{"lastreverse"} eq "reverse") {
		$lastreverse = "";
	} else {
		$lastreverse = "reverse";
		@dtafiles = reverse @dtafiles;
	}
}
	print qq(<INPUT TYPE=HIDDEN NAME="lastreverse" VALUE="$lastreverse">\n);

    sub descriptionsort {
	# comments go in alphabetical order, blank lines sorted last
	($c, $d) = ($comment{$a}, $comment{$b});
	return (-1) if ($c ne "" and $d eq "");
	return (1) if ($c eq "" and $d ne "");
	$c cmp $d;
    }

    sub Difsort { # we want to make sure blanks are sorted last
      ($c, $d) = ($difs{$a}, $difs{$b});
      return (-1) if ($c ne "" and $d eq "");
      return (1) if ($c eq "" and $d ne "");
      $c cmp $d;
    }

    my ($sum, $mass, $comment, $url, $charge, $zcolor, $temp);
    foreach $file (@dtafiles) {
	$charge = $charge{$file};
	$zcolor = $zcolors[ ($charge > 3 ? 2 : $charge - 1) ];

	print qq(<TR VALIGN=TOP>\n<TD><INPUT NAME="selected" TYPE=CHECKBOX VALUE="$file");
	print (" CHECKED") if $selected{$file};
	print ("></TD>\n");

	print <<MIDSECTION;
<TD><TT><span style="color:#$mzcolor">$mz{$file}</span></TT></TD>
<TD><TT><span style="color:#$masscolor">$mass{$file}</span></TT></TD>
<TD><TT><span style="color:#$zcolor">$charge</span></TT></TD>
<TD><TT>$scanurl{$file}</TT></TD>
<TD><TT><span style="color:#$intencolor">$sum{$file}</span></TT></TD>
<TD><TT>$numions{$file}</TT></TD>
<TD><TT>$difs{$file}</TT></TD>
<TD><TT><span style="color:#$commentcolor">$comment{$file}</span></TT></TD>
</TR>

MIDSECTION

   }
   return;
}

##
## This subroutine displays default limits that make a dta selected.
## This can then be changed by the user for easier automation.
##

sub output_autolimits {
  &set_selection_defaults;

  print <<EOM;
<td width=40>&nbsp;</td>
<td valign="top">
<TABLE cellspacing=0 cellpadding=0 border=0>
<tr><td>
<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
	<td width=20><img src="/images/ul-corner.gif" width=10 height=20></td>
	<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Deselect Spectra With</td>
	<td width=20><img src="/images/ur-corner.gif" width=10 height=20></td>
</tr></table>
</td></tr>

<tr><td>
<table cellpadding=0 cellspacing=0 border=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=right>Match Ions:&nbsp;&nbsp;</td> 
		<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;Greater than or equal to <INPUT NAME="maxDIonsPercent" VALUE="$maxDIonsPercent" MAXLENGTH=2 SIZE=2>%&nbsp;</td>
</tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=right>&nbsp;TIC:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor="#f2f2f2">&nbsp;&nbsp;Less than <INPUT NAME="minTic" VALUE="$minTic" MAXLENGTH=10 SIZE=5>&nbsp;MS<sup>2</sup></td>
</tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=right>&nbsp;Ions:&nbsp;&nbsp;</span></td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;Fewer than <INPUT NAME="minIons" VALUE="$minIons" MAXLENGTH=3 SIZE=3>&nbsp;
</tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=right>&nbsp;Intensity:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;Below&nbsp;<INPUT NAME="minIntenPercentile" VALUE="$minIntenPercentile" MAXLENGTH=2 SIZE=2>th percentile</td>
</tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=rignt>&nbsp;Charge States:&nbsp;&nbsp;</td>
	<td bgcolor=#f2f2f class=smalltext>
EOM
  my $i, $v;
  for ($i = 1; $i < $maxZ; $i++) {
    $v = $zUnused[$i] ? "CHECKED" : "";
    print qq(		&nbsp;&nbsp;$i+<INPUT TYPE=CHECKBOX NAME="zUnused" VALUE="$i" $v>\n);
  }
  $v = $zUnused[$maxZ] ? "CHECKED" : "";
  print qq(		&gt;=$maxZ+<INPUT TYPE=CHECKBOX NAME="zUnused" VALUE="$maxZ" $v>&nbsp;</td>\n);

  print <<EOM2;
</tr>
<tr height=18><td class=smallheading bgcolor=#e8e8fa align=right>&nbsp;MH+ Limits:&nbsp;&nbsp;</td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;&nbsp;Min:&nbsp;
		<INPUT NAME="minMass" VALUE="$minMass" MAXLENGTH=5 SIZE=5>&nbsp;Da&nbsp;&nbsp;&nbsp;&nbsp;Max:&nbsp;
		<INPUT NAME="maxMass" VALUE="$maxMass" MAXLENGTH=5 SIZE=5>&nbsp;Da</span></td>
</tr></table>
</td></tr></table>
</td></tr></table>

<TABLE cellspacing=0 cellpadding=0 border=0 width=300>
<tr><td>
<table cellspacing=0 cellpadding=0 bgcolor="#e8e8fa" height=20 width=100%><tr>
	<td width=20><img src="/images/ul-corner.gif" width=10 height=20></td>
	<td width=100% class=smallheading>&nbsp;&nbsp;&nbsp;&nbsp;Tolerance</td>
	<td width=20><img src="/images/ur-corner.gif" width=10 height=20></td>
</tr></table>
</td></tr>

<tr><td>
<table cellpadding=0 cellspacing=0 border=0 width=100% style="border: solid #000099; border-width:1px">
<tr><td bgcolor=#e8e8fa style="font-size:2">&nbsp;</td><td bgcolor=#f2f2f2 style="font-size:2">&nbsp;</td></tr>
<tr height=18>
	<td align="right" class=smallheading bgcolor=#e8e8fa width=33%>&nbsp;Known Ions:&nbsp;&nbsp;</span></td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT NAME="exclude_tolerance" VALUE="$exclude_tolerance" MAXLENGTH=4 SIZE=4>&nbsp;Da&nbsp;</td>
</tr>
<tr height=18>
	<td align="right" class=smallheading bgcolor=#e8e8fa>&nbsp;Difs:&nbsp;&nbsp;</span></td>
	<td class=smalltext bgcolor=#f2f2f2>&nbsp;<INPUT NAME="dif_tolerance" VALUE="$dif_tolerance" MAXLENGTH=4 SIZE=4>&nbsp;Da&nbsp;</td>
</tr>
</table>
</td></tr></table>
<br>
<HR>
EOM2
}

sub hide_selection_defaults {
  my $zUnusedstr = join (", ", @zUnused);

  print <<EOM;
<INPUT TYPE=HIDDEN NAME="minIons" VALUE="$minIons">
<INPUT TYPE=HIDDEN NAME="maxDIonsPercent" VALUE="$maxDIonsPercent">
<INPUT TYPE=HIDDEN NAME="minTic" VALUE="$minTic">
<INPUT TYPE=HIDDEN NAME="minIntenPercentile" VALUE="$minIntenPercentile">
<INPUT TYPE=HIDDEN NAME="zUnused" VALUE="$zUnusedstr">
<INPUT TYPE=HIDDEN NAME="minMass" VALUE="$minMass">
<INPUT TYPE=HIDDEN NAME="maxMass" VALUE="$maxMass">
<INPUT TYPE=HIDDEN NAME="exclude_tolerance" VALUE="$exclude_tolerance">
<INPUT TYPE=HIDDEN NAME="dif_tolerance" VALUE="$dif_tolerance">
EOM
}

##
## if we are called from another program, we call this subroutine, which sets
## the thresholds to their defaults
## Also called by &output_autolimits so we have the defaults in only one place
##

sub set_selection_defaults {
  $minIons = $DEFS_VUDTA{'< x ions'};
  $maxDIonsPercent = $DEFS_VUDTA{'>= x% match to known ions'};
  $minIntenPercentile = $DEFS_VUDTA{'Intensity below xth %ile'};
  $minTic = $DEFS_VUDTA{'Less than x MS2 TIC'};
  my $i;
  for ($i = 1; $i < $maxZ; $i++) {
    $zUnused[$i] = "";
  }
  $zUnused[$maxZ] = "$maxZ";

  $minMass = $DEFS_VUDTA{"MH+ Limits: Min"};
  $maxMass = $DEFS_VUDTA{"MH+ Limits: Max"};
  $dif_tolerance = $DEFS_VUDTA{"Difs Tolerance"};
  $exclude_tolerance = $DEFS_VUDTA{"Known Ions Tolerance"};
}

sub get_selection_defaults {
  # unentered values will be the most liberal

  $minIons = $FORM{"minIons"} || 0;

  # a value over a hundred allows all to pass through:
  $maxDIonsPercent = $FORM{"maxDIonsPercent"};
  $maxDIonsPercent = 110 if (!defined $maxDIonsPercent);

  $minIntenPercentile = $FORM{"minIntenPercentile"} || 0;

  $minTic = (defined $FORM{"minTic"}) ? $FORM{"minTic"} : 0;

  my $i;
  for ($i = 1; $i <= $maxZ; $i++) {
    $zUnused[$i] = $FORM{"zUnused"} =~ /$i/ ? "$i" : "";
  }

  $minMass = $FORM{"minMass"} || 0;
  $maxMass = $FORM{"maxMass"};
  $maxMass = "" if (!defined $maxMass);
  $dif_tolerance = $FORM{"dif_tolerance"} || 0;
  $exclude_tolerance = $FORM{"exclude_tolerance"} || 0;
}

##
## Automatically selects all DTAs but those that match
## the default criteria for deselection (entered by the user on
## the first page).
##

sub auto_select {
  # calculate cutoff intensity
  my $intenThreshold = 0;
  if ($minIntenPercentile != 0) {
    my $index = $numdtas * $minIntenPercentile / 100;
    $index = $numdtas - 1 if ($index >= $numdtas);
    $index = 0 if ($index < 0);

    my @d = sort { $sum{$a} <=> $sum{$b} } @dtafiles;
    $intenThreshold = $sum{$d[$index]};
  }

  my $mass, $z;
  $numsel = 0;
	print "$minTic<br>\n";
  foreach $dta (@dtafiles) {
    next if ($numions{$dta} < $minIons);
    next if ($sum{$dta} < $intenThreshold);
	next if ($sum{$dta} < $minTic);
	($mass = $mass{$dta}) =~ s/^(&nbsp;)+//;
    next if ($mass < $minMass);
    next if (($maxMass ne "") and ($mass > $maxMass));

    $z = $charge{$dta};
    $z = $maxZ if ($z > $maxZ);
    next if ($zUnused[$z]);

    # eliminate good matches to contaminants:
    next if ($ionpercent{$dta} >= $maxDIonsPercent);

    $selected{$dta} = 1;
    $numsel++;
  }
}

##
## &get_selected contains the logic for determining which dtas will
## be selected (that is, have checkboxes checked) on this page
##

sub get_selected {
  ##
  ## $sel determines which files should be selected by default
  ##
  my $sel = $FORM{"selectall"};
  my @sel;

  ##
  ## Automatically select all, some, or no .dta files depending on the
  ## value of $sel.
  ##
  if ($sel =~ /all/i) {  # "All" was pressed
    @sel = @dtafiles;
  } elsif ($sel =~ /none/i) { # "None" was pressed
    @sel = ();
  } elsif ($sel =~ /default/i) { # "Default" was pressed
    # auto_select will alter the necessary variables directly:
    &auto_select;
    return;
  } else {
    @sel = split (", ", $FORM{"selected"});
  }

  $numsel = 0;
  foreach $dta (@sel) {
    $selected{$dta} = 1;
    $numsel++;
  }
}


sub do_graph {

  # Lincoln Stein's great Perl port
  # 	http://www-genome.wi.mit.edu/ftp/pub/software/WWW/GD.html
  # of Thomas Boutell's wonderful gd (gifdraw) C library
  #	http://www.boutell.com/gd/ 
  my ($tickinterval, $a, $x, $i, $f, $l, $label, $labelcolor);
  use GD;

  local $HBUFFER = 30;
  local $VBUFFER = 40;
  local $TOPVBUFFER = 15;

  local $HAVAIL = $HSIZE - (2 * $HBUFFER);
  local $VAVAIL = $VSIZE - (2 * $VBUFFER);

  my $font = gdMediumBoldFont;
  my $tickfont = gdSmallFont;
  local $labelfont = ($] < 5.00400) ? gdSmallFont : gdTinyFont;

  my $TICKLENGTH = 5;

  local $im = new GD::Image($HSIZE, $VSIZE);
  $im->interlaced("true");

  local ($white, $lightblue, $black, $red, $gray, $orange, $darkblue,
	 $darkgreen, $darkred);

  $white = $im->colorAllocate (255, 255, 255);
  $lightblue = $im->colorAllocate (70, 50, 255);
  $black = $im->colorAllocate (0,0,0);
  $red = $im->colorAllocate (255, 0, 0);
  $gray = $im->colorAllocate (80, 80, 80);
  $orange = $im->colorAllocate (255, 127, 0);
  $darkblue = $im->colorAllocate (0, 0, 128);
  $darkgreen = $im->colorAllocate (0, 128, 0);
  $darkred = $im->colorAllocate (100, 0, 0);

  # the first is for charge of +1, the second for +2, etc.
  my @labelcolor = ($darkblue, $darkgreen, $darkred);

  # fill with white
  $im->filledRectangle(0,0, $HSIZE, $VSIZE, $white);

  # Place info at the top
  $im->string($font, $HBUFFER, 0, "Directory name: $dirname", $gray);
	
  $im->string($font, $HSIZE /2, 0, $fancyname, $orange);

  # draw axes:
  $im->line($HBUFFER, $TOPVBUFFER, $HBUFFER, $VSIZE - $VBUFFER, $black);
  $im->line($HBUFFER, $VSIZE - $VBUFFER, $HSIZE - $HBUFFER, $VSIZE - $VBUFFER, $black);

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

  $a = (int ($lowerbound /$tickinterval) + 1) * $tickinterval;
  for ($i =  $a; $i < $upperbound; $i += $tickinterval) {
    $x = $HBUFFER + int ($HAVAIL * ($i - $lowerbound)/$scanlen + 0.5);
    
    $im->line($x, $VSIZE - $VBUFFER, $x, $VSIZE - $VBUFFER + $TICKLENGTH, $black);
    &x_center_normal ($im, $tickfont, $x, $VSIZE - $VBUFFER + $TICKLENGTH, $i, $black);
  }


  
  # label axes:
  &x_center_normal ($im, $font, $HBUFFER, $VSIZE - $VBUFFER + 3 * $TICKLENGTH, $lowerbound, $red);
  &y_center_upright ($im, $font, $HBUFFER - $font->height, $VSIZE - $VBUFFER, "0", $black);
  
  $im->stringUp ($font, $HBUFFER - $font->height, $TOPVBUFFER + 5 * $font->width, &sci_notation($maxsum), $red);
  &x_center_normal ($im, $font, $HSIZE - $HBUFFER, $VSIZE - $VBUFFER + 3 * $TICKLENGTH, $upperbound, $red);


  # graph and label the peaks:
  foreach $file (@dtafiles) {
    $f = $firstscan{$file};
    $l = $lastscan{$file};

    $label = "$mass{$file} $charge{$file} $f-$l";

    $labelcolor = $labelcolor[$charge{$file} - 1];
    $labelcolor = $labelcolor[$#labelcolor] if (!$labelcolor);

    &graph ($im, $f, $l, $sum{$file}, $label, $labelcolor);
  }

  open (PNG, ">$tempdir/$pngfile") || die ("Could not write to $tempdir/$pngfile");
  binmode PNG;
  print PNG $im->png;
  close PNG;
}

sub x_center_normal {
  # given an x on which to CENTER the given font, using same y
  my ($im, $font, $x, $y, $s, $color) = @_;

  my ($w) = $font->width;

  $im->string($font, $x - $w * length($s)/2, $y, $s, $color);
}
sub y_center_upright {
  # given an y on which to CENTER the given font, using same x
  my ($im, $font, $x, $y, $s, $color) = @_;

  my($h) = $font->width;
  $im->stringUp($font, $x, $y + $h * length($s)/2, $s, $color);
}

sub graph {
  my ($im, $firstscan, $lastscan, $sum, $label, $labelcolor) = @_;
  my ($midscan, $mid, $H, $B, $delta, $x, $y);

  $firstscan -= $lowerbound;
  $lastscan -= $lowerbound;
  $midscan = ($firstscan + $lastscan) / 2;
  $B = $lastscan - $firstscan;
  $maxsum = 1 if (!$maxsum); # to prevent divide by zero errors
  $H = $sum/$maxsum;


  # special case if scanlen is zero
  if ($scanlen == 0) {
      $im->string (gdMediumBoldFont, $HBUFFER + 100, $TOPVBUFFER + 50, "This set has only one DTA, of zero width.", $red);
      return;
  }

  $left = $HBUFFER + int ($HAVAIL * $firstscan / $scanlen + 0.5);
  $right = $HBUFFER + int ($HAVAIL * $lastscan / $scanlen + 0.5);

  $mid = $HBUFFER + int ($HAVAIL * $midscan / $scanlen + 0.5);
  $peak = $VSIZE - $VBUFFER - int ($VAVAIL * $H + 0.5);

  # this does triangles:
#	if ($firstscan > 0 && $midscan < $scanlen) {
  $im->line($left, $VSIZE - $VBUFFER, $mid, $peak, $lightblue);
#	}
#	if ($midscan > 0 && $lastscan < $scanlen) {
  $im->line($mid, $peak, $right, $VSIZE - $VBUFFER, $lightblue);
#	}

  $y = $peak - int ($VAVAIL / 3.5);
  $y = $peak + int ($VAVAIL / 3.5) if ($y < $VAVAIL / 4);
  $x = $mid - ($labelfont->height)/2;

  &y_center_upright ($im, $labelfont, $x, $y, $label, $labelcolor) if ($LABELSON);
  my $graphlabel = $graphlabel{$file};
  if ($graphlabel && $graphlabel ne "") {
    $y -= (length ($label)/2 + 3) * $labelfont->width if $LABELSON;
    &y_center_upright ($im, $labelfont, $x, $y, $graphlabel, $red);
  }
}


################ Code for dta_vcr_chr: create list of dtas and define functions
sub dta_vcr_chr_load () {

# total number of dtas displayed in dta-chromatogram
$num_boxes = $#dtafiles + 1;

$dir = "$seqdir/$dirname";

print "<SCRIPT LANGUAGE=\"Javascript\"><!-- \n";
print "var dtas_info = new Array(); var dtas_info_temp = new Array(); \n";

my ($sum, $mass, $comment, $url, $charge, $zcolor, $temp);
$i=0;

foreach $file (@dtafiles) {
	$charge = $charge{$file};
	$zcolor = $zcolors[ ($charge > 3 ? 2 : $charge - 1) ];
	print "dtas_info_temp[$i] = '" . " <TD><TT><span style=\"color:#$mzcolor\"> " . $mz{$file} . " </span></TT></TD><TD><TT><span style=\"color:#$masscolor\"> " . $mass{$file} . " </span></TT></TD><TD><TT><span style=\"color:#$zcolor\"> " . $charge{$file} . " </span></TT></TD><TD><TT> " . $scanurl{$file} . " </TT></TD><TD><TT><span style=\"color:#$intencolor\"> " . $sum{$file} . " </span></TT></TD><TD><TT> " . $numions{$file} . " </TT></TD><TD><TT> " . $difs{$file} . " </TT></TD><TD><TT><span style=\"color:#$commentcolor\"> " . $comment{$file} . "'\n";
	$i++;
}

print <<EOF;

var current_index = 0;
var dtas = new Array();
var dta_vcr_chr;
var num_selected
var elt_ind = new Array($num_boxes);
var file_elts = new Array($num_boxes);

// file_elts will contain all the checkboxes found in dta_chromatogram that are by a dta
var counter = 0;
for (i = 0; i < document.forms[0].elements.length; i++) {
	if (document.forms[0].elements[i].name == "selected") {
		file_elts[counter++] = document.forms[0].elements[i];
	}
}

function get_dtas () {
	dtas.length = 0;
	num_selected = 0; b=0;
	for (i = 0; i < document.forms[0].elements.length; i++)	{
		if (document.forms[0].elements[i].name == "selected") {
			if (document.forms[0].elements[i].checked == 1) {
				dtas[num_selected] = document.forms[0].elements[i].value;
				dtas_info[num_selected] = dtas_info_temp[b];
				num_selected++ ; 
			}
			b++
		}
	}

	// index the _indices_ of file_elts that correspond to checked checkboxes
    counter = 0;
	elt_ind.length = $num_boxes;   // temporary assignment, to make sure there are enough
	for (i = 0; i < file_elts.length; i++)
		if (file_elts[i].checked == true)
			elt_ind[counter++] = i;
	current_index = 0;
	elt_ind.length = counter;
}

function gotoDTA(index) {
	if (index >= dtas.length)
		index = dtas.length - 1;
	if (index < 0)
		index = 0;
	current_index = index;
	
	var new_url = "$displayions?dtafile=$dir/" + dtas[current_index];
	dta_vcr_chr.displayions.location.replace(new_url);

	write_info(current_index);
}

function opendta_vcr_chr() {

	if (dta_vcr_chr && !dta_vcr_chr.closed) {

		dta_vcr_chr.focus();

	} else {

		get_dtas ();
		
		if (num_selected > 0) {
			dta_vcr_chr = open("","dta_vcr_chr","width=940,height=745,resizable");
			dta_vcr_chr.document.open();
			dta_vcr_chr.document.writeln('<HTML><HEAD><TITLE>DTA VCR</TITLE></HEAD>');
			dta_vcr_chr.document.writeln('<FRAMESET ROWS="50,65,*" BORDER=0">');
			dta_vcr_chr.document.writeln('<FRAME NAME="controls" SRC="" SCROLLING=no MARGINHEIGHT=0 MARGINWIDTH=0>');
			dta_vcr_chr.document.writeln('<FRAME NAME="info" SRC="" SCROLLING=no MARGINHEIGHT=0 MARGINWIDTH=0>');
			dta_vcr_chr.document.writeln('<FRAME NAME="displayions" SRC="$displayions?dtafile=$dir/');
			dta_vcr_chr.document.writeln(dtas[0]);
			dta_vcr_chr.document.writeln('&numaxis=1" MARGINHEIGHT=0 MARGINWIDTH=0></FRAMESET></HTML>');
			dta_vcr_chr.document.close();

			dta_vcr_chr.controls.document.open();
			dta_vcr_chr.controls.document.writeln('<HTML><HEAD><TITLE>DTA VCR</TITLE>$stylesheet_javascript</HEAD><BODY><table height=100% width=100%><tr><td align=center><form>');
			dta_vcr_chr.controls.document.writeln('<a href="javascript:parent.opener.gotoDTA(0)"><image src="$webimagedir/vcr_to_beginning.gif" width=30 height=30 border=0></a>&nbsp;&nbsp;');
			dta_vcr_chr.controls.document.writeln('<a href="javascript:parent.opener.gotoDTA(parent.opener.current_index - 1)"><image src="$webimagedir/vcr_back.gif" width=50 height=30 border=0></a>&nbsp;&nbsp;');
			dta_vcr_chr.controls.document.writeln('&nbsp;&nbsp;<a href="javascript:parent.opener.gotoDTA(parent.opener.current_index + 1)"><image src="$webimagedir/vcr_forward.gif" width=50 height=30 border=0></a>');
			dta_vcr_chr.controls.document.writeln('&nbsp;&nbsp;<a href="javascript:parent.opener.gotoDTA(parent.opener.dtas.length - 1)"><image src="$webimagedir/vcr_to_end.gif" width=30 height=30 border=0></a>');
			dta_vcr_chr.controls.document.writeln('</form></td></tr></table></body></html>');
			dta_vcr_chr.controls.document.close();
	 
			write_info(current_index);
		}
	}
}

function write_info(index) {
	dta_vcr_chr.info.document.open();
	dta_vcr_chr.info.document.writeln('<HTML><HEAD>$stylesheet_javascript</HEAD><BODY BGCOLOR=#FFFFFF>');
	dta_vcr_chr.info.document.writeln('<TABLE WIDTH=700 BORDER=0 CELLSPACING=0 CELLPADDING=0><TR VALIGN=TOP><TD></TD>');	

	dta_vcr_chr.info.document.writeln('<TD><FORM NAME="DTA_VCR_CHECKBOX">');
	dta_vcr_chr.info.document.writeln('<INPUT type="checkbox" name="selected" value="' + file_elts[current_index].value + '" checked>');
//    dta_vcr_chr.info.document.writeln(file_elts[current_index]);
	dta_vcr_chr.info.document.writeln('</FORM></TD>');

	dta_vcr_chr.info.document.writeln(parent.dtas_info[index]);
	dta_vcr_chr.info.document.writeln('</TT></TD></TR></table>');
	dta_vcr_chr.info.document.writeln('<div align=right><b>' + (index+1) + ' of ' + (num_selected) + '&nbsp;&nbsp;</b></div>');

	dta_vcr_chr.info.document.writeln('</body></html>');
	dta_vcr_chr.info.document.close();
	
	// if you check or uncheck the checkbox in dta_vcr, make sure the changes are registered in dta_chromatogram
	dta_vcr_chr.info.document.DTA_VCR_CHECKBOX.selected.onclick = update_RS_checkbox;

    // if you check or uncheck the checkbox in dta_chromatogram, make sure the changes are registered in dta_vcr
    update_checkbox();
}

function update_RS_checkbox()
{   
	file_elts[elt_ind[current_index]].checked = dta_vcr_chr.info.document.DTA_VCR_CHECKBOX.selected.checked;
}

// update checkbox in controls
function update_checkbox()
{
	if (dta_vcr_chr.info.document.DTA_VCR_CHECKBOX.selected)
		dta_vcr_chr.info.document.DTA_VCR_CHECKBOX.selected.checked = file_elts[elt_ind[current_index]].checked;
}


// close pop-up windows
function close_popups()
{
	if (dta_vcr_chr)
		if (!dta_vcr_chr.closed)
			dta_vcr_chr.close();
}
onunload = close_popups;

//--></SCRIPT>

EOF
}