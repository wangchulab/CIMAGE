#!/usr/local/bin/perl

#-------------------------------------
#	DTA Finder,
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
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
 
&cgi_receive();

&MS_pages_header ("DTA Finder", "#00009C");
print "<HR><P>\n";

#while (($k, $v) = each %FORM) { print STDERR ("$k=$v\n"); }

##
## code to get all of the sequest directories
##
$directories = $FORM{"directory"};

$givenmass = $FORM{"mass"};
$givenmass =~ s/\s//g;
$minmass = $FORM{"minmass"};
$minmass =~ s/\s//g;
$maxmass = $FORM{"maxmass"};
$maxmass =~ s/\s//g;

$by_mass = (defined $givenmass and $givenmass ne "")
  || (defined $minmass and $minmass ne "") || (defined $minmass and $maxmass ne "");

$nterm = $FORM{"Nterm"};
$nterm =~ s/\s//g;
$nterm =~ tr/a-z/A-Z/;

$cterm = $FORM{"Cterm"};
$cterm =~ s/\s//g;
$cterm =~ tr/a-z/A-Z/;
$by_seq = (defined $nterm and $nterm ne "") || (defined $cterm and $cterm ne "");

if ($by_seq) {
  $use_mono = $FORM{"MassType"};
  $ion_tol = $FORM{"ion_tolerance"};
  $grep_outs = $FORM{"grep_outs"}; # if this is defined, we scan ".out" files
  $dtascan = $FORM{"dtascan"}; # if this is defined, we scan .dta files for ions

  if ((!$grep_outs) && (!$dtascan)) {
    undef $by_seq;
  }
}


if ((!defined $directories) || (!$by_seq && !$by_mass)){
  &get_alldirs();

  &output_form();
  exit;
}

##
## otherwise, we will scan each directory for matching dta files
##

@dirs = split(", ", $directories);


if ($by_mass) {
  $mass_tol = $FORM{"mass_tolerance"};
  $floor = defined $givenmass ? &max ($givenmass - $mass_tol, $minmass) : $minmass;
  $ceiling = defined $givenmass ? &min ($givenmass + $mass_tol, $maxmass) : $maxmass;
}

##
## here we read in all the DTAs, and exclude
## by mass if asked.

foreach $dir (@dirs) {
  opendir (DIR, "$seqdir/$dir") || next;
  @dtas = grep { m!\.dta$! } readdir (DIR);
  closedir DIR;

  @matching_dtas = ();
  foreach $dta (@dtas) {
    open (DTA, "$seqdir/$dir/$dta") || next;
    $line = <DTA>;
    close DTA;

    ($mass, $charge) = split (' ', $line);

    next if ($floor and $mass < $floor);
    next if ($ceiling and $mass > $ceiling);

    $mass{"$dir/$dta"} = $mass;
    $charge{"$dir/$dta"} = $charge;

    push (@matching_dtas, $dta);
  }
  $matching{$dir} = join (", ", @matching_dtas);
}

##
## exclude and score by presence of ion if asked.
##

if ($by_seq) {
  &ion_check();
}

$totalnum = 0;
foreach $dir (@dirs) {
  @matching_dtas = split (", ", $matching{$dir});
  $totalnum += $#matching_dtas + 1;
}

##
## organize this data for display
##

print "<div>\n";
if ($by_mass) {
  print ("Searching for MH+ from $floor to $ceiling.<br>\n");
}
print "</div>\n";

# CODE ADDED FOR THE DTA VCR BUTTON
$vcr_count = 0;
print <<EOF;
<form action="$dtavcr" method="post" target="_blank">
<INPUT TYPE=SUBMIT CLASS=button VALUE="DTA VCR">
<INPUT TYPE=hidden NAME="DTAVCR:conserve_space" VALUE=1>
EOF

print "<br><br><div>\n";

if ($by_seq) {
  print ("Searching for ");
  if ($nterm and $cterm) {
    print ("starting N-term sequence of $nterm, and ending C-term sequence of $cterm.<br>\n");
  } elsif ($nterm) {
    print ("starting N-term sequence of $nterm.<br>\n");
  } elsif ($cterm) {
    print ("ending C-term sequence of $cterm.<br>\n");
  }
}

print ("<b>$totalnum</b> found.<p>\n");

