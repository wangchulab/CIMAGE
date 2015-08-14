#!/usr/local/bin/perl

#-------------------------------------
#	DTA Banisher,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/T. A. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# takim 12/12/97  perl rewrite of twosandthrees (wsl)
#                 cgi'd following difbrowser.pl
# takim 4/10/98   major functionality enhancements

# dta_banisher checks some data that sequest doesn't catch and allows user to take
#   appropriate action:
#   1)  banish extraneous dta's (highest ion > mh+)

# further notes:  banish all options obsoleted

## site definitions
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

&MS_pages_header("DTA Banisher", "#9F9F5F");

# constant strings
$banishall="Banish all candidates";
$unbanishall="Unbanish all";

# grab options
$dirname = $FORM{'directory'};
$banish = $FORM{'banish'};
$bancharge = $FORM{'bancharge'};
$unbancharge = $FORM{'unbancharge'};
$unbanish = $FORM{'unbanish'};
$selectall = $FORM{'selectall'};
$chfile = $FORM{'chfile'};
$chset = $FORM{'chset'};
$chreset = $FORM{'chreset'};
$curch = $FORM{'curch'};

if (!defined $dirname) {
  &output_form;
  print "</FORM>\n";
  &tail;
  exit;
}

$dir="$seqdir/$dirname";  # this is somewhat insecure

# log file
#open(LOG, ">> dta_banisher.log");
#$date=localtime(time);
#print LOG "$date\n";

# fast file glob
&read_data;

sub read_data {
  opendir CURRDIR, "$dir";
  @allfiles=readdir CURRDIR;
  closedir CURRDIR;
  # glob for *.2.dta
  @dta2files=grep(/^.*\.2\.dta$/, @allfiles);
  @dta3files=grep(/^.*\.3\.dta$/, @allfiles);
  # glob for all dta files -wsl 12/14
  @dtafiles=grep(/^.*\.dta*$/, @allfiles);
}

# Figure out what we want to do
#   banish==xx and bancharge==yy => banish xx.yy
#   unbanish==xx and unbancharge==yy => unbanish xx.yy
#   selectall==$banishall => banish anything bad
#   selectall==$unbanishall => unbanish anything banished (scan for .2 first, NOT .banished)
#   chfile==xx and chset>0 => set charge to $chset
#   chreset==xx and curch==yy => remove xx.yy and restore xx.?.orig

if ( (defined $banish) && (defined $bancharge) ) {
  &banish_dta($banish, $bancharge);
  &read_data;
}

if ( (defined $unbanish) && (defined $unbancharge) ){
  &unbanish_dta($unbanish, $unbancharge);
  &read_data;
}

if ( (defined $curch) && (defined $chreset) )  {
    &reset_charge($chreset, $curch);
    &read_data;
}

if (defined $selectall) {
  if ($selectall eq $banishall) {
    foreach $dta2file (@dta2files) {
      $dtabase=$dta2file; $dtabase=~s/\.2\.dta$//;
      ($mhplus, $charge, $highion, $precursor)=read_dta($dta2file);
      if ($highion > $mhplus) {
	&do_banish($dtabase);
      }
    }
  } elsif ($selectall eq $unbanishall) {
    foreach $dta3file (@dta3files) {
      $dtabase=$dta3file; $dtabase=~s/\.3\.dta$//;
      # filenames
      $dta2file=$dtabase . ".2.dta";
      $banfile=$dtabase . ".2.dta.banished"; # wsl 12/14
      if (grep(/^$banfile$/, @allfiles)) {
	do_unbanish($dtabase);
      }
    }
  }

  &read_data;
}

if ((defined $chfile) && ($chset>0)){
    &set_charge($chfile, $chset);
    &read_data;
}

## PRESENTATION and status loop

