#!/usr/local/bin/perl

#-------------------------------------
#	FastaMaka,
#	(C)1997-2000, 1998 Harvard University
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
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
require "fasta_include.pl";

################################################
# the following are the 20 normal amino acids except K - Arginine and I -
# isoleucine, because for the purposes of this program I and L are
# indistinguishable; and K never occurs in the middle of a peptide, Q never
# appears at the end
#
# ie. this is pretty much what you'd expect when dealing with tryptic peptides
# except that we don't account for the possibility of KP in the peptide.

@amino_acids = ('A', 'C', 'D', 'E', 'F', 'G', 'H', 'L', 'M', 'N', 'P', 'Q',
		'R', 'S', 'T', 'V', 'W', 'Y');

#$MAX_PEPTIDES = 300000; # maximum number of peptides to output to a database
$MAX_PEPTIDES = 1000000; # maximum number of peptides to output to a database

&cgi_receive;

#while (($k, $v) = each %FORM) { print STDERR "$k=$v\n"; }

$UsePermuta = $FORM{"permuta"};
if ($UsePermuta) {
	$script_color = '#e02090';
	&MS_pages_header ("FastaMaka Permuta", $script_color);
	print"<hr>\n";
} else {
	$script_color = '#8020e0';
	&MS_pages_header ("FastaMaka", $script_color);
	print"<hr>\n";
}

$date = $starttime = localtime(time);

# I just want you all to know that this is NOT secure
if ($FORM{"writebehavior"} eq "writeover") {
    $openmethod = ">";
} else {
    # by default append
    $openmethod = ">>";
}

$peptide = $FORM{"peptide"};

$raw = $peptide;
if (!defined $peptide) {
	&output_form;
	exit;
}
$peptide = "" if (exists $FORM{"clear"});
 
# strip first line if in FASTA database format
#$fasta_info = $1 if ($peptide =~ s/^>(.*)\n//);

$fasta_info = $FORM{"fasta_info"};
$fasta_info =~ s/^\s*>//;

# check if first line is a FASTA-format header
if ($peptide =~ s/^\s*>(.*)[\r\n]+//) {
  $fasta_info = $1;
}

$fasta_info =~ s/^\s*//;

