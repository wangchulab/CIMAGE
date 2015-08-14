#!/usr/local/bin/perl

#-------------------------------------
#	Dif Browser,
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
 
&cgi_receive;

$dif_tolerance = 1.0;

&MS_pages_header ("DifBrowser", "#9F9F5F");

$dirname = $FORM{"directory"};

if (!defined $dirname) {
  &output_form;
  print ("</FORM>\n");
  &tail;
  exit;
}

$dir = "$seqdir/$dirname";

&read_data;
&get_scans;
&calc_difs;

&print_info;

#&print_triangle_table;

&print_pairs;

##
## create a URL to displayions with the requisite information
##
sub dispurl {
  my ($small, $large, $seq, $side) = @_;

  my $diffmass = &mw ("Average", 0, $seq) + $Average_mass{"Hydrogen"};
  my $mass = &precision ($mass{$large} - $diffmass, 2);

  my $s = $side ? "B" . $seq : $seq . "B";

  my $url = $displayions . "?dtafile=$seqdir/$dirname/$large";
  $url .= "&amp;numaxis=1";
  $url .= "&amp;pep=$s";
  $url .= "&amp;MassB=$mass";

  return $url;
}

sub syn {
  my ($small, $large, $seq, $side) = @_;

  my $diffmass = &mw ("Average", 0, $seq) + $Average_mass{"Hydrogen"};
  my $mass = &precision ($mass{$large} - $diffmass, 2);

  my $s = $side ? "B" . $seq : $seq . "B";
  
  my $syn = qx($synopsis "dtafile=$dir/$large" "pep=$s" "MassB=$mass");
  $syn =~ s/Synopsis: //;
  $syn =~ s/\n//g;
 
  return $syn;
}

# print out the pairs