# presentation header
print "<HR>\n";
print "<p><b><a href=\"$webseqdir/$dirname\" target=_blank>$dir</a></b></p>"; # link to dir for user double check
print "<table cellspacing=0 BORDER=0>\n";
print "<tr><th>&nbsp; Scans &nbsp;</th><th>&nbsp; z &nbsp;</th><th>&nbsp; m/z &nbsp;</th><th>&nbsp; MH+ &nbsp;</th>\
<th nowrap>&nbsp; Max Ion &nbsp;</th><th>&nbsp; Do Something? &nbsp;</th>\n";

# added by Martin 05/19/98
print ("<th>&nbsp; Zoom files &nbsp;</th>\n");

print "<form action=\"$ourname\" method=post>\n";
print qq(<input type="hidden" name="directory" value="$dirname">);


# status loop through @dtafiles

@dtapairs = (); # initialize, changed from a string to an array thomas 12/16/97

PRV: foreach $dtafile (@dtafiles) {
$dtabase=$dtafile; $dtabase=~s/\.\d\.dta$//; # base for all filenames

  # skip if the .3.dta pair
  next PRV if grep(/^$dtafile$/, @dtapairs);
  
  # some filenames
  $dta2file = $dtabase . ".2.dta";
  $dta3file = $dtabase . ".3.dta";
  
  ($mhplus, $charge, $highion, $precursor) = &read_dta($dtafile);

  # for banishing, map the "notcharge", the banishing complement
  # suave way of doing this is $notcharge = 5 - $charge;
  if ($charge == 3) {
      $notcharge = 2; 
  } elsif ($charge == 2) {
      $notcharge = 3;
  }
  $banfile = $dtabase . ".$notcharge.dta.banished";

  $scans=$dtabase;
  $scans=~s/[\w|\d|\-]+\.(\d+)\.(\d+)/$1-$2/; # remove hyphens, prefix
  
  # if 2/3 pair, we can print either the 2 or 3
  # arbitrarily let 2 dominate
  if (($charge == 2) && grep(/^$dta3file$/, @dtafiles)) {
    print "<tr><td nowrap align=center><tt>&nbsp;<a href=\"$displayions?Dta=$dir/$dta3file\" target=_blank>$scans</a>&nbsp;</tt></td>\n"; # but print 3
    $ispair=1;
  } else {
    print "<tr><TD nowrap align=center><tt>&nbsp;<a href=\"$displayions?Dta=$dir/$dtafile\" target=_blank>$scans</a>&nbsp;</tt></td>\n";
    $ispair=0;
  }

  print "  <td align=center><tt>$charge</tt></td>\n";
  $precursor=&precision($precursor, 2);
  if ($precursor<1000) {
    $precursor="&nbsp;$precursor";
  }
  print "  <td><tt>&nbsp;$precursor&nbsp;</tt></td>\n";

  $mhplus=&precision($mhplus, 2);
  if ($mhplus<1000) {
    $mhplus="&nbsp;$mhplus";
  }
  if ($mhplus >= 1.5*$highion) {
      print "  <td><b><tt>&nbsp;$mhplus&nbsp;</tt></b></td>\n";
  } else {
      print "  <td><tt>&nbsp;$mhplus&nbsp;</tt></td>\n";
  }
  if ($highion<1000) {
    $highion="&nbsp;$highion";
  }
  if ( ($highion > $mhplus) || ($ispair) ) {
    print "<td><tt>&nbsp;<b>$highion</b>&nbsp;</tt></td>\n"; # change color
  } else {
    print "<td><tt>&nbsp;$highion&nbsp;</tt></td>\n";
  }

  print ("  <td nowrap>&nbsp;");

  if ( ($highion > $mhplus) && (!$ispair) ) {
      # let charge up or down
	$chargeup=$charge+1;
	$chargedn=$charge-1;
	if ( ($chargedn > 0) && (!grep(/^$dtabase.$chargedn.dta$/, @allfiles)) ) {
		print "z = $charge:  <a href=\"$ourname?directory=$dirname&chfile=$dtafile&chset=$chargedn\">Decrement</a>&nbsp;&nbsp;";
	} else {
		print "z = $charge:  -&nbsp;&nbsp;";
	}

	if ( ($chargeup <= 5) && (!grep(/^$dtabase.$chargeup.dta$/, @allfiles)) ) {
		print "<a href=\"$ourname?directory=$dirname&chfile=$dtafile&chset=$chargeup\">Increment</a>";
	} else {
		print ("-");
	}
  } elsif ($ispair) {
      # found dta3file
      # 12/13 wsl link to view spectrum before banishing
      push(@dtapairs, $dta3file); # place in @dtapairs so that the matching dta3 is not printed
      print "<b>2+/3+ Pair</b>&nbsp;";
      
      print "Banish <a href=\"$ourname?directory=$dirname&banish=$dtabase&bancharge=2\">2+</a> <a href=\"$ourname?directory=$dirname&banish=$dtabase&bancharge=3\">3+</a>"; 
  } else {
      # let charge up or down
	$chargeup=$charge+1;
	$chargedn=$charge-1;
	if ( ($chargedn > 0) && (!grep(/^$dtabase.$chargedn.dta$/, @allfiles)) ) {
		print "z = $charge:  <a href=\"$ourname?directory=$dirname&chfile=$dtafile&chset=$chargedn\">Decrement</a>&nbsp;&nbsp;";
	} else {
		print "z = $charge:  -";
	}

	if ( ($chargeup <= 5) && (!grep(/^$dtabase.$chargeup.dta$/, @allfiles)) ) {
		print "<a href=\"$ourname?directory=$dirname&chfile=$dtafile&chset=$chargeup\">Increment</a>";
	} else {
		print ("-");
    }
  }

  if ( (($charge==3) || ($charge==2)) && (grep(/^$banfile$/, @allfiles))) {
    # found banished file
    # 12/13 wsl link to view spectrum before banishing
    #print "  <TD><a href=\"$displayions?Dta=$dir/$banfile\" target=_blank>.$notcharge.dta.banished</a></td>\n"; # wsl 12/14
      print "&nbsp;&nbsp;<a href=\"$ourname?directory=$dirname&unbanish=$dtabase&unbancharge=$notcharge\">Unbanish $notcharge+</a>";
  }

  # let charge reset
  if ($o=&orig_charge($dtabase)) {
      print "&nbsp;&nbsp;<a href=\"$ourname?directory=$dirname&chreset=$dtabase&curch=$charge\">Reset to z=$o</a>\n";
  }
  print ("&nbsp;</td>\n");

  ## the following added by Martin 05/19/98:
  # links to the zoom files for visual evaluation
  
  print ("<td>&nbsp;");

  
  ## new code, added by Martin to use lcq_zta_list.txt 98/07/19
  my (@zoomscans) = &get_zoomscans ($dir, $dtafile);
  my ($n);

  foreach $zta (@zoomscans) {
    ($n) = $zta =~ m!.*\.(\d+)\.zta!i;

    print qq(<a href="$zoomdisplay?Dta=$dir/$zta" target=_blank>$n</a> );
  }

  print ("&nbsp;</td>");

#  print "</tr>\n";
}

