#!/usr/local/bin/perl

#-------------------------------------
#	Fence Scan,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


$hdr_font = '<span class="smallheading">';
$hdr_unfont = '</span>';

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
 
&MS_pages_header ("Fence Scan", "#FF7F00");
print "<HR><P><div>\n";

$directories = $FORM{"directory"};

if (!defined $directories){
  &get_alldirs();

  &output_form();
  exit;
}

$givenmass = $FORM{"mass"};
if (defined $givenmass) {
  $mass_tol = $FORM{"mass_tolerance"};
  $floor = $givenmass - $mass_tol;
  $ceiling = $givenmass + $mass_tol;
}

$seq = $FORM{"seq"};
$seq =~ tr/a-z/A-Z/;
$seq =~ s/\s+//g;

@dirs = split (", ", $directories);

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

print ("<p>");
print ("Scanning for sequence $seq.<br>\n");
print ("<ul>");

foreach $dir (@dirs) {
  print qq(<li>In directory <a href="$webseqdir/$dir/">$dir</a>:<br>\n);

  print "<ul>";
  foreach $dta (@matching_dtas) {
    $answer = `$cgidir/slanted_fences.exe Dta=$seqdir/$dir/$dta Pep=$seq`;
    (@answers) = split ('\n', $answer);

    $url = &urlize("$dir/$dta");
    $mass = $mass{"$dir/$dta"};
    $charge = $charge{"$dir/$dta"};

    print ("<li>");
    print ($hdr_font, "Dta: ", $hdr_unfont, "<tt>", qq(<a href="$url">$dta</a>), "</tt>");
    print ("&nbsp;" x 3);

    print ($hdr_font, "MH+: ", $hdr_unfont, "<tt>", $mass, "</tt>");
    print ("&nbsp;" x 3);

    print ($hdr_font, "z: ", $hdr_unfont, "<tt>", $charge, "</tt>");
    print ("<br>\n");

    foreach $answer (@answers) {
      # make it a fuzzy URL:
      $answer =~ s!offset: (\d+\.?\d*)!qq(offset: <a href=") . &urlize ("$dir/$dta", $1) . qq(">$1</a>)!e;
      print ("<tt>$answer</tt><br>\n");
    }
  }
  print "</ul>";
}
print "</ul>";

print "</div></body></html>";
exit;

sub urlize {
  my $file = $_[0];
  my $offset = $_[1];
  my $url;
 
  $url = "$fuzzyions?Dta=$seqdir/$file";
  $url .= "&amp;numaxis=1";
  if ($offset) {
    $url .= "&amp;Ntermspace=($offset)$seq";
  }

  return $url;
}


sub output_form {
  print <<EOM;
<FORM ACTION="$ourname" METHOD=POST>

Pick a list of directories in which to search:<br>
<span class="dropbox"><SELECT SIZE=15 MULTIPLE NAME="directory">
EOM
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE="$dir">$fancyname{$dir}\n);
  }
 
  print <<EOM;
</SELECT></span>

<p>
Inner Sequence:
<INPUT NAME="seq" SIZE=10>

<p>
<INPUT TYPE=SUBMIT CLASS="button" VALUE="Scan">

<INPUT TYPE=RESET CLASS="button" VALUE="Clear">

<p>

MH+:
<INPUT NAME="mass" SIZE=6>
 
+/-:
<INPUT NAME="mass_tolerance" VALUE="1.0" SIZE=4>
<p>

<INPUT NAME="MassType" TYPE=RADIO VALUE=1 CHECKED>Mono
<INPUT NAME="MassType" TYPE=RADIO VALUE=0>Avg

</FORM>
EOM

}