sub print_pairs {
  print <<EOM;
<TABLE CELLSPACING=1 CELLPADDING=1 BORDER>
<TR ALIGN=CENTER>
<TD COLSPAN=4><B>K-differences</B></TD>
<TD COLSPAN=4><B>R-differences</B></TD>
</TR>

<TR ALIGN=CENTER>
<TD>Smaller</TD>
<TD>Larger</TD>
<TD>Masses</TD>
<TD>Display</TD>

<TD>Smaller</TD>
<TD>Larger</TD>
<TD>Masses</TD>
<TD>Display</TD>
</TR>

EOM

  my $k, $r, $file, $kfile, $rfile, $kcount=0, $rcount=0;
  my $num;


  for ($i = 0; $i < $numdtas; $i++) {
    $k = $K_larger[$i];
    $r = $R_larger[$i];
    next unless ($k or $r);

    $k =~ s/, $//;
    $r =~ s/, $//;

    @k = split (", ", $k);
    @r = split (", ", $r);

    $num = &max ($#k, $#r) + 1;

    for ($j=0; $j < $num; $j++) {
      print ("<TR ALIGN=CENTER>\n");
      $file = $massfiles[$i];
      $mass = $mass{$file};

      $k = shift @k;
      $r = shift @r;

      if ($k) {
	$kcount++;
	$kfile = $massfiles[$k];
	$kmass = $mass{$kfile};

	$url1 = &dispurl ($file, $kfile, "K", 0);
	$url2 = &dispurl ($file, $kfile, "K", 1);

	$s1 = &syn  ($file, $kfile, "K", 0);
	$s2 = &syn  ($file, $kfile, "K", 1);

	print ("<TD><TT>$scanurl{$file}</TT></TD>\n");
	print ("<TD><TT>$scanurl{$kfile}</TT></TD>\n");
	print ("<TD><TT>$mass --&gt; $kmass (", $kmass - $mass, ")</TT></TD>\n");
	print qq(<TD><TT><a href="$url1">N ($s1)</a> or <a href="$url2">C ($s2)</a></TT></TD>\n);
      } else {
	print "<TD></TD>\n" x 4;
      }

      if ($r) {
	$rcount++;
	$rfile = $massfiles[$r];
	$rmass = $mass{$rfile};

	$url1 = &dispurl ($file, $rfile, "R", 0);
	$url2 = &dispurl ($file, $rfile, "R", 1);

	$s1 = &syn  ($file, $rfile, "R", 0);
	$s2 = &syn  ($file, $rfile, "R", 1);

	print ("<TD><TT>$scanurl{$file}</TT></TD>\n");
	print ("<TD><TT>$scanurl{$rfile}</TT></TD>\n");
	print ("<TD><TT>$mass --&gt; $rmass (", $rmass - $mass, ")</TT></TD>\n");
	print qq(<TD><TT><a href="$url1">N ($s1)</a> or <a href="$url2">C ($s2)</a></TT></TD>\n);
      } else {
	print "<TD></TD>\n" x 4;
      }
      print ("</TR>\n");
    }
  }
  print ("</TABLE>\n");

  print ("<div>Total: $kcount K-difs, $rcount R-difs.</div>\n");
}

sub get_scans {
  foreach $file (@dtafiles) {
    ($scan{$file}) = $file =~ m!(\d+\.\d+)\.\d\.dta!;
    $scanurl{$file} = qq(<a href="$displayions?dtafile=$dir/$file&amp;numaxis=1">$scan{$file}</a>);
  }
}

sub print_info {
  print <<EOM;
<hr>

<p>
Directory: <a href="$webseqdir/$dirname">$dirname</a>
</p>
EOM
}

sub print_triangle_table {
  print <<EOM;
<TABLE CELLSPACING=1 CELLPADDING=1 BORDER>
<TR ALIGN=CENTER>
<TD><tt>&nbsp;&nbsp;#&nbsp;&nbsp;</tt></TD>
<TD><tt>File</tt></TD>
<TD><tt>&nbsp;Mass&nbsp;</tt></TD>
EOM

  for ($i = 1; $i <= $numdtas; $i++) {
    print ("<TD><tt>$i", ($i<10) ? "&nbsp;" : "", "</tt></TD>\n");
  }
  print ("</TR>\n");

  for ($i = 0; $i < $numdtas; $i++) {
    $file = $massfiles[$i];
    print ("<TR ALIGN=RIGHT>\n");
    print ("<TD><tt>", $i+1, "&nbsp;</tt></TD>\n");
    print ("<TD><tt>$file</tt></TD>\n");
    print ("<TD><tt>", $mass{$file}, "</tt></TD>\n");

    print "<TD BGCOLOR=gray>&nbsp;</TD>\n" x $i;
    print ("<TD BGCOLOR=black>&nbsp;</TD>\n");

    for ($j=$i+1; $j < $numdtas; $j++) {
      print ("<TD><tt>");
      print ("K") if ($j == $K_larger[$i]);
      print ("R") if ($j == $R_larger[$i]);
      print ("&nbsp;</tt></TD>\n");
    }
    print ("</TR>\n");
  }
  print ("</TABLE>\n");
}

sub calc_difs {
  my $diff, $sigdiff, $s1, $s2;
  my $key, $file, $smaller, $larger;

  for ($i = 0; $i < $numdtas; $i++) {
    for ($j = $i + 1; $j < $numdtas; $j++) {
      $key = $massfiles[$i];
      $file = $massfiles[$j];
 
      $diff = $mass{$file} - $mass{$key};
      $sigdiff = abs($diff);

      if ($diff > 0) {
	$smaller = $i;
	$larger = $j;
      } else {
	$smaller = $i;
	$larger = $j;
      }

      $s1 = $sigdiff - $dif_tolerance;
      $s2 = $sigdiff + $dif_tolerance;

      # check lysines
      $K_larger[$smaller] .= "$larger, " if ($s2 >= 128.0 and $s1 <= 128.0);

      # check arginines
      $R_larger[$smaller] .= "$larger, " if ($s2 >= 156.0 and $s1 <= 156.0);

    } # for
  } # end of mass-diffs loops
}

sub read_data {
  opendir (DATADIR, "$dir") || die ("could not opendir $dir");
 
  while($file = readdir (DATADIR)) {
    # filenames look like "username-sample.0245.0268.1.dta"
    # here, 0245 ms is the start, 0268 ms is the end, of the interval
    $file =~ /(\d\d\d\d)\.(\d\d\d\d)\.\d\.dta$/ || next;
 
    $firstscan{$file} = $1;
    $lastscan{$file} = $2;
 
    push (@dtafiles, $file);
  }
  closedir DATADIR;
  @dtafiles = sort { ($firstscan{$a} + $lastscan{$a}) <=>
		       ($firstscan{$b} + $lastscan{$b}) } @dtafiles;

  foreach $file (@dtafiles) {
    open (FILE, "$dir/$file") || die ("Could not open $file");
    $mass_charge = <FILE>; # first line is mass and charge info
    chomp $mass_charge;
 
    ($mass{$file}, $charge{$file}) = split (" ", $mass_charge);
    $charge{$file} = "+" . $charge{$file} if ($charge{$file} > 0);
    close FILE;
  }

  $numdtas = $#dtafiles + 1;

  select STDOUT;

  @massfiles = sort { $mass{$a} <=> $mass{$b} } @dtafiles; # sort by mass
}

sub output_form {
  print ("<hr><br>\n");
  print qq(<FORM ACTION="$ourname" METHOD=POST>);
 
  ##
  ## subroutine from microchem_include.pl
  ## that gets all the directory information
  ##
  &get_alldirs;

  # make dropbox:
  print ("<span class=\"dropbox\"><SELECT name=\"directory\">\n");

  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }
  print ("</SELECT></span>\n");

  print qq(<INPUT TYPE="SUBMIT" CLASS="button" VALUE="Show" NAME="show">&nbsp;);
}
 
##
## &tail
##
##      Prints copyright, attributions, and closing tags
##
sub tail {
  print ("</body></html>\n");
}
