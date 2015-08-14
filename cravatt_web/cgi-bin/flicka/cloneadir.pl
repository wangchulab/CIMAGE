#!/usr/local/bin/perl

#-------------------------------------
#	Clone-A-Dir,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
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

&MS_pages_header("Dir de Dozen", "#871F78", "tabvalues=Clone-A-Dir&Clone-A-Dir:\"/cgi-bin/cloneadir.pl\"&Delete-A-Dir:\"/cgi-bin/deleteadir.pl\"&Combine-A-Dir:\"/cgi-bin/combineadir.pl\"&Rename-A-Dir:\"/cgi-bin/renameadir.pl\"&Search and Replace:\"/cgi-bin/searchreplace.pl\"");

$directory = $FORM{"directory"};

if (!defined $directory) {
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



if (($FORM{"DataFile"} eq "selected") && (-f "$seqdir/$directory/selected_dtas.txt")) {
  if (open (SEL, "$seqdir/$directory/selected_dtas.txt")) {
    while ($line = <SEL>) {
      chomp $line;
      push (@dtafiles, $line);
    }
  }
}

$newdirtag = $FORM{"NewDirTag"};
$copyouts = $FORM{"CopyOuts"};

# remove initial underscore if it exists.
$newdirtag =~ s/^_//;
$newdirtag =~ s/\s//g;

# remove shell meta-characters
$newdirtag =~ tr/A-Z/a-z/;
$newdirtag =~ tr/a-z0-9\-_//cd;

if ($newdirtag eq "") {
  &clone_error ("NewDirTag is blank.", "Please enter a tag that will be appended to the new directory's name.");
}

require "clone_code.pl";

my ($newdir, @retval) = &clonedir ($directory, $newdirtag, \@dtafiles, $copyouts, $operator, $comments);

if ((shift @retval) == 0) {  # success
  &clone_success (@retval);
} else {
  &clone_error (@retval);
}

# print success message

sub clone_success {
  @msgs = @_;

	print <<EOM;
	<p>
	<div class="normaltext">

	<image src="/images/circle_1.gif">&nbsp;Directory clone was successful.
	<ul>
	<li><span class="smallheading">Old Directory: </span><a href="$viewinfo?directory=$directory">$directory</a><br>
	<li><span class="smallheading">New Directory: </span><a href="$viewinfo?directory=$newdir">$newdir</a><br>
	</ul>
	</div>
EOM
	
	@text = ("Run Sequest","Create DTA", "Sequest Summary","View DTA Chromatogram");
	@links = ("sequest_launcher.pl","create_dta.pl","runsummary.pl?directory=$newdir","dta_chromatogram.pl");
	&WhatDoYouWantToDoNow(\@text, \@links);

	if (@msgs) {
		print ("<p>The following non-fatal errors were reported:<br>\n");
	    print join ("\n", @msgs);
	}
}

sub clone_error {
  $h2msg = shift @_;
  print ("<h2>$h2msg</h2><div>\n");
  print (join ("\n", @_), "</div>\n");

  &get_alldirs;
  &output_form;
  exit;
}


sub output_form {

$checked{$DEFS_CLONEADIR{"Dta files to copy"}} = " CHECKED";
$checked{"copyout"} = " CHECKED" if ($DEFS_CLONEADIR{"Copy Out files?"} eq "yes");

  print <<EOFORM;
<div>

<FORM ACTION="$ourname" METHOD=GET>
<TABLE>
<TR ALIGN=LEFT>
<TH><span class="smallheading">Directory to Clone:</span></TH>

<TH><span class="smallheading">&nbsp;&nbsp;&nbsp;NewDirTag:</span></TH>
</TR>

<TR>
<TD><SPAN CLASS=dropbox><SELECT NAME="directory">

EOFORM
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

  print <<EOFORM;
</SELECT></SPAN></TD>

<TD>_<span style="font-size:4pt"> </span><INPUT NAME="NewDirTag" MAXLENGTH=25 SIZE=10 VALUE="$newdirtag"></TD>
</TR>
</TABLE>

<br>

<span class="smallheading">Comments</span> <span class="smalltext">(to append to old comments):</span><BR>
<tt><TEXTAREA NAME="comments" COLS=50 ROWS=5 MAXSIZE=240 WRAP></TEXTAREA></tt>

<br><br>

<span class="smallheading">Dta files to copy: </span>

<INPUT TYPE=RADIO NAME="DataFile" value="all"$checked{'All'}><span class="smalltext">All</span>
<INPUT TYPE=RADIO NAME="DataFile" value="selected"$checked{'Selected'}><span class="smalltext">Selected</span>
&nbsp;&nbsp;&nbsp;
<span class="smallheading">Copy Out files?</span> 
<INPUT TYPE=checkbox NAME="CopyOuts" VALUE="yes"$checked{'copyout'}>
<br><br>
<span class="smallheading">Operator:</span> <INPUT NAME="operator" SIZE=3 MAXLENGTH=3>&nbsp; <INPUT TYPE=SUBMIT CLASS=button VALUE="Clone Me">
</FORM>
</div>
EOFORM
}


sub error {

	print <<EOF;

<H3>Error:</H3>
<div>
@_
</div>
</body></html>
EOF

	exit 0;

}
