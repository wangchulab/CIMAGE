#!/usr/local/bin/perl

#-------------------------------------
#	DTA Control,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/C. M. Wendl/T. A. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



# a version of DTA Banisher for operating on a single DTA
# code recycled somewhat from dta_banisher.pl


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


# grab options
$myfile = $FORM{'dtafile'};
$newMHplus = $FORM{'MHplus'};
$dirname = $FORM{'directory'};
$chset = $FORM{'chset'};
$delete = $FORM{'delete'};
$operator = $FORM{'operator'};


if (!defined $myfile) {
	if (!defined $dirname) {
		&output_form;
	} else {
		&getdta_form;
	}
}



# if $myfile is a ZTA file (passed from zoomdisplay), convert to DTA
if ($myfile =~ /\.zta$/) {
	($dirname,$ztaname) = ($myfile =~ m!$seqdir/(.+?)/(.+\.zta)$!i);
	$filename = &zta2dta("$seqdir/$dirname",$ztaname);
	$myfile =~ s/$ztaname/$filename/;	

} else {
	($dirname,$filename) = ($myfile =~ m!$seqdir/(.+?)/(.+\.dta)$!i);
}
($fileroot) = ($filename =~ /^(.+)\.[x\d]\.dta$/);
$dir="$seqdir/$dirname";  # this is somewhat insecure


# fast file glob
&read_data;

sub read_data {

  opendir CURRDIR, "$dir";
  @relevantfiles = grep /$fileroot/, readdir CURRDIR;
  closedir CURRDIR;
  # glob for *.2.dta
  @dta2files=grep(/^.*\.2\.dta$/, @relevantfiles);
  @dta3files=grep(/^.*\.3\.dta$/, @relevantfiles);
  $ispair = (@dta2files && @dta3files);
  # glob for all dta files -wsl 12/14
  @dtafiles=grep(/^.*\.dta$/, @relevantfiles);

}


if ((defined $FORM{"setMHP"}) || (defined $FORM{"setMHP2"}) || (defined $FORM{"setMHP3"})) {
	# change MH+

	if (defined $FORM{"setMHP2"}) {
		$dtafile = $dta2files[0];
		$newMHplus = $FORM{"MHplus2"};
	} elsif (defined $FORM{"setMHP3"}) {
		$dtafile = $dta3files[0];
		$newMHplus = $FORM{"MHplus3"};
	} else {
		$dtafile = $dtafiles[0];
	}

	open(DTAFILE,"<$dir/$dtafile");
	@DTAlines = <DTAFILE>;
	close(DTAFILE);
	$DTAlines[0] =~ s/(\S+)(\s+\S+)/$newMHplus$2/;

	open(DTAFILE,">$dir/$dtafile");
	foreach (@DTAlines) {
		print DTAFILE $_;
	}
	close DTAFILE;

	&redirect("$ourname?dtafile=$dir/$fileroot.x.dta&operator=$operator");
	exit;

}


