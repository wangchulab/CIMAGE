#!/usr/local/bin/perl

#-------------------------------------
#	SampleList Trimmer
#	(C)1998 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


## This is a script to allow us to trim the samplelist,
## deleting unwanted directories.

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
require "flatfile_lib.pl";

&MS_pages_header ("Trimmer", "#6B4226");
print "<HR><P>\n";

&cgi_receive();

## process any input
$dirs = $FORM{"directory"};
$checknum = $FORM{"checknum"};


if ($dirs) {
  if ($checknum) {
    &delete_dirs();

  } else {
    &warning_page();
  }

  exit();
}

## If no input, display each of the subdirectory names, sorted by date,
## with checkboxes for selection

## open the Sequest directory, and find out all of its subdirectories:
opendir (SEQDIR, $seqdir) || die ("can't open Sequest dir");
# the following is a yucky but efficient way to recycle the stat call
# Addition by Ulas: any dir that starts with uchem doesn't appear
@alldirs = grep { /^[^\.]/ && !(/^uchem/) && -d "$seqdir/$_" &&
		    ($mtime{$_} = (stat (_))[9])} readdir (SEQDIR);
closedir SEQDIR;

&calc_dir_datestamps();
&calc_dir_allzips ();

# Added by Ulas to enable different sorting schemes. Default is Datestamp
if($FORM{'sort'} eq 'name') {
	@alldirs = sort byName @alldirs;
} else {
	@alldirs = sort byDatestamp @alldirs;  # The default
}

sub byDatestamp { $datestamp{$a} cmp $datestamp{$b}; }
sub byName { $a cmp $b; }

print <<EOM;

<h4>Selected directories will be <span style="color:red"><b>deleted</b></span>. No
<span style="color:magenta">if</span>s, <span style="color:magenta">and</span>s,
or <span style="color:magenta">but</span>s.</h4>

<div>
<FORM ACTION="$ourname" METHOD=POST>

<B>Select:</B>
<A HREF="javascript:checkAll()"><IMAGE SRC="$webimagedir/all.gif" BORDER=0 WIDTH=38 HEIGHT=25 ALIGN=TEXTTOP></A>
<A HREF="javascript:uncheckAll()"><IMAGE SRC="$webimagedir/none.gif" BORDER=0 WIDTH=38 HEIGHT=25 ALIGN=TEXTTOP></A>


<SCRIPT LANGUAGE="JavaScript">
<!--
    function uncheckAll()
    {
	for (i = 0; i < document.forms[0].elements.length; i++)
	{
	    if (document.forms[0].elements[i].name == "directory")
		document.forms[0].elements[i].checked = 0;
	}
    }
    function checkAll()
    {
	for (i = 0; i < document.forms[0].elements.length; i++)
	{
	    if (document.forms[0].elements[i].name == "directory")
		document.forms[0].elements[i].checked = 1;
	}
    }
//-->
</SCRIPT>
&nbsp;&nbsp;&nbsp;&nbsp;
<INPUT TYPE=SUBMIT CLASS=button VALUE="Delete Selected">
Sort by:
<A HREF="trimmer.pl?sort=datestamp">Datestamp</a>
<A HREF="trimmer.pl?sort=name">Name</a>
<TABLE>
<TR>
<TD></TD>
<TD>Directory Name</TD>
<TD>Datestamp</TD>
<TD>Zip Date</TD>
</TR>
EOM

foreach $dir (@alldirs) {
	  print <<EOM;
<TR>
<TD><INPUT TYPE=CHECKBOX NAME="directory" VALUE="$dir"></TD>
<TD><a href="$webseqdir/$dir">$dir</a></TD>
<TD width=170>$datestamp{$dir}</TD>
<TD>$allzips{$dir}</TD>
</TR>
EOM
}

## the JavaScript to select/unselect all is taken from Chris Wendl's code
## in RunSummary  -- Martin

print ("</TABLE></FORM>\n");
print "</div></body></html>\n";

exit();

## this finds what directories have a backup and stores the dates of the backups in @allzips

sub calc_dir_allzips {
  my ($zipname, $d);
  
  foreach $d (@alldirs) {
    $zipname = ($seqdir . "/" . $d . ".zip");
    
  if (-e $zipname) {

      @PStats = stat $zipname;
      my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime($PStats[9]);
      $year += 1900;
      $month++;
      $month = "0" . $month if ($month < 10);
      $mday = "0" . ($mday) if ($mday < 10);
	$allzips{$d} = join ("_", $year, $month, $mday);

    } else {
      $allzips{$d} = "";
    }
  }
}


