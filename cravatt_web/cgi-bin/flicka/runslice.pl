#!/usr/local/bin/perl

#-------------------------------------
#	RunSlice,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker/T.A. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# this is adapted from fastamaka, thomas 1 may 1998
# modified by Tim Vasil (April 2000) --> append & autoindexing enhancements

$MAX_PEPTIDES = 50;

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
require "fasta_include.pl";

&cgi_receive;

&MS_pages_header ("Db Slice", "#6F4242");
print"<hr>\n";

$source = $FORM{"source"};
unless ($source) {
    &output_form;
    exit;
}

# I just want you all to know that this is NOT secure
if ($FORM{"writebehavior"} eq "writeover") {
    $openmethod = ">";
} else {
    # by default append
    $openmethod = ">>";
}

$name = $FORM{"name"};
if ($name =~ m/^other/i && $name !~ m/\.fasta$/) {
    $name = $FORM{"other"};
    $name =~ s/\s//g;
    if (!defined $name or $name eq "") {
        $name = "generic_database_" . $$;
    }
    if ($name !~ /.fasta$/) {
        $name .= ".fasta";
    }
}

$append_name = $FORM{"append_name"};
$useappend = $FORM{"useappend"};

# atomic open check
if (!open (FASTA, $openmethod . "$dbdir/$name")) {
    &error ("Could not write to file $name.\n");
}
close FASTA;

$logic1 = $FORM{'logic1'};
$logic2 = $FORM{'logic2'};
$logic3 = $FORM{'logic3'};
$search1 = $FORM{"search1"}; # programming for plainness
$search2 = $FORM{"search2"};
$search3 = $FORM{"search3"};