print ("<ul>\n");
foreach $dir (@dirs) {
  @matching_dtas = split (", ", $matching{$dir});
  $num = $#matching_dtas + 1;

  print qq(<li><a href="$webseqdir/$dir/" target=_blank>$dir</a>: <b>$num</b> found.\n);

  print ("<ul>\n");
  foreach $dta (@matching_dtas) {
    $url = &urlize ("$dir/$dta");
    $mass = $mass{"$dir/$dta"};
    $charge = $charge{"$dir/$dta"};
    $score = $score{"$dir/$dta"} if $by_seq;

    print qq(<li><a href="$url" target=_blank>$dta</a>: MH+: $mass, z: $charge);

	if ($by_seq) {
      if ($score != 0) {
	print (", ");
	print ("<b>") if ($score == $maxscore);
	print qq(Score: $score);
	print ("</b>") if ($score == $maxscore);

	  }
      $str = "";
      if ($ntermsupergrepmatch{"$dir/$dta"}) {
	$str = "Nterm";
      }

      if ($ctermsupergrepmatch{"$dir/$dta"}) {
	$str .= " and " if ($str ne "");
	$str .= "Cterm";
      }
      if ($str ne "") {
	$url = &out_urlize("$dir/$dta");
	print qq(, <b><a href="$url">$str SuperGrep match</a></b>);
      }
    }
    print "\n";

	# added by cmw for DTA VCR (8/27/99):
	print qq(<input type=hidden name="DTAVCR:link$vcr_count" value="$url">\n);
	$vcr_count++;

  }
  print ("</ul>\n");
}
print ("</ul>\n");

print "</div>\n";

print("</form>");
#END of DTA VCR BUTTON CODE


# converts an .out file to an URL for display

sub out_urlize {
  my $file = $_[0];
  my $out;
  my $url;

  ($out = $file) =~ s!\.dta$!.out!;
  $url = "$showout?OutFile=$seqdir/$out";
  return $url;
}

# this takes a DTA filename and converts it to a URL for display

sub urlize {
  my $file = $_[0];
  my $url;

  $url = "$fuzzyions?Dta=" . &url_encode("$seqdir/$file");
  $url .= "&amp;numaxis=1";
  $url .= "&amp;Ntermspace=$nterm";
  $url .= "&amp;Ctermspace=$cterm";
  if ((defined $cterm and $cterm ne "") and !(defined $nterm and $nterm ne "")) {
    $url .= "&amp;side_to_walk=Cterm";
  } elsif (!(defined $cterm and $cterm ne "") and (defined $nterm and $nterm ne ""))  {
    $url .= "&amp;side_to_walk=Nterm";
  }
  return $url;
}
   

sub output_form {

  $checked{$DEFS_DTA_FINDER{"Mono/Avg"}} = " CHECKED";
  $checked{"ionscan"} = " CHECKED" if ($DEFS_DTA_FINDER{"DTA ion scan"} eq "yes");
  $checked{"supergrep"} = " CHECKED" if ($DEFS_DTA_FINDER{"Long shot *.out SuperGrep"} eq "yes");

  print <<EOM;
<FORM ACTION="$ourname" METHOD=POST>
<TABLE CELLSPACING=5 BORDER=0>
<TR>
<TD>
Pick a list of directories in which to search:<br>
<span class="dropbox"><SELECT SIZE=15 MULTIPLE NAME="directory">
EOM
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE="$dir">$fancyname{$dir}\n);
  }

  print <<EOM;
</SELECT></span>
</TD>

<TD>

<h4>Mass Filter:</h4>
<p>

MH+:
<INPUT NAME="mass" SIZE=6 VALUE="$DEFS_DTA_FINDER{"MH+"}">

+/-:
<INPUT NAME="mass_tolerance" VALUE="$DEFS_DTA_FINDER{"MH+ +/-"}" SIZE=4>
<p>
<CENTER>or</CENTER>
<p>

Min:
<INPUT NAME="minmass" SIZE=6 VALUE="$DEFS_DTA_FINDER{"Min"}">

Max:
<INPUT NAME="maxmass" SIZE=6 VALUE="$DEFS_DTA_FINDER{"Max"}">

<p>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Show">
<INPUT TYPE=RESET CLASS=button VALUE="Clear">
</TD>

<TD width=20></TD>

<TD>

<h4>Ion Filter:</h4>
<p>
Enter a short expected sequence:
<p>

Nterm:
<INPUT NAME="Nterm" SIZE=5 VALUE="$DEFS_DTA_FINDER{"Nterm"}">
<SPACER TYPE=HORIZONTAL SIZE=20>
Cterm:
<INPUT NAME="Cterm" SIZE=5 VALUE="$DEFS_DTA_FINDER{"Cterm"}">

<p>
Tolerance:
<INPUT NAME="ion_tolerance" SIZE=5 VALUE="$DEFS_DTA_FINDER{"Tolerance"}">

<p>
<INPUT NAME="MassType" TYPE=RADIO VALUE=1$checked{"Mono"}>Mono
<INPUT NAME="MassType" TYPE=RADIO VALUE=0$checked{"Avg"}>Avg

