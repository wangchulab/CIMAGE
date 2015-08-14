#!/usr/local/bin/perl

#-------------------------------------
#	glorp_prone
#	(C)1998 Harvard University
#	
#	W. S. Lane/M. Baker
#-------------------------------------


# Martin's all new program

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

&MS_pages_header ("Teratogenic Killer", "#ff0000");
print ("<hr>\n");

#print ("<h2>happy dead jesus day</h2>\n");

$dir = $FORM{"directory"};

if (!defined $dir) {
  &output_form();
  exit();
}


$fulldir = "$seqdir/$dir";
opendir (DIR, "$fulldir") || &error ("Could not open directory $fulldir. $!");
@alldtas = sort {$a cmp $b} grep { m!\.dta$! } readdir (DIR);
closedir (DIR);

foreach $dta (@alldtas) {
  open (DTA, "$fulldir/$dta") || next;
  $LINE =  <DTA>; # grab one line

  ($mhplus{$dta}, $charge{$dta}) = $LINE =~ m!(\d+\.?\d*)\s+(\d)!;
    
  ($low, $high) = $dta =~ m!.*\.(\d{4})\.(\d{4})\.\d!;

  if ($low eq $high) {
    $scanname{$dta} = $low;
  } else {
    $scanname{$dta} = $low . "-" . $high;
  }

  close (DTA);
}

$sel_dtas = $FORM{"selected"};
if (!defined $sel_dtas) {
  &output_second_form();
  exit();
}

@sel_dtas  = split (", ", $sel_dtas);
foreach $dta (@sel_dtas) {
  $dta .= ".dta" if ($dta !~ m!\.dta$!);
  $selected{$dta} = 1;
}

# construct backward-looking hashes:
foreach $dta (@alldtas) {
  $mass = $mhplus{$dta};
  $dta{$mass} .= " $dta";
  $sel_mass{$mass} = 1 if ($selected{$dta});
}

@checkvals = sort {$a <=> $b} keys (%dta);
@vals = sort {$a <=> $b} keys %sel_mass;

$diff = 1.01; # the amount extra to subtract: must be ~1 dalton if dealing with MH+ values:


$l = @vals;
$biggest = $vals[$l - 1] + 1.0;

OUTER:
for ($i = 0; $i < $l; $i++) {
  $m1 = $vals[$i];

  INNER:
  for ($j = $i + 1; $j < $l; $j++) {
    $m2 = $vals[$j];

    $sum = $m1 + $m2 - 18.01 - $diff; # water must be removed

    last INNER if ($sum > $biggest);
    $sum_seen{$sum} .= "$m1 + $m2;";
  }
}

if (@checkvals) {
  @sums = keys %sum_seen;
 OUTER2:
  foreach $sum (@sums) {

    # check to see that it is close in value to check values:
   INNER2:
    foreach $val (@checkvals) {
      if ($val - $sum > 0.5) {
        # if not close to anything, remove from consideration:
        delete $sum_seen{$sum} if (!defined $near{$sum});
        next OUTER2;
      }
      next INNER2 if ($val - $sum < -0.5);
      $near{$sum} .= $dta{$val};
    }
  }
}

@sums = sort {$a <=> $b} keys %sum_seen;

$l = @sums;

print "<div>\n";
print ("$l matches found.<P>\n");
#print ("selected are @sel_dtas\n"); 


print ("<TT>");
foreach $sum (@sums) {
  print (&precision ($sum, 2, 4, "&nbsp;"), "&nbsp;" x 4);

  foreach $pair ( split (m!;!, $sum_seen{$sum}) ) {
    print ($pair, "\n");
    ($mass1, $mass2) = split (m!\s*\+\s*!, $pair);

    foreach $big_dta (split (' ', $near{$sum})) {
      foreach $dta1 (split (' ', $dta{$mass1})) {
        $comp1 = `$compare_dtas Dta=$fulldir/$big_dta  Dta=$fulldir/$dta1`;
        chomp $comp1;
        $comp1 =~ s!^(\d+)% ions.*!$1!g;		# just the percentage (without %)

        foreach $dta2 (split (' ', $dta{$mass2})) {
          $comp2 = `$compare_dtas Dta=$fulldir/$big_dta  Dta=$fulldir/$dta2`;
          chomp $comp2;
          $comp2 =~ s!^(\d+)% ions.*!$1!g;		# just the percentage (without %)

          print qq(<a href="$thumbnails?Dta=$fulldir/$big_dta&amp;Dta=$fulldir/$dta1&amp;Dta=$fulldir/$dta2">);
          print ($scanname{$big_dta}, " =&gt; ", $scanname{$dta1}, ", ", $scanname{$dta2});
          print (" ($comp1%/$comp2%)</a>\n");
        }
      }
    }
    print ("&nbsp;" x 2);
  }

  print ("<br>\n");
}
print ("</TT>\n");
print "</div></body></html>";

#print ("</TT></TD></TR></TABLE>\n");





sub output_form {
  print <<EOFORM;
<div>
<FORM METHOD=POST ACTION="$ourname">
Pick a directory in which to glorp:
<span class=dropbox><SELECT NAME="directory">
EOFORM

  &get_alldirs();
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }

  print <<EOFORM2;
</SELECT></span>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Glorp!">
</FORM>
</div>
EOFORM2
}



sub output_second_form {

  print <<EOFORM;
<div>
<FORM METHOD=POST ACTION="$ourname">
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">
<h2>The chosen directory is <a href="$webseqdir/$dir">$dir</a>.</h2>
Select some masses (not too many) for serious partial inspection:
<INPUT TYPE=SUBMIT CLASS=button VALUE="Submit">
<INPUT TYPE=RESET CLASS=button VALUE="Clear">
<P>
EOFORM



  print ("<tt>");
  print ("Dta", "&nbsp;" x 8);
  print ("MH+", "&nbsp;" x 6);
  print ("z", "&nbsp;" x 2);
  print ("selected");

  print ("<br><hr>\n");

  foreach $dta (@alldtas) {

    print ($scanname{$dta}, "&nbsp;" x (11 - length ($scanname{$dta}	)) );
    print &precision ($mhplus{$dta}, 2, 4, "&nbsp;");
    print ("&nbsp;&nbsp;");
    print ($charge{$dta}, "&nbsp;" x (3 - length ($charge{$dta})) );
    print qq(<INPUT TYPE=CHECKBOX NAME="selected" VALUE="$dta">);
    print ("<br>\n");
  }

  print ("</tt></FORM></div>\n");
}

sub error {
  print <<EOF;
<H2>Error:</H2>
<div>
@_
</div>
</body></html>
EOF
  exit 0;
}