if (defined $delete) {
  $operator = $FORM{"operator"};
#  if ($operator) {			# op. initials no longer required
	$operator =~ tr/A-Z/a-z/;

	if ($delete eq "Delete 2+") {
		@gonners = @dta2files;
	} elsif ($delete eq "Delete 3+") {
		@gonners = @dta3files;
	} else {
		@gonners = @dtafiles;
	}

	unless (&delete_files(map "$dir/$_", @gonners))
	{
		&MS_pages_header("DTA Control", "#3F9F5F");
		my $fileid = ($#gonners > 0) ? "One of the files you've tried to delete" : "The file $gonners[0]";
		&error("$fileid cannot be deleted right now.<br>Is SEQUEST running?"); 
		exit;
	}
	&update_selected_dtas($dirname);

	# log
	my $now = localtime();
	$logentry = "DTA Control deleted " . join(" and ",@gonners) . "  $now  $operator";
	&write_log($dirname,$logentry);
	&write_deletionlog($dirname,$logentry,\@gonners);

	if (($delete eq "Delete 2+") || ($delete eq "Delete 3+")) {
		&redirect("$ourname?dtafile=$dir/$fileroot.x.dta&operator=$operator");
		exit;
	} else {
		&MS_pages_header("DTA Control", "#3F9F5F");
		print "<HR><P>" . join(" and ",@gonners) . " deleted.<P>\n";
		print "<A HREF=\"$ourname?directory=$dirname\">Pick another DTA</A>\n";
		&tail;
		exit;
	}
#  } else {
#
#	&MS_pages_header("DTA Control", "#3F9F5F");
#	&error("You must enter your initials in the <i>Operator</i> field.");
#	exit;
#  }
}


if ((defined $FORM{"setZ"}) && ($chset>0)) {
  # if it's a 2+/3+ pair, delete 3+ and set charge of 2+
  if ($ispair) {
	if ($chset == 2) {
		unless (&delete_files("$dir/$dta3files[0]"))
		{
			&MS_pages_header("DTA Control", "#3F9F5F");
			&error("The file $dta3files[0] cannot be deleted right now.<br>Is SEQUEST running?"); 
			exit;
		}
		&update_selected_dtas($dirname);
		&redirect("$ourname?dtafile=$dir/$fileroot.x.dta&operator=$operator");
	} elsif ($chset == 3) {
		unless (&delete_files("$dir/$dta2files[0]"))
		{
			&MS_pages_header("DTA Control", "#3F9F5F");
			&error("The file $dta2files[0] cannot be deleted right now.<br>Is SEQUEST running?"); 
			exit;
		}
		&update_selected_dtas($dirname);
		&redirect("$ourname?dtafile=$dir/$fileroot.x.dta&operator=$operator");
	} else {
		unless (&delete_files("$dir/$dta3files[0]"))
		{
			&MS_pages_header("DTA Control", "#3F9F5F");
			&error("The file $dta3files[0] cannot be deleted right now.<br>Is SEQUEST running?"); 
			exit;
		}
		&update_selected_dtas($dirname);
		&set_charge($dta2files[0], $chset);
	}
  } else {
	&set_charge($filename, $chset);
  }
}


&MS_pages_header("DTA Control", "#3F9F5F", $nocache);

unless (@dtafiles) {
	print("<hr><p>There are no files $fileroot.*.dta.<P><A HREF=\"$ourname?directory=$dirname\">Pick another DTA</A>");
	exit;
}



# presentation header
print <<EOH;
<HR>
<p><b><a href=\"$webseqdir/$dirname\">$dir</a>&nbsp;&nbsp;<a href=\"$viewheader?directory=$dirname\">Info</a></b></p>

<table cellspacing=0 BORDER=0>
<tr><th>&nbsp; Scans &nbsp;</th><th>&nbsp; z &nbsp;</th><th>&nbsp; m/z &nbsp;</th><th>&nbsp; MH+ &nbsp;</th>
<th nowrap>&nbsp; Max Ion &nbsp;</th>
<th>&nbsp; Zoom files &nbsp;</th>
EOH


# this used to be a loop over @dtafiles

  $dtafile = $dtafiles[0];

  $dtabase=$dtafile; $dtabase=~s/\.\d\.dta$//; # base for all filenames

  if ($ispair) {
	  $dta2file = $dta2files[0];
	  $dta3file = $dta3files[0];
	  ($mhplus[0], undef, $highion, $precursor) = &read_dta($dta2file);
	  ($mhplus[1], undef, undef, undef) = &read_dta($dta3file);
  } else {
	  ($mhplus, $charge, $highion, $precursor) = &read_dta($dtafile);
	  @mhplus = ($mhplus);	# useful for generality with 2+/3+ pairs
  }

  $scans=$dtabase;
  $scans=~s/[\w|\d|\-]+\.(\d+)\.(\d+)/$1-$2/; # remove hyphens, prefix
  
  $disp_link = ($ispair) ? $dta3file : $dtafile;
  print "<tr><TD nowrap align=center><tt>&nbsp;<a href=\"$displayions?Dta=$dir/$disp_link\">$scans</a>&nbsp;</tt></td>\n";

  if ($ispair) {
	  print "  <td align=center><tt>2+/3+</tt></td>\n";
  } else {
	  print "  <td align=center><tt>$charge+</tt></td>\n";
  }

  $precursor=&precision($precursor, 2);
  if ($precursor<1000) {
    $precursor="&nbsp;$precursor";
  }
  print "  <td><tt>&nbsp;$precursor&nbsp;</tt></td>\n";

  foreach $mhplus (@mhplus) {
	  $mhplus=&precision($mhplus, 2);
	  if ($mhplus >= 1.5*$highion) {
		$mhplus = "<b>$mhplus</b>";
	  } else {
		$mhplus = "$mhplus";
	  }
  }
  if ($ispair) {
	  print "<td><tt>$mhplus[0]/$mhplus[1]</tt></td>";
  } else {
	  print "<td><tt>$mhplus</tt></td>";
  }

  if ($highion<1000) {
    $highion="&nbsp;$highion";
  }
  if ( ($highion > $mhplus) || ($ispair) ) {
    print "<td><tt>&nbsp;<b>$highion</b>&nbsp;</tt></td>\n"; # change color
  } else {
    print "<td><tt>&nbsp;$highion&nbsp;</tt></td>\n";
  }


  ## the following added by Martin 05/19/98:
  # links to the zoom files for visual evaluation
  
  print ("<td>&nbsp;");

  
  ## new code, added by Martin to use lcq_zta_list.txt 98/07/19
  my (@zoomscans) = &get_zoomscans ($dir, $dtafile);
  my ($n);

  foreach $zta (@zoomscans) {
    ($n) = $zta =~ m!.*\.(\d{4})\.zta!i;

    print qq(<a href="$zoomdisplay?Dta=$dir/$zta">$n</a> );
  }

  print ("&nbsp;</td>");

print "</table>";


foreach (@mhplus) {
	s!<b>!!ig;
	s!</b>!!ig;
}

if ($ispair) {
  print <<EOF;
<p>
<form action="$ourname" method=get><input type=hidden name="dtafile" value="$dir/$dta2file">
<table cellspacing=0 cellpadding=0>
<tr><td align=right>Set MH+ of 2+:&nbsp;</td>
<td><INPUT NAME="MHplus2" value="$mhplus[0]" size=8></td>
<td><INPUT TYPE=submit CLASS=button name="setMHP2" VALUE="Change"></td>
</tr>
<tr><td align=right>Set MH+ of 3+:&nbsp;</td>
<td><INPUT NAME="MHplus3" value="$mhplus[1]" size=8></td>
<td><INPUT TYPE=submit CLASS=button name="setMHP3" VALUE="Change"></td>
</tr>
<tr>
<td align=right>Set Charge:&nbsp;</td>
<td><span class=dropbox><SELECT NAME="chset">
<OPTION VALUE="0">-
<OPTION VALUE="1">1+
<OPTION VALUE="2">2+
<OPTION VALUE="3">3+
<OPTION VALUE="4">4+
<OPTION VALUE="5">5+
<OPTION VALUE="6">6+
<OPTION VALUE="7">7+
<OPTION VALUE="8">8+
</SELECT></span>
</td>
<td><INPUT TYPE=submit CLASS=button NAME="setZ" VALUE="Change"></td>
</tr>
<tr><td>&nbsp;</td></tr>
<tr>
<td colspan=3 align=center>
Op: <input name="operator" value="$operator" size=3>&nbsp;
<input type=submit CLASS=button name="delete" value="Delete Both"><p>
<input type=submit CLASS=button name="delete" value="Delete 2+">&nbsp;<input type=submit CLASS=button name="delete" value="Delete 3+">
</td></tr>

</table>
</form>
EOF
} else {
  print <<EOF;
<p>
<form action="$ourname" method=get><input type=hidden name="dtafile" value="$dir/$dtafile">
<table cellspacing=0 cellpadding=0>
<tr><td align=right>Set MH+:&nbsp;</td>
<td><INPUT NAME="MHplus" value="$mhplus" size=8></td>
<td><INPUT TYPE=submit CLASS=button name="setMHP" VALUE="Change"></td>
</tr>
<tr>
<td align=right>Set Charge:&nbsp;</td>
<td><span class=dropbox><SELECT NAME="chset">
<OPTION VALUE="0">-
<OPTION VALUE="1">1+
<OPTION VALUE="2">2+
<OPTION VALUE="3">3+
<OPTION VALUE="4">4+
<OPTION VALUE="5">5+
<OPTION VALUE="6">6+
<OPTION VALUE="7">7+
<OPTION VALUE="8">8+
</SELECT></span>
</td>
<td><INPUT TYPE=submit CLASS=button NAME="setZ" VALUE="Change"></td>
</tr>
<tr><td>&nbsp;</td></tr>
<tr>
<td colspan=3 align=center>
Op: <input name="operator" value="$operator" size=3>&nbsp;<input type=submit CLASS=button name="delete" value="Delete">
</td></tr>

</table>
</form>
EOF
}


sub read_dta {
  my $dtafile = shift;
  my(@datax, @firstline, @lastline, $mhplus, $highion, $charge, $precursor);

  open DTA, "$dir/$dtafile"; @datax=<DTA>; close DTA;
  @firstline=split(' ', $datax[0]);
  @lastline=split(' ', $datax[$#datax]);
  $mhplus=$firstline[0];
  $charge=$firstline[1];
  $highion=$lastline[0];
  $precursor = ( ($mhplus - $Mono_mass{'Hydrogen'}) / $charge) + $Mono_mass{'Hydrogen'};

  return($mhplus, $charge, $highion, $precursor);
  
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

	# rename old file
        if ((grep(/^$dtabase.\d.dta.orig$/, @relevantfiles))) {
	    unless (unlink "$dir/$dtafile")
	    {
		&MS_pages_header("DTA Control", "#3F9F5F");
		&error("The file $dtafile cannot be deleted or renamed right now.<br>Is SEQUEST running?"); 
		exit;
	    }
	} else {
	    unless (rename "$dir/$dtafile", "$dir/$dtafile.orig")
	    {
		&MS_pages_header("DTA Control", "#3F9F5F");
		&error("The file $dtafile cannot be deleted or renamed right now.<br>Is SEQUEST running?"); 
		exit;
	    }
	}

	open(DTA, ">$dir/$dtabase.$chset.dta");
	print DTA "$newmhplus $chset\n";
	print DTA @olddata;
	close DTA;

	# open profile and selected_dtas and change our line hum..
	set_prof($dtafile, $chset);
	set_selected($dtafile, $chset);


	# delete any existing OUT file related to $dtafile (added cmw, 6-26-98)
	# code borrowed from microchem_include: &delete_files
	($root1,$root2) = ($dtafile =~ /^(.+)\.(\d+\.\d)\.dta$/);
	$out = "$root1.$root2.out";
	unlink "$dir/$out" if (-e "$dir/$out");

	&redirect("$ourname?dtafile=$dir/$fileroot.x.dta&operator=$operator");
	exit;

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

  &MS_pages_header("DTA Control", "#3F9F5F");
  print "<hr><br><div>\n";
  print qq(<FORM ACTION="$ourname" METHOD=get>);

  &get_alldirs;


  print "Pick a directory:<br>\n";
  print "<span class=dropbox><SELECT name=\"directory\">\n";
  
  foreach $dir (@ordered_names) {
    print qq(<option value="$dir">$fancyname{$dir}\n);
  }
  print "</select></span>\n";
  print qq(<input type="submit" CLASS=button value="Continue">&nbsp;);
  print "</div></body></html>\n";

  exit;

}


sub getdta_form {

  &MS_pages_header("DTA Control", "#3F9F5F");
  print "<hr><br>\n";
  print qq(<FORM ACTION="$ourname" METHOD=get>);

  print "<p><b><a href=\"$webseqdir/$dirname\">$seqdir/$dirname</a>&nbsp;&nbsp;<a href=\"$viewheader?directory=$dirname\">Info</a></b></p>"; # link to dir for user double check

  opendir(DIR,"$seqdir/$dirname") || &error("Cannot access directory $dirname.");
  @dtas = grep /\.dta$/, readdir(DIR);
  closedir DIR;

  print "<div>Pick a DTA file:<br>\n";
  print "<span class=dropbox><SELECT name=\"dtafile\">\n";
  
  foreach $dta (@dtas) {
    print qq(<option value="$seqdir/$dirname/$dta">$dta\n);
  }
  print "</select></span>\n";
  print qq(<input type="submit" CLASS=button value="Continue">&nbsp;);
  print "<p><a href=\"$ourname\">Pick another directory</a>";
  print "</div></body></html>\n";

  exit;

}



sub tail {
  print "</body></html>\n";
}



sub error {

	print "<h3>Error:</h3><div>" . join("<BR>",@_) . "</div></body></html>";

}