if ($fasta_info eq "") {
	$fasta_info = "Web$$ pepseq at $date";
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

$mass = $FORM{"mass"};
if ($mass) {
    $tolerance = $FORM{"tolerance"};
    $masstype = $FORM{"MassType"};
    $lowmass = $mass - $tolerance;
    $highmass = $mass + $tolerance;
}

$peptide =~ tr/a-z/A-Z/;

# Text lines are ended with "\r\n"; make this "normal" Unix CRs:
$peptide =~ s!\r\n!\n!g;

if (!$UsePermuta) {
  $peptide =~ s!\s!!g;

  if ($peptide eq "") {
    &error("Please enter a <b>non-empty",
	   "</b> sequence.<p>\n");
  }
  if ($peptide =~ /[^A-Z]/) {
  &error("<b>Please use only letters and",
         "whitespace, or try <a href=\"$fastamaka?permuta=yes\">FastaMaka Permuta</a>.</b><p>\n");
  }

  if (!open (FASTA, $openmethod . "$dbdir/$name")) {
    &error ("Could not write to file $name.\n");
  }

  print FASTA (">$fasta_info\n");
  
  # wrap every 60 letters or so
  $peptide =~ s!(.{60})!$1\n!g;
  print FASTA "$peptide\n\n";

  $pepcount = 1;

  if ($useappend and $append_name ne "(None)" and $append_name ne "" and open (CONTAM, "$dbdir/$append_name")) {
    print FASTA while (<CONTAM>);
    close CONTAM;
    $contam_added = 1;
  }
  close FASTA;

  &success_page();
  exit();
}

# transform all I's to L's and all K's to Q's
# (we'll make C-terminal Q's K's later).

$peptide =~ tr/IK/LQ/;

$peptide =~ s/\s+$//;
@regexps = split ("\n", $peptide);
$peptide =~ s!\s!!g;

if ($peptide eq "") {
	&error("Please enter a <b>non-empty",
		"</b> sequence.<p>\n");
}

for ($i=0; $i <= $#regexps; $i++) {
	$regexps[$i] =~ s/\s//g;

	if ($regexps[$i] =~ m#\[[^\]]*[\{\}][^\]]*]\]# ) {
		&error ("Peptide sequence $regexps[$i] embeds curly brackets",
			" in square bracketed enclosures. Not allowed\n");
	}
	if (&brackets_outta_order ($regexps[$i])) {
		&error ("Peptide sequence $regexps[$i] has unmatched brackets",
			"or brackets out of order. Not allowed\n");
	}

	# sanity check entered peptides via really messy reg expns
	# remove nested {}
	$regexps[$i] =~ s#\{([^\}]*)\{([^\}]*)\}([^\}]*)\}#$1$2$3#g;
	# reduce [*?*] to ?
	$regexps[$i] =~ s#\[[^\]]*\?[^\]]*]\]#?#g;
	# reduce [A] to A and [] to nothing
	$regexps[$i] =~ s#\[([^\]]?)\]#$1#g;
	# remove nested []
	$regexps[$i] =~ s#\[([^\]]*)\[([^\]]*)\]([^\]]*)\}#$1$2$3#g;

	if ($regexps[$i] eq "") {
		splice (@regexps, $i, 1);
		$i--;
	}
}


if ($peptide =~ m#[^A-Z\s\?\[\]\{\}]#) {
	&error ("<b>The previously entered peptide,</b> <tt>$peptide</tt>,",
		" <b>contains characters other than letters and carriage ",
		"returns.</b>\n");
	exit;
}

if (!open (FASTA, $openmethod . "$dbdir/$name")) {
    &error ("Could not write to file $name.\n");
}
    
$pepcount = 0;
$cys_add = 0;
$longmasstype = $masstype ? "mono" : "average";

sub print_pept {
    my $pep = $_[0];
    my $m = &mw ($longmasstype, $cys_add, $pep) + 1;
    return if ($mass && ($m < $lowmass or $m > $highmass));

    $pep =~ s/Q$/K/; # C-terminal Q are really K

    $pepcount++;
    print FASTA (">", $pepcount, $fasta_info, "\n");
    
    # wrap every 60 letters or so
    $pep =~ s!(.{60})!$1\n!g;
    print FASTA "$pep\n\n";
}

# here we expand each regexpeptide to a real peptide
$num = 0;
foreach $elt (@regexps) {
    $num += &number_outputs ($elt);
}
if ($num > $MAX_PEPTIDES) {
   &error ("$raw would produce too many ($num) peptide sequences",
	" (over $MAX_PEPTIDES). Try using fewer question marks and square",
	" bracket pairs, and minimize the choices in bracket pairs.");
}

foreach $elt (@regexps) {
    $count = $elt =~ tr#\?\[#\?\[#;

    $leftbr = $elt =~ tr#\{#\{#;
    $rightbr = $elt =~ tr#\}#\}#;
    if (!$leftbr and !$rightbr) {
	$count ? &expand ($elt) : &print_pept ($elt);
	next;
    }

    if ($leftbr > 1 or $rightbr > 1) {
	&error ("$elt has too many curly brackets - maximum one set per",
		" peptide sequence."); 
    }
    if ((($leftbr - $rightbr) != 0) || ($elt =~ m!\}.*\{!)) {
        &error ("$elt has mismatched brackets.");
    }

    ($front, $mid, $back) = $elt =~ m!^(.*)\{(.*)\}(.*)$!;
    if (&letter_length ($mid) != 2) {
	&error ("$elt has too many letters between brackets: ",
		"only a dipeptide juggle is allowed.");
    }
    $pep1 = $front . $mid . $back;
    $pep2 = $front . &letter_reverse ($mid) . $back;
    if ($count) {
	&expand ($pep1, $pep2);
    } else {
	&print_pept ($pep1);
	&print_pept ($pep2);
    }
}


if ($useappend and $append_name ne "(None)" and $append_name ne "" and open (CONTAM, "$dbdir/$append_name")) {
  print FASTA while (<CONTAM>);
  close CONTAM;
  $contam_added = 1;
}
close FASTA;

&success_page();
exit();

sub success_page {
  PrintDbCreationResults(entries	=> $pepcount,
						 db			=> $name,
						 include	=> (($useappend) ? $FORM{"append_name"} : ''),
						 appended	=> !($FORM{"writebehavior"} eq "writeover"),
						 copyhosts	=> (($FORM{"copytohosts"}) ? $DEFAULT_COPY_HOSTS : ''),
						 autoindex	=> $FORM{"autoindex"});

$endtime = localtime(time);
print <<SUCCESS;
<p>
<span class="smalltext" style="color:#8E236B">Starting time: $starttime</span>
<br>
<span class="smalltext" style="color:#8E236B">Ending time: $endtime</span>
SUCCESS
}


sub error {
	print "<span style=\"color:#800000\">", @_, "</span>";
	&output_form("error");
	exit;
}

# returns "true length" of a regexp segment; eg "A[BFG]" has length 2
sub letter_length {
	local ($seq) = $_[0];
	$seq =~ s#\[[^\]]*\]#p#g;
	$seq =~ tr#\}\{##;
	return (length ($seq));
}

# returns "true reversal" of a regexp segment; eg "A[BFG]" goes to "[BFG]A"
sub letter_reverse {
	local ($seq) = $_[0];
	$seq = reverse ($seq);
	$seq =~ tr@\]\[\}\{@\[\]\{\}@; # swap all brackets
	return $seq;
}

# just checks order, not embeddedness
sub brackets_outta_order {
	local ($seq) = $_[0];
	local ($ns, $nc); # counters for number of curly and square brackets
	local ($i, $l, $a);
	$l = length ($seq);

	while ($i < $l) {
		$a = substr ($seq, $i, 1);
		$i++;
		$nc++ if ($a eq "{");
		$nc-- if ($a eq "}");
		$ns++ if ($a eq "[");
		$ns-- if ($a eq "]");

		return (-1) if ($ns < 0 or $nc < 0);
	}
	return (0) if ($ns == 0 and $nc == 0);
	return (-1);
}

sub number_outputs {
	local ($pep) = $_[0];
	local ($num, $pos, $pos2);

	$num = ($#amino_acids + 1) ** ($pep =~ tr#\?##);

	# take {} into account
	while (1) {
	    $pos = index ($pep, "{");
	    last if ($pos == -1);
	    $pos2 = index ($pep, "}", $pos);
	    last if ($pos2 == ($pos -1));

	    $num *= &letter_length (substr ($pep, $pos + 1, $pos2 - $pos -1));
	    $pep =~ s#\{(.*?)\}#$1#;
	}

	# take [] into account
	while (1) {
	    $pos = index ($pep, "[");
	    last if ($pos == -1);
	    $pos2 = index ($pep, "]", $pos);
	    last if ($pos2 == ($pos - 1));
	    $num *= ($pos2 - $pos - 1);
	    $pep =~ s#\[.*?\]##;
	}
	return ($num);
}

# currently expands question marks and square brackets
# NB: code is duplicated for speed. It could be more concise for readability,
# but this is by far the most commonly executed subroutine. Speed
# improvements welcome.

sub expand {
    # "my" should be faster than "local"
    my $pep;
    my ($pos, $pos2, $left, $right);
    my (@letters);

    # reverse the order; look for brackets first, then question marks
    while ($pep = shift) {
	if ($pep !~ m#[\?\[\]]#) {
	    &print_pept ($pep);
	    next;
	}

	$pos = index ($pep, "[");
	if ($pos != -1) {
	    $pos2 = index ($pep, "]", $pos);
	    &error ("parsing error: missing right bracket") if ($pos2 == ($pos - 1));
	    $left = substr ($pep, 0, $pos);
	    $right = substr ($pep, $pos2 + 1) unless ($pos2 == length ($pep));

	    @letters = split ("", substr ($pep, $pos + 1, $pos2 - $pos - 1));
	    if ($right !~ m#[\?\[\]]# and $left !~ m#[\?\[\]]#) {
		foreach $let (@letters) {
		    &print_pept ($left . $let . $right);
		}
	    } else {
		foreach $let (@letters) {
		    &expand ($left . $let . $right);
		}
	    }
	} else {     # no brackets, look for question marks
	    $pos = index ($pep, "?");
	    if ($pos != -1) {
		$left = substr ($pep, 0, $pos);
		$right = substr ($pep, $pos + 1) unless ($pos == length ($pep));

		if ($right !~ m#\?# and $left !~ m#\?#) {
		    foreach $let (@amino_acids) {
			&print_pept ($left . $let . $right);
		    }
		} else {
		    foreach $let (@amino_acids) {
			&expand ($left . $let . $right);
		    }
		}
	    }
	}
    }
}


sub output_form {
  $checked{$DEFS_FASTAMAKA{"append/write over"}} = " CHECKED";
  $checked{"useappend"} = ($DEFS_FASTAMAKA{"Append database"} eq "yes") ? " checked" : "";
  $checked{"autoindex"} = ($DEFS_FASTAMAKA{"Auto-index headers"} eq "yes") ? " checked" : "";
  $checked{"copytohosts"} = ($DEFS_FASTAMAKA{"Copy to hosts"} eq "yes") ? " checked" : "";

  my $fasta_info, $peptide;
  my $ignoreCHECKED, $mass;
  my $tolerance = $DEFS_FASTAMAKA{"MH+ tolerance"};  # default value for mas search tolerance

  my $ignoreCHECKED;

  my $monoCHECKED, $avgCHECKED;
  if ($DEFS_FASTAMAKA{"mono/average"} eq "Monoisotopic") {
	$monoCHECKED = "CHECKED", $avgCHECKED = "";
  } else {
	$monoCHECKED = "", $avgCHECKED = "CHECKED";
  }
  
  $mass = $DEFS_FASTAMAKA{"MH+"};

  my $othertitle = "Other (below)";
  my $name = $othertitle;

  my $other_name = $DEFS_FASTAMAKA{"new database name"};

  my $append_name = $DEFS_FASTAMAKA{"Database to append"};

  # if true, requires us to include the old values.
  if (defined $_[0]) {
    $checked{"useappend"} = " checked" if $FORM{"useappend"};
	$checked{"autoindex"} = " checked" if $FORM{"autoindex"};
	$fasta_info = $FORM{"fasta_info"};
    $peptide = $FORM{"peptide"};
    $ignoreCHECKED = "CHECKED" if $FORM{"ignoreCRs"};
    $mass = $FORM{"mass"};
    $tolerance = $FORM{"tolerance"};
    $monoCHECKED = "" if ($FORM{"MassType"} != 1);
    $name = $FORM{"name"};
    $other_name = $FORM{"other"};
	$append_name = $FORM{"append_name"};
  }
  $avgCHECKED = "CHECKED" if ($monoCHECKED eq "");

  $name = $DEFS_FASTAMAKA{"new database name"} if (!defined $name or $name eq "");
  my (@files);

  $HelpLinkPermuta = ".permuta" if ($UsePermuta);
  $HelpLink = "<A href=\"$webhelpdir/help_$ourshortname$HelpLinkPermuta.html\">Help</a>&nbsp;";

    print <<ENDOFFORM1;
<FORM ACTION="$ourname" METHOD=POST NAME="form">
<INPUT TYPE=HIDDEN NAME="permuta" VALUE="$UsePermuta">
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
<TR ALIGN=LEFT>
<TD COLSPAN=2 align=right><nobr><span class=smalltext>(Optional) </span><b><span style="color:$script_color">FASTA header:&nbsp;</b></nobr></TD>
<TD><INPUT SIZE=97 NAME="fasta_info" VALUE="$fasta_info"></TD>
</TR>
<TR>
<TD VALIGN=TOP COLSPAN=2 align=right><B><span style="color:$script_color">Enter sequence:&nbsp;</span></B></TD>
<TD COLSPAN=2 ROWSPAN=4><tt><TEXTAREA ROWS=10 COLS=95 WRAP=VIRTUAL NAME="peptide">$peptide</TEXTAREA></tt></TD>
</TR>
ENDOFFORM1

if ($UsePermuta) {
    print <<ENDOFFORM2;
<TR>
<TD><span style="color:red"><span class=smalltext><b>MH+:</b></span> <INPUT NAME="mass" SIZE=6 MAXLENGTH=6
VALUE="$mass"></TD>
<TD><span class=smalltext><b>+/- </b></span><span class=dropbox><SELECT NAME="tolerance">
ENDOFFORM2

  foreach $value (0.5, 1.0, 2.0, 5.0, 20.0) {
    print ("<OPTION");
    print (" SELECTED") if ($value == $tolerance);
    print (">$value\n");
  }

print <<ENDOFFORM3;
</SELECT></span>
</TD>
</TR>

<TR VALIGN=TOP>
<TD>
<INPUT TYPE=RADIO NAME="MassType" VALUE=1 $monoCHECKED><span class=smalltext><b>Monoisotopic</b></span></TD>
<TD>
<INPUT TYPE=RADIO NAME="MassType" VALUE=0 $avgCHECKED><span class=smalltext><b>Average&nbsp;</b></span></TD>
</TR>
ENDOFFORM3
} else { #no permuta
	print '<TR><TD COLSPAN="2"></TD></TR>';
	print '<TR><TD COLSPAN="2"></TD></TR>';
}

print <<ENDOFFORM4;
<TR><TD COLSPAN="2" VALIGN="BOTTOM" ALIGN="RIGHT">
<INPUT TYPE=SUBMIT CLASS=button VALUE="FASTA me" onClick="return CheckForm()"> <INPUT TYPE=RESET CLASS=button VALUE="Clear">&nbsp;<BR>&nbsp;
</TD></TR>
<TR ALIGN=LEFT>
<TD COLSPAN="2" align=right><span class=smalltext><b>Output database:&nbsp;</b></span></TD><TD>
<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0><TR><TD>
ENDOFFORM4

ListDatabases("name", $name, $othertitle);

print <<ENDOFFORM5;
  </TD>
  <TD>&nbsp;&nbsp;&nbsp;&nbsp;
      <INPUT TYPE=RADIO NAME="writebehavior" VALUE="append"$checked{"Append"}></TD>
  <TD><span class=smalltext><b>Append&nbsp;</b></span></TD>
  <TD><INPUT TYPE=RADIO NAME="writebehavior" VALUE="writeover"$checked{"Write Over"}></TD>
  <TD><span class=smalltext><b>Overwrite</b></span>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD>
  <TD><INPUT TYPE=CHECKBOX NAME="autoindex"$checked{"autoindex"}></TD>
  <TD><b><span class=smalltext> Auto-index FASTA headers</b></span></TD>
  <TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$HelpLink</TD>
 </TR></TABLE>
</TD>
</TR>

<TR ALIGN=LEFT>
<TD COLSPAN="2" align=right><NOBR><span class=smalltext><b>Name (if "Other"):&nbsp;</b></span></NOBR></TD>
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
	$copyA = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
	$copyB = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
}

print <<EOF;
    </TD></TR></TABLE>
    <TD>
      <TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0><TR>
	  <TD>$copyA</TD>
      <TD>$copyB</TD></TR></TABLE>
	</TD>
  </TR></TABLE>
</TD></TR>
EOF

if ($UsePermuta) {
	ShowPermutaInstructions();
} else {
	ShowHeaderHelper();
}

print <<ENDOFFORM7;
<SCRIPT>
function CheckForm() {
	var controls = document.form;
	var OtherFile = controls.name.options[controls.name.selectedIndex].text;

	// is a sequence entered?
	controls.peptide.value = controls.peptide.value.replace(/\\s/g, "");
	if (controls.peptide.value == "") {
		controls.peptide.focus();
		alert("You must enter a sequence.");
		return false;
	}
	// is the sequence valid?
	if (controls.peptide.value.match(/[^A-Z]/i) && "$UsePermuta" == "") {
		alert("Please use only letters and whitespace in the sequence, or use FastaMaka Permuta.");
		return false;
	}

	// if a specified filename is required, is it provided?
	// Currently, 0 will always be Other the way this code is written
	if (controls.name.selectedIndex == 0) {
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

function VerifyOverwrite(filename) {
	return confirm('The file "' + filename + '" already exists and you have selected the "Overwrite" option.\\n\\nDo you want to proceed and erase all existing data in this file?');
}

function MakeHeader(make_type) {
	var form = document.form;

	// read in values and make sure they're appropriate
	var FirstInitial = Trim(form.FirstInitial.value)
	var LastName = Trim(form.LastName.value);
	var LastInitial = (LastName != "") ? LastName.charAt(0) : "";
	var SequenceName = Trim(form.SequenceName.value);
	if (SequenceName.length < 4) {
		form.SequenceName.focus();
		alert('"Sequence short name" must be at least 4 characters long.');
		return false;
	}
	var StrippedSequenceName = SequenceName.toLowerCase().replace(/[^a-z_\\-0-9]/g,"");
	var SequenceFullName = Trim(form.SequenceFullName.value);
	var SequenceSpecies = Trim(form.SequenceSpecies.value);
	var Description = Trim(form.Description.value);
	if (make_type == 'header') {
		// build header
		var Header;
		var IntroHeader = String(FirstInitial + LastInitial).toLowerCase();
		if (IntroHeader != "" && StrippedSequenceName != "") { IntroHeader += "|"; }
		IntroHeader += StrippedSequenceName;
		Header = AddSection(IntroHeader, SequenceName, " ");
		Header = AddSection(Header, SequenceFullName, (IntroHeader != Header) ? ", " : " ");
		if (SequenceSpecies != "") {
			Header = AddSection(Header, "[" + SequenceSpecies + "]", " ");
		}
		Header = AddSection(Header, Description, (IntroHeader != Header) ? ", " : " ");
		Header = AddSection(Header, TitleCase(FirstInitial) + ((FirstInitial != "" && LastName != "") ? "." : "") + TitleCase(LastName), (IntroHeader != Header) ? ", " : " ");
		// assign header to form field
		document.form.fasta_info.value = ">" + Header;
	} else if (make_type == 'filename') {
		// build filename
		var Filename = String(FirstInitial + LastName).toLowerCase();
		Filename += (Filename != "" && StrippedSequenceName != "") ? "_" : "";
		Filename += StrippedSequenceName;
		Filename += (Filename == "") ? "$other_name" : ".fasta";
		// assign filename to form field
		document.form.other.value = GetValidFilename(Filename);
		// select "Other" in list box
		for (var i=0; i < document.form.name.length; i++) {
			if (document.form.name.options[i].text == "$othertitle") {
				document.form.name.options[i].selected = true;
				break;
			}
		}
	}

	// return false so page doesn't reload w/ button click
	return false;
}
function AddSection(text, new_section, prev_chars) {
	if (new_section != "") {
		text += (text == "") ? new_section : prev_chars + new_section;
	}
	return text;
}
function Trim(text) { return text.replace(/^\\s*|\\s*\$/g, ""); }
function TitleCase(text) { return text.charAt(0).toUpperCase() + text.slice(1, text.length).toLowerCase(); }
function GetValidFilename(text) { return text.replace(/['":?\\057\\134*<>|]/g, ""); }
</SCRIPT>
</BODY></HTML>
ENDOFFORM7
}

sub ShowPermutaInstructions {
print <<ENDOFFORM100;
<TR><TD COLSPAN="3">&nbsp;<BR><HR></TD></TR>
<TR><TD COLSPAN="3">
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0>
<TR><TD valign=top><p align="right"><b>Instructions:&nbsp;</b></span></TD>
<TD><blockquote><span class=smalltext>Please enter peptides in the text box. Different peptides should be separated
by hitting the return key.<br>
<b>Note:</b>  Text will wrap automatically at the
end of the box. The program will still think it is one long peptide until you
hit the return key.</span></blockquote>
</TD></TR>
<TR><TD valign=top><p align="right"><b>Syntax:&nbsp;</b></TD>
<TD colspan=2><span class=smalltext><ol>
<li>All <tt>I</tt>'s are converted to <tt>L</tt>'s and all internal and
N-terminal <tt>K</tt>'s are converted to <tt>Q</tt>'s. C-terminal
<tt>Q</tt>'s are converted to <tt>K</tt>'s.

<li>Enter a question mark (&quot;?&quot;) at a position where you don't know
the amino acid. e.g. <tt>acd?f</tt> will result in 18 five-aa sequences, <br>each
starting with <tt>ACD</tt> and ending with <tt>F</tt>. (<tt>ACDIF</tt> and
<tt>ACDKF</tt> will not be produced, by rule 1.)

<li>Use the square brackets (&quot;[&quot; and &quot;]&quot;) to enclose
known possibilities for a position. e.g. <tt>d[aie]g</tt> encodes for
<tt>DAG</tt>, <tt>DIG</tt>, and <tt>DEG</tt>.

<li>Use the curly brackets (&quot;{&quot; and &quot;}&quot;) to enclose
ordering ambiguity (currently limited to a di-peptide sequence). e.g.
<tt>{an}te</tt> encodes <br>for <tt>ANTE</tt> and <tt>NATE</tt>.

<li>You can put square brackets and question marks in curly-bracket-enclosed
sequences. You cannot nest curly brackets in square brackets, <br>or square or
curly brackets within themselves.

<li>Additionally, the program will not compute the peptides if the number to
be generated is greater than $MAX_PEPTIDES.
</ol></span></TD></TR>
</TABLE>

</TD></TR></TABLE></FORM>
ENDOFFORM100
}

sub ShowHeaderHelper() {
print <<ENDOFFORM6;
<TR><TD COLSPAN="3">&nbsp;<BR><HR></TD></TR>
<TR>
<TD COLSPAN="2" VALIGN="MIDDLE"><nobr><span style="color:#767676"><B>Fasta Header Helper&nbsp;</B></span></nobr></TD>
<TD VALIGN="MIDDLE">

<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0 WIDTH=100%><TR>
  <TD><span style="color:#767676" class=smalltext>Fill in below and click button on right to auto-construct header/filename.</span></TD>
  <TD><P ALIGN="RIGHT">
      <INPUT TYPE=SUBMIT CLASS="Button" VALUE="Make header" onClick="return MakeHeader('header')">
      <INPUT TYPE="SUBMIT" CLASS="Button" VALUE="Make filename" onClick="return MakeHeader('filename')"></TD>
</TR></TABLE>
</TD></TR>
<TR><TD COLSPAN="2" ALIGN="RIGHT"><span style="color:#767676" class=smalltext>Researcher's first initial:&nbsp;</span></TD>

<TD VALIGN="TOP" COLSPAN="2">
<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR>
  <TD><INPUT TYPE="TEXT" SIZE=2 NAME="FirstInitial" MAXLENGTH=1>&nbsp;&nbsp;</TD>
  <TD><span style="color:#767676" class=smalltext>Last name:&nbsp;</span></TD>
  <TD><INPUT TYPE="TEXT" SIZE=20 NAME="LastName"></TD>
  <TD><span style="color:#767676" class=smalltext>&nbsp;e.g. J Doe</span</TD>
</TR></TABLE>

</TD></TR><TR>
<TD COLSPAN="2" ALIGN="RIGHT"><span style="color:#767676" class=smalltext>Sequence short name:&nbsp;</span></TD>
<TD>

<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR>
  <TD><INPUT TYPE="TEXT" SIZE=13 NAME="SequenceName" MAXLENGTH=12></TD>
  <TD><span style="color:#767676" class=smalltext>&nbsp;4-12 characters, e.g. eEF1A</span></TD>
</TR></TABLE>

</TD></TR><TR>
<TD COLSPAN="2" ALIGN="RIGHT"><span style="color:#767676" class=smalltext>Sequence full name:&nbsp;</span></TD>
<TD>

<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR>
  <TD><INPUT TYPE="TEXT" SIZE=50 NAME="SequenceFullName"></TD>
  <TD><span style="color:#767676" class=smalltext> &nbsp;e.g. elongation factor 1 alpha</span></TD>
</TR></TABLE>

</TD></TR><TR> 
<TD COLSPAN="2" ALIGN="RIGHT"><span style="color:#767676" class=smalltext>Species of sequence:&nbsp;</span></TD>
<TD>

<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR>
  <TD><INPUT TYPE="TEXT" SIZE=50 NAME="SequenceSpecies"></TD>
  <TD><span style="color:#767676" class=smalltext> &nbsp;e.g. human; p. falciparum</span></TD>
</TR></TABLE>

</TD></TR><TR>
<TD COLSPAN="2" ALIGN="RIGHT"><span style="color:#767676" class=smalltext>Description:&nbsp;</span></TD>
<TD>

<TABLE CELLSPACING=0 CELLPADDING=0 BORDER=0><TR>
  <TD><tt><TEXTAREA WRAP=VIRTUAL ROWS="2" COLS="48" NAME="Description"></TEXTAREA></tt></TD>
  <TD><span style="color:#767676" class=smalltext>&nbsp;e.g. RNA binding domain; expressed in e. coli; GST fusion, etc.</span></TD>
</TR></TABLE>

</TD></TR>
</TABLE>
</SPAN>
</FORM>
ENDOFFORM6
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