print "</table>";
#print qq(<input type="submit" class="button" name="selectall" value="$banishall">
#	 <input type="submit" name="selectall" value="$unbanishall">);

sub read_dta {
  my($dtafile)=@_;
  my($dta3file, $dta2file, @datax, @data3, @firstline, @lastline, $mhplus, $mh3, $mh2, $highion, $charge, $precursor);

  $dta4file=$dtabase . ".4.dta";
  $dta3file=$dtabase . ".3.dta";
  $dta2file=$dtabase . ".2.dta";
  $dta1file=$dtabase . ".1.dta";

  open DTA, "$dir/$dtafile"; @datax=<DTA>; close DTA;
  @firstline=split(' ', $datax[0]);
  @lastline=split(' ', $datax[$#datax]);
  $mhplus=$firstline[0];
  $charge=$firstline[1];
  $highion=$lastline[0];
  $precursor = ( ($mhplus - $Mono_mass{'Hydrogen'}) / $charge) + $Mono_mass{'Hydrogen'};
#  $precursor=$highion;
  
  open DTA, "$dir/$dta2file";
  $_=<DTA>; @firstline=split(/ /, $_);
  close DTA;
  $mh2=$firstline[0];

  return($mhplus, $charge, $highion, $precursor);
}

sub read_dta_tom {
  my($dtabase)=@_;
  my($dta3file, $dta2file, @data3, @firstline, @lastline, $mh3, $mh2, $highion);

  $dta4file=$dtabase . ".4.dta";
  $dta3file=$dtabase . ".3.dta";
  $dta2file=$dtabase . ".2.dta";
  $dta1file=$dtabase . ".1.dta";

  open DTA, "$dir/$dta3file"; @data3=<DTA>; close DTA;
  @firstline=split(/ /, $data3[0]);
  @lastline=split(/ /, $data3[$#data3]);
  $mh3=$firstline[0];
  $highion=$lastline[0];
  
  open DTA, "$dir/$dta2file";
  $_=<DTA>; @firstline=split(/ /, $_);
  close DTA;
  $mh2=$firstline[0];

  return($mh3, $mh2, $highion);
}

sub banish_dta {
    # 10 April 1998, thomas
    # generalized banishing (user chooses charge 2 or 3)
    my($banish, $bancharge)=@_; # input is a dtabasename, charge to banish
    my($origfile, $banfile, $status);

    $origfile = $banish . ".$bancharge.dta";
    $banfile = $banish . ".$bancharge.dta.banished";
    if (grep(/$origfile/, @dtafiles)) {
	# no sanity checks for existence of other dta files
	$status = rename "$dir/$origfile", "$dir/$banfile";

	# delete any existing OUT file related to $origfile (added cmw, 6-26-98)
	# code borrowed from microchem_include: &delete_files
	($root1,$root2) = ($origfile =~ /^(.+)\.(\d+\.\d)\.dta$/);
	$out = "$root1.$root2.out";
	unlink "$dir/$out" if (-e "$dir/$out");

	if ($status == 0) {
	    print "<BR>Banish $banish.$bancharge failed!";
	}
    }
}

sub unbanish_dta {
    # generalized unbanish
    # pass dta base and charge of banished dta
    my($unbanish, $unbancharge)=@_;
    $banfile = $unbanish . ".$unbancharge.dta.banished";
    $dtafile = $unbanish . ".$unbancharge.dta";
    if (grep(/$banfile/, @allfiles)) {
	$status = rename "$dir/$banfile", "$dir/$dtafile";
	if ($status == 0) {
	    print "<BR>Unbanish $banfile failed!";
	}
    }
}

sub set_prof {
    # sets lcq_profile(dtabase) to dtabase.chset
    my($dtafile, $chset) = @_;
    my(@profdata, $dtabase);
    $dtabase = $dtafile; $dtabase=~s/\.\d\.dta$//;

    open(PROF, "$dir/lcq_profile.txt");
    while ($_=<PROF>) {
	if (grep(/^$dtafile.*/, $_)) {
	    substr($_, 0, length("$dtabase.$chset.dta")) = "$dtabase.$chset.dta";
	}
	push(@profdata, $_);
    }
    close PROF;
    open(PROF, "> $dir/lcq_profile.txt");
    print PROF @profdata;
    close PROF;
}

sub set_charge {
	my($dtafile, $chset)=@_;
	my($mhplus, $charge, $highion, $precursor, $newdta, $dtabase);

	$dtabase = $dtafile; $dtabase=~s/\.\d\.dta$//;

	# remove the old dta file, create a new one with mhplus = chset,
	# written to chset.dta, old file backed up to xxx.old

	# we may want to check backup file existence

	($mhplus, $charge, $highion, $precursor)= &read_dta($dtafile);

	if (grep(/^$dtabase\.$chset\.dta$/, @dtafiles)) {
		return;
	}

	## be vewy vewy careful! says Martin 98/07/19
	## let's calculate the MH+ correctly and print only to two sig digs
	$newmhplus = ($precursor - $Mono_mass{'Hydrogen'}) * $chset + $Mono_mass{'Hydrogen'};
	$newmhplus = &precision ($newmhplus, 2);

	# open old dta and read in data
	open(DTA, "$dir/$dtafile");
	@olddata=<DTA>;
	close DTA;
	shift @olddata;

	open(DTA, ">$dir/$dtabase.$chset.dta");
	print DTA "$newmhplus $chset\n";
	print DTA @olddata;
	close DTA;

	# open profile and selected_dtas and change our line hum..
	set_prof($dtafile, $chset);
	set_selected($dtafile, $chset);

	# rename old file
        if ((grep(/^$dtabase.\d.dta.orig$/, @allfiles))) {
	    unlink "$dir/$dtafile";
	} else {
	    rename "$dir/$dtafile", "$dir/$dtafile.orig";
	}

	# delete any existing OUT file related to $dtafile (added cmw, 6-26-98)
	# code borrowed from microchem_include: &delete_files
	($root1,$root2) = ($dtafile =~ /^(.+)\.(\d+\.\d)\.dta$/);
	$out = "$root1.$root2.out";
	unlink "$dir/$out" if (-e "$dir/$out");
}

sub orig_charge {
    # returns 0 if no original charge file
    # returns original charge otherwise
    # parameter is dtabase
    my($dtabase)=@_;
    my($o, $i);
    if (grep(/^$dtabase.\d.dta.orig$/, @allfiles)) {
	$i=-1;
	$o="";
	while ($o eq "") {
	    $i++;
	    ($o) = ($allfiles[$i] =~ m/$dtabase.(\d).dta.orig/);
	}
	return $o;
    } else {
	return 0;
    }
}

sub reset_charge {
    my($dtabase, $curch)=@_;

    my($o, $dtafile, $origfile, $destfile);

    # compute filenames
    $dtafile = $dtabase . ".$curch.dta";
    $o = &orig_charge($dtabase);
    $origfile = $dtabase . ".$o.dta.orig";
    $destfile = $dtabase . ".$o.dta";

    if ( (grep(/^$dtafile$/, @allfiles)) && (grep(/^$origfile$/, @allfiles)) && (!grep(/^$destfile$/, @allfiles)) ) {
	if (rename "$dir/$origfile", "$dir/$destfile") {
          unlink "$dir/$dtafile";

	    # delete any existing OUT file related to $dtafile (added cmw, 6-26-98)
	    # code borrowed from microchem_include: &delete_files
	    ($root1,$root2) = ($dtafile =~ /^(.+)\.(\d+\.\d)\.dta$/);
	    $out = "$root1.$root2.out";
	    unlink "$dir/$out" if (-e "$dir/$out");

	    set_prof($dtafile, $o);
	    set_selected($dtafile, $o);
	}
    }
}

# added by cmwendl (6/11/98) to update selected_dtas.txt properly
# (code mostly stolen from &set_prof)
sub set_selected {
    # changes (dtabase) in selected_dtas.txt to dtabase.chset
    my($dtafile, $chset) = @_;
    my(@seldata, $dtabase);
    $dtabase = $dtafile; $dtabase=~s/\.\d\.dta$//;

    open(SELECTED, "$dir/selected_dtas.txt");
    while (<SELECTED>) {
	if (/^$dtafile/) {
	    substr($_, 0, length("$dtabase.$chset.dta")) = "$dtabase.$chset.dta";
	}
	push(@seldata, $_);
    }
    close SELECTED;
    open(SELECTED, "> $dir/selected_dtas.txt");
    print SELECTED @seldata;
    close SELECTED;
}




sub output_form {
  print "<hr><br>\n";
  print qq(<FORM ACTION="$ourname" METHOD=POST>);

  &get_alldirs;
  print "<span class=\"dropbox\"><SELECT name=\"directory\">\n";
  
  foreach $dir (@ordered_names) {
    print qq(<option value="$dir">$fancyname{$dir}\n);
  }
  print "</select></span>\n";

  print qq(<input type="submit" class="button" value="verify" name="verify">&nbsp;);
}

sub tail {
  print "</body></html>\n";
}

#close LOG;