$i=0;
if ($search1) {    
    $search[$i]->{'logic'}=$logic1;
	# replace the metacharacters with a backslash in front
	$_ = $search1;
	s/\|/\\\|/g; s/\\/\\\\/g; s/\*/\\\*/g; s/\+/\\\+/g; s/\?/\\\?/g; s/\(/\\\(/g; s/\)/\\\)/g; s/\./\\\./g; s/\^/\\\^/g; s/\$/\\\$/g; s/\[/\\\[/g; s/\{/\\\{/g;
	$search1 = $_;
    $search[$i]->{'match'}=$search1;
    $i++;
}
if ($search2) {
    $search[$i]->{'logic'}=$logic2;
	# replace the metacharacters with a backslash in front
	$_ = $search2;
	s/\|/\\\|/g; s/\\/\\\\/g; s/\*/\\\*/g; s/\+/\\\+/g; s/\?/\\\?/g; s/\(/\\\(/g; s/\)/\\\)/g; s/\./\\\./g; s/\^/\\\^/g; s/\$/\\\$/g; s/\[/\\\[/g; s/\{/\\\{/g;
	$search2 = $_;
    $search[$i]->{'match'}=$search2;
    $i++;
}
if ($search3) {
    $search[$i]->{'logic'}=$logic3;
	# replace the metacharacters with a backslash in front
	$_ = $search3;
	s/\|/\\\|/g; s/\\/\\\\/g; s/\*/\\\*/g; s/\+/\\\+/g; s/\?/\\\?/g; s/\(/\\\(/g; s/\)/\\\)/g; s/\./\\\./g; s/\^/\\\^/g; s/\$/\\\$/g; s/\[/\\\[/g; s/\{/\\\{/g;
	$search3 = $_;
    $search[$i]->{'match'}=$search3;
}

if (!open(SRC, "$dbdir/$source")) {
    &error("Could not open $source.\n");
}

close SRC;

#Changed by SDR(08/22/01) Made my at front since this var should be local
#SDR: Since we are sending this to cmdslice, it expects to see a variable inserted
#	  for contaminants and before it was just getting a blank, and in a command line
#	  such as run_in_background this indicated there was no argument for it.
#	  Note, this fix will not work correctly now if append_name == no
my $contaminants = ($useappend) ? $append_name : "0";
$autoindex = (defined($FORM{"autoindex"}) ? "1" : "0");

if ($openmethod eq ">>") {
    $append = "1";
} else {
    $append = "0";
}

# This piece of code needs to wait for the database to be built before continuing onto the success page so that
# the later code will retrieve the correct file size of the database (sdr 08/29/01)
#&run_in_background("$perl $cgidir/cmdslice.pl $source $name $append $contaminants $autoindex \"$logic1\" \"$search1\" \"$logic2\" \"$search2\" \"$logic3\" \"$search3\"");

$procobj = &run_silently_in_background("$perl $cgidir/cmdslice.pl $source $name $append $contaminants $autoindex \"$logic1\" \"$search1\" \"$logic2\" \"$search2\" \"$logic3\" \"$search3\"");
until ($procobj->Wait(1000)) {
	print "." or &abort($procobj);
}
&success_page;
exit;



sub success_page {
  PrintDbCreationResults(db			=> $name,
						 include	=> (($useappend) ? $append_name : ''),
						 appended	=> !($FORM{"writebehavior"} eq "writeover"),
						 copyhosts	=> (($FORM{"copytohosts"}) ? $DEFAULT_COPY_HOSTS : ''),
						 autoindex	=> $FORM{"autoindex"},
						 dontindex  => '0');
}


sub error {
	print "<br><span style=\"color:#800000\">", @_, "</span>";
	&output_form("error");
	exit;
}

sub output_form {
  my $fasta_info, $peptide;

  my $othertitle = "Other (below)";
  my $name = $othertitle;

  my $other_name = $DEFS_DBSLICE{"new database name"};

  $checked{$DEFS_DBSLICE{"append/write over"}} = " CHECKED";
  $checked{"useappend"} = ($DEFS_DBSLICE{"Append database"} eq "yes") ? " checked" : "";
  $checked{"autoindex"} = ($DEFS_FASTAMAKA{"Auto-index headers"} eq "yes") ? " checked" : "";
  $checked{"copytohosts"} = ($DEFS_FASTAMAKA{"Copy to hosts"} eq "yes") ? " checked" : "";

  my $append_name = $DEFS_FASTAMAKA{"Database to append"};

  # if true, requires us to include the old values.
  if (defined $_[0]) {
    $fasta_info = $FORM{"fasta_info"};
    $name = $FORM{"name"};
    $other_name = $FORM{"other"};
    $checked{"useappend"} = " checked" if $FORM{"useappend"};
	$checked{"autoindex"} = " checked" if $FORM{"autoindex"};
	$append_name = $FORM{"append_name"};
  }
  $avgCHECKED = "CHECKED" if ($monoCHECKED eq "");

  $name = $DEFS_DBSLICE{"new database name"} if (!defined $name or $name eq "");
  my (@files);

  print <<ENDOFFORM2;
<FORM NAME="form" ACTION="$ourname" METHOD=POST>
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>

<TR ALIGN=LEFT>
<TR>
<TD align=right><span class=smalltext><b>Source database:</b>&nbsp;</span></TD><TD>
ENDOFFORM2

ListDatabases("source", $DEFAULT_DB);

  print <<ENDOFFORM3;
</TD></TR><TD valign=top align=right><span class=bigtext>&nbsp;</span><span class=smalltext><b>Search pattern:&nbsp;</b></span></TD>
<td>
<table CELLSPACING=0 CELLPADDING=0 BORDER=0><tr>
<TD align=right><span class="dropbox"><select name="logic1">
<option value="AND" selected>CONTAINS
<option value="NOT">DOES NOT CONTAIN</select></span>&nbsp;</td><TD><INPUT SIZE=72 NAME="search1" VALUE="$search1"></TD>
</TR>
<TR>
<td align=right><span class="dropbox"><select name="logic2">
<option value="OR" selected>OR CONTAINS
<option value="AND">AND CONTAINS
<option value="NOT">DOES NOT CONTAIN</select></span>&nbsp;</td><td><input size=72 NAME="search2" VALUE="$search2"></TD>
</TR>
<TR>
<td align=right><span class="dropbox"><select name="logic3">
<option value="OR" selected>OR CONTAINS
<option value="AND">AND CONTAINS
<option value="NOT">DOES NOT CONTAIN</select></span>&nbsp;</td><td><input size=72 name="search3" VALUE="$search3"></TD>
</TR></table></td></tr>

<TR><TD colspan="2">&nbsp;</TD></TR>
<TR ALIGN=LEFT>
<TD align=right><span class=smalltext><b>Output database:&nbsp;</b></span></TD><TD>
<TABLE WIDTH=100% BORDER=0 CELLSPACING=0 CELLPADDING=0><TR>
  <TD>
  <TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR><TD>
ENDOFFORM3

ListDatabases("name", $name, $othertitle);

print <<ENDOFFORM5;
      &nbsp;&nbsp;
	  <TD><INPUT TYPE=RADIO NAME="writebehavior" VALUE="append"$checked{"Append"}></TD>
	  <TD><span class=smalltext><b><layer top=-5>Append</layer>&nbsp;&nbsp;</b></span></TD>
      <TD><INPUT TYPE=RADIO NAME="writebehavior" VALUE="writeover"$checked{"Write Over"}></TD>
	  <TD><span class=smalltext><b>Overwrite</b></span></TD>
    </TR></TABLE></TD>
  <TD ALIGN="RIGHT">
  <TABLE><TR>
    <TD><INPUT TYPE=CHECKBOX NAME="autoindex"$checked{"autoindex"}></TD>
	<TD>
	  <b><span class=smalltext> Auto-index FASTA headers</b></span>
	</TD>
  </TR></TABLE>
</TD></TR></TABLE>
</TD>
</TR>

<TR ALIGN=LEFT>
<TD align=right><NOBR><span class=smalltext><b>Name (if "Other"):&nbsp;</b></span></NOBR></TD>
<TD>
<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=100%><TR>
  <TD><INPUT SIZE=29 VALUE="$other_name" NAME="other"></TD>
  <TD>
    <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0><TR>
	  <TD><INPUT TYPE=CHECKBOX NAME="useappend"$checked{"useappend"}></TD>
	  <TD><span class=smalltext><b>Also include:&nbsp;</b></span></TD>
	  <TD>
ENDOFFORM5

ListDatabases("append_name", $append_name);

if ($multiple_sequest_hosts) {
	$copyA = "<INPUT TYPE=CHECKBOX NAME=\"copytohosts\"$checked{'copytohosts'}>";
	$copyB = '<span class=smalltext><b>Copy to hosts&nbsp;</b></span>';
} else {
	$copyA = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	$copyB = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
}

print <<EOF;
    </TD></TR></TABLE>
    <TD align=right>
      <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0><TR>
	  <TD>$copyA</TD>
      <TD>$copyB</TD></TR></TABLE>
	</TD>
  </TR></TABLE></TD></TR>
<TR><TD COLSPAN=2>&nbsp;</TD></TR>
<TR><TD></TD><TD>
<INPUT TYPE=SUBMIT CLASS=button VALUE="FASTA me" onClick="return CheckForm()">
<INPUT TYPE=RESET CLASS=button VALUE="Clear">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="$webhelpdir/help_$ourshortname.html">Help</a></TD></TR>
</TABLE></FORM>
<SCRIPT>
function CheckForm() {
	var controls = document.form;
	var OtherFile = controls.name.options[controls.name.selectedIndex].text;

	// is some search specified?
	if (!Trim(controls.search1.value + controls.search2.value + controls.search3.value).length) {
		controls.search1.focus();
		alert("Please specify a search pattern.");
		return false;
	}
	// if a specified filename is required, is it provided?
	if (OtherFile) {
		// format filename
		controls.other.value = GetValidFilename(controls.other.value.replace(/\\s/g, ""));
		
		if (controls.other.value == "") {
			controls.other.focus();
			alert("You must specify a filename.");
			return false;
		}
		if (!controls.other.value.match(/.fasta\$/)) {
			controls.other.value += ".fasta";
		}
	}

	// if overwriting a file, is this ok?
	if (controls.writebehavior[1].checked) {
		if (OtherFile=="$othertitle") {	// "Other" file
			for (var i=0; i < controls.name.length; i++) {
				if (controls.name.options[i].text == controls.other.value) {
					if (!VerifyOverwrite(controls.other.value)) { return false; } else { break; }
				}
			}
		} else {	// file in list (no searching required)
			if (!VerifyOverwrite(OtherFile)) { return false; }
		}
	}

	// all checks succeeded
	return true;
}
function Trim(text) { return text.replace(/^\\s*|\\s*\$/g, ""); }
function VerifyOverwrite(filename) {
	return confirm('The file "' + filename + '" already exists and you have selected the "Overwrite" option.\\n\\nDo you want to proceed and erase all existing data in this file?');
}
function GetValidFilename(text) { return text.replace(/['":?\\057\\134*<>|]/g, ""); }
</SCRIPT>
</BODY></HTML>
EOF
}

# ListDatabases
# Purpose:		Prints a list of database files
# Arguments:	<form name for list>, <default file (will be selected)>, <an additional entry (i.e. "Other:")>
sub ListDatabases {
	my ($list_name, $default_file, $othertitle) = @_;
    opendir (DBDIR, "$dbdir") || { print ("Could not open $dbdir!<p>\n") &&
				       return };
    @files = grep { /^[^\.].*\.fasta$/ } readdir (DBDIR);
    closedir DBDIR;

    @files = sort { $a cmp $b } @files;
	@files = ($othertitle, @files) if ($othertitle);

    print ("<span class=dropbox><SELECT NAME=\"$list_name\">\n");
    foreach $file (@files) {
		print ("<OPTION");
		print (" SELECTED") if ($file eq $default_file);
		print (">$file\n");
    }
    print ("</SELECT></span>\n");

}