<p>
<INPUT TYPE="CHECKBOX" NAME="dtascan"$checked{"ionscan"}>DTA ion scan
<br>
<INPUT TYPE="CHECKBOX" NAME="grep_outs"$checked{"supergrep"}>Long shot *.out SuperGrep


</TD>
</TR>
</TABLE> 

</FORM>

<span style="color:#00009C" class="largetimes"><B><I>Instructions:</I></B></span>
<p>



You can input an MH+ with tolerance to limit the DTAs by MH+,
input N-term or C-term sequences to scan the heavy ions for, or do both.

<p>
The two filters operate on a logical AND basis: DTAs shown will fit the mass limits
entered and contain ions matching the sequences.

<p>The SuperGrep feature checks to see if, by crazy coincidence, Sequest matched
the Nterm or Cterm sequences in one of its output files.


EOM
}


sub ion_check {
  my (@letters, $middle, $subroutine, @residues, $m, @matching, @ions);
  my ($mass, $numions, $sum, @score, $score, $ion, @our_matching);
  my ($out, %matched, $charge);

  ##
  ## calculate array of masses to subtract from MH+
  ##

  ## first we calculate residues to create y-ions for the nterm seqs

  if ($dtascan) {
    @letters = split ("", $nterm);

    $m = 0.0;
    if ($use_mono) {
      foreach $letter (@letters) {
	$m += $Mono_mass{$letter};
	push (@residues, $m);
      }
    } else {
      foreach $letter (@letters) {
	$m += $Average_mass{$letter};
	push (@residues, $m);
      }
    }

    ## then, we calculate residues to create b-ions for the cterm seqs

    @letters = split ("", $cterm);

    $m = 18.0;
    if ($use_mono) {
      foreach $letter (@letters) {
	$m += $Mono_mass{$letter};
	push (@residues, $m);
      }
    } else {
      foreach $letter (@letters) {
	$m += $Average_mass{$letter};
	push (@residues, $m);
      }
    }
  } # $dtascan

  foreach $dir (@dirs) {
    next unless $matching{$dir};

    @matching = split (", ", $matching{$dir});
    @our_matching = ();

    foreach $dta (@matching) {
      if ($dtascan) {
	@ions = ();
	$mass = $mass{"$dir/$dta"};
	$charge = $charge{"$dir/$dta"};
	$precursor = ($mass - 1.0)/ $charge + 1.0;

	foreach $res (@residues) {
	  $ion = $mass - $res;
	  next if (($ion <= $precursor) && ($charge != 1));
	  push (@ions, $ion);
	}

	# don't bother if we don't have any ions
	if ($#ions + 1 > 0) {
	  @score = ();
	  $numions = 0;

	  open (DTA, "$seqdir/$dir/$dta");
	  $line = <DTA>; # skip first line;

	  while (<DTA>) {
	    ($mass, $inten) = split;
	    $numions++;
	
	    $i = 0;
	    foreach $ion (@ions) {
	      $score[$i] = &max($inten, $score[$i]) if (abs ($mass - $ion) < $ion_tol);
	      $i++;
	    }
	  }
	  close DTA;

	  $threshold = $numions ? $sum /($numions * 2) : 0;
	  $score = 0;
	  foreach $num (@score) {
	    $score++ if ($num > $threshold);
	  }
	  if ($score > 0 ) {
	    $score{"$dir/$dta"} = $score;
	    $matched{"$dir/$dta"} = 1;
	    push (@our_matching, $dta);
	  }
	  $maxscore = &max($maxscore, $score);
	}
      } # $dtascan

      if ($grep_outs) {
	($out = $dta) =~ s!\.dta$!.out!;
	open (OUT, "$seqdir/$dir/$out") || next;

	while (<OUT>) {
	  s!#!!g; # eliminate the "#" marks for oxidized methionines

	  if ($nterm and (m!\s\(.\)$nterm\S*$!o || m!\s.\.$nterm\S*\..$!o)) {	# updated for SequestC2 format OUTfiles
	    $ntermsupergrepmatch{"$dir/$dta"} = "1";
	    if (!$matched{"$dir/$dta"}) {
	      $matched{"$dir/$dta"} = 1;
	      push (@our_matching, $dta);
	    }
	  }
	  if ($cterm and (m!$cterm$!o || m!\s.\.\S*$cterm\..$!o)) {		# updated for SequestC2 format OUTfiles
	    $ctermsupergrepmatch{"$dir/$dta"} = 1;
	    if (!$matched{"$dir/$dta"}) {
	      $matched{"$dir/$dta"} = 1;
	      push (@our_matching, $dta);
	    }
	  }
	}
	close OUT;
      } # $grep_outs
    } # foreach $dta ...

    $matching{$dir} = join (", ", @our_matching);
  } # foreach $dir ...
}
