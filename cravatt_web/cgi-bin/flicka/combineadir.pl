#!/usr/local/bin/perl

#-------------------------------------
#	Combine-A-Dir,
#	(C)1999 Harvard University
#	
#	W. S. Lane/L. F. Sullivan/B. Guaraldi
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
}
################################################
&cgi_receive();

&MS_pages_header("Dir de Dozen", "#871F78", "tabvalues=Combine-A-Dir&Clone-A-Dir:\"/cgi-bin/cloneadir.pl\"&Delete-A-Dir:\"/cgi-bin/deleteadir.pl\"&Combine-A-Dir:\"/cgi-bin/combineadir.pl\"&Rename-A-Dir:\"/cgi-bin/renameadir.pl\"&Search and Replace:\"/cgi-bin/searchreplace.pl\"");

$fromdirs = $FORM{"fromdirs"};	# source directories
$todir    = $FORM{"todir"};		# target directory
if ((!defined $fromdirs) && (!defined $todir)) {
  &get_alldirs;
  &output_form;
  exit;
}

$operator = $FORM{"operator"};
if (!defined $operator) {
	&error("You must type your initials in the Operator field.");
}
$operator =~ tr/A-Z/a-z/;

$comments = $FORM{"comments"};
&encode_comments("$comments");

$newdirtag = $FORM{"NewDirTag"};	# tag to add to the end of the new directory name
$dtafiles = $FORM{"DataFile"};
$copyouts = $FORM{"CopyOuts"};

# This file contains the two functions used below; clonedir and combinedir.
require "combine_code.pl";
	
my ($newdir, @retval) = &combinedirs($fromdirs, $todir, $newdirtag, $dtafiles, $copyouts, $operator, $comments);	

if((shift @retval) == 1) { #error
	&clone_error (@retval);
} else {
	&clone_success(@retval);
}

# print success message

sub clone_success {
  @msgs = @_;

  my $i;
  foreach $dir (split(", ", $fromdirs)) {
	  $i++;
	  $message .= qq|<li><span class=smallheading>Directory $i:</span> <a href="$viewinfo?directory=$dir">$dir</a><br>\n|;
  }

  print <<EOM;
<div class=normaltext><br>
<image src="/images/circle_1.gif">&nbsp;The directories have been successfully combined.<BR>
<ul>
$message
<li><span class=smallheading>New Directory:</span> <a href="$viewinfo?directory=$newdir">$newdir</a>
<ul>
</div>
EOM

  if (@msgs) {
    print ("<p>The following non-fatal errors were reported:<br>\n");
    print join ("\n", @msgs);
  }

@text = ("Sequest Summary", "Run Sequest", "View DTA Chromatogram");
@links = ( "runsummary.pl?directory=$newdir","sequest_launcher.pl" ,"dta_chromatogram.pl");
&WhatDoYouWantToDoNow(\@text, \@links);

}


sub clone_error {
  $h2msg = shift @_;
  print ("<p></p><span class=largetext style=color:red><b>$h2msg</b></span><div class=normaltext>\n");
  print (join ("\n", @_), "</div>\n");

  &get_alldirs;
  &output_form;
  exit;
}


sub output_form {

$checked{$DEFS_COMBINEADIR{"Dta files to copy"}} = " CHECKED";
$checked{"copyout"} = " CHECKED" if ($DEFS_COMBINEADIR{"Copy Out files?"} eq "yes");

  foreach $dir (@ordered_names) 
  {
    $diroptions .= qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }
  
  print <<EOFORM;

<div>
	
<FORM NAME="mainform" ACTION="$ourname" METHOD=GET>

<TABLE>
<TR ALIGN=LEFT>
<TH><span class="smallheading">1. Pick a directory to provide the info for the new dir:</TH>
</TR>

<TR>
<TD><SPAN CLASS=dropbox>
<SELECT NAME="todir" onBlur="selectEquivalent();" onClick="selectEquivalent();" onKeyUp="selectEquivalent();">
$diroptions
</SELECT>
</SPAN></TD>
</TR>

<TR ROWHEIGHT="7"><TD></TD></TR>

<TR ALIGN=LEFT>
<TH><span class="smallheading">2. Pick a dirtag for the new dir:</TH>
</TR><TR>
<TD>
&nbsp;&nbsp;&nbsp;&nbsp;
_<span style="font-size:4pt"> </span><INPUT NAME="NewDirTag" MAXLENGTH=25 SIZE=10 VALUE="$newdirtag">
</TD>
</TR>

<TR ROWHEIGHT="7"><TD></TD></TR>

<TR ALIGN=LEFT>
<TH><span id="fromheader" class="smallheading">3. Select the dirs to be placed in the new dir:</TH>
</TR>

<TR>
<TD><SPAN CLASS=dropbox>
<SELECT NAME="fromdirs" size=5 multiple onBlur="countSelected();" onClick="this.blur(); this.focus();" onKeyUp="countSelected();">
$diroptions
</SELECT></SPAN></TD>

</TR>
</TABLE>

<br>

<span class="smallheading">Dta files to copy: </span>

<INPUT TYPE=RADIO NAME="DataFile" value="all"$checked{'All'}><span class="smalltext">All</span>
<INPUT TYPE=RADIO NAME="DataFile" value="selected"$checked{'Selected'}><span class="smalltext">Selected</span>
&nbsp;&nbsp;&nbsp;
<span class="smallheading">Copy Out files? </span>
<INPUT TYPE=checkbox NAME="CopyOuts" VALUE="yes"$checked{'copyout'}>

<br><br>

<span class="smallheading">Comments</Span><span class="smalltext"> (to append to old comments):</span><BR>
<tt><TEXTAREA NAME="comments" COLS=50 ROWS=5 MAXSIZE=240 WRAP></TEXTAREA></tt>

<br><br>

<span class="smallheading">Operator:</span> <INPUT NAME="operator" SIZE=3 MAXLENGTH=3>&nbsp; <INPUT TYPE=SUBMIT CLASS=button VALUE="Combine">

&nbsp;<a href="$webhelpdir/help_$ourshortname.html">Help</a>

</FORM>
</div>

<script language="Javascript">
<!--
	var oldEquivalent = 0;

	function countSelected() {
		var numberselected = 0;
		var i;
		for (i = 0; i < document.mainform.fromdirs.options.length; i++) {
			if (document.mainform.fromdirs.options[i].selected == true) {
				numberselected++;
			}
		}
		document.all.fromheader.innerText = "3. Select the dirs to be placed in the new dir: (" + numberselected + " selected)";
	}

	function selectEquivalent() {
		document.mainform.fromdirs.options[oldEquivalent].selected = false;
		document.mainform.fromdirs.options[document.mainform.todir.selectedIndex].selected = true;
		oldEquivalent = document.mainform.todir.selectedIndex;
		countSelected();
	}

	document.mainform.fromdirs.options[0].selected = true;

//-->
</script>

EOFORM

}


sub error {

	print <<EOF;

<span class=smallheading>Error:</span><br>
<div>
@_
</div>
</body></html>
EOF

	exit 0;

}