## this finds the dirs' datestamps, and puts that into
## the global var %datestamp

sub calc_dir_datestamps {
  my ($firstline, $line, @names, @info, $i, %entry, $d);
  my ($lastmod, $header, $key, $dummy);

  ## check the samplelist first:
  if (open (SLIST, "$SAMPLELIST")) {
    $firstline = <SLIST>;
    chomp $firstline;
    $firstline =~ tr/A-Z/a-z/;

    # get the names of the field entries from the top line
    @names = split (/:/, $firstline);

    while ($line = <SLIST>) {
      chomp $line;
      %entry = ();
      @info = split (/:/, $line);

      for ($i = 0; $i <= $#names; $i++) {
        $entry{$names[$i]} = $info[$i];
      }

      $d = $entry{"directory"};
      $datestamp{$d} = $entry{"datestamp"};
    }
    close SLIST;
  }

  ## next, check each directory not already covered for
  ## its datestamp, in a Header.txt file

  foreach $d (@alldirs) {
    next if ($datestamp{$d} && $datestamp{$d} ne "");

    $lastmod = 0;
    $header = "$seqdir/$d/Header.txt";
    %entry = ();

    if (open (HEADER, "$header")) {
      $lastmod = (stat ("$header"))[9];

        foreach $line (<HEADER>) {
	    chomp $line;
          $line =~ /([^:]*):([^:]*)/;
          ($key = $1) =~ tr/A-Z/a-z/;
          $entry{$key} = $2;
	  }
      close HEADER;
    } else {
      $lastmod = (stat ("$seqdir/$d") )[9];
    }

    if ($entry{"datestamp"} && $entry{"datestamp"} ne "") {
      $datestamp{$d} = $entry{"datestamp"};

    } else {
      # turn $lastmod into the form YYYY_MM_DD
      my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) =
	    localtime($lastmod);
      $year += 1900;
      $month++;
      $month = "0" . $month if ($month < 10);
      $mday = "0" . ($mday) if ($mday < 10);

      $datestamp{$d} = "no datestamp; last modified " . join ("_", $year, $month, $mday);
    }
  }
}

## make sure the user wants to delete these directories
sub warning_page {
  my (@dirs) = split (", ", $dirs);
  my ($num) = scalar @dirs;

  print <<EOM;
<div>

<h5>Are you sure you want to delete these directories?</h5>

You have selected $num directories to be deleted.

<FORM ACTION="$ourname" METHOD=POST>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Go Ahead, Delete">
<A HREF="$ourname">Start Over</a>
<INPUT TYPE=HIDDEN NAME="checknum" VALUE="1">
<p>
EOM

  foreach $dir (@dirs) {
    print <<EOM;
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">$dir<br>\n
EOM
  }
  print ("</FORM></div>\n");
}

sub delete_dirs {
  my (@dirs) = split (", ", $dirs);
  my ($errcode);
  my (@baddirs);
  my (@gooddirs);

  foreach $dir (@dirs) {
	opendir (DIR, "$seqdir/$dir");
	@allfiles = grep !/^\.\.?$/, readdir DIR;
	closedir DIR;
	unlink map "$seqdir/$dir/$_", @allfiles;

    $errcode = (rmdir "$seqdir/$dir") ? 0 : $!;

    if ($errcode) {
	    push (@baddirs, $dir);
    } else {
	    push (@gooddirs, $dir);
		(@error) = &removefrom_flatfile ($dir);
    }
  }
  
  print ("<p><div>\n");

  if (scalar @baddirs) {
    print ("<b>The following directories were NOT deleted:</b><p>\n");
    print join ("<br>\n", @baddirs);
    print ("<p>\n");
  }

  if (scalar @gooddirs) {
    print ("<b>The following directories were successfully deleted:</b><p>\n");
    print join ("<br>\n", @gooddirs);
    print ("<p>\n");

	if (shift @error) {		# returns 1 on error, 0 on success
		print "Update of flatfile failed: @error.\n";
	} else {
		print ("Update of flatfile successful.\n");
	}
  }
  print "</div>\n";
}
