#!/usr/local/bin/perl
#-------------------------------------
#	Consensi Synopsi,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#       C. M. Wendl/T. Kim
#
#	v3.1a
#	
#	licensed to Finnigan
#
#       2/27/98 T.Kim added database descriptor line
#-------------------------------------


# must be in "#AABBCC" form:
@rank_colour = ("#FF0000", "#0000FF", "#008000", "#FF00FF", "#C87800", "#C00000", "#000080",  "#800080", "#C0C0C0", "#8C1717");
# cmw 27.9.98: a very crude way to create 42 new colors automatically (and none of them too bright)
$colournum = 100000;
for ($i = $#rank_colour + 1; $i < 52; $i++) {
	$rank_colour[$i] = "#$colournum";
	$colournum += 16667;
}
$num_ranks_to_colour = $#rank_colour + 1;


# letters for labeling consensi
$consensi_letterstr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

$MAX_NUM_CONSENSI = length ($consensi_letterstr);

##
## a note on the internals:
##
## Some associative arrays, like %selected, are indexed by the truncated
## file name. Most of the linear arrays are indexed by the index of the
## file in @outs. This is given by $number{<truncated filename>}
##
## Most of the associative arrays have an entry for each poss. peptide
## hit in each .out file. These are indexed by "a:b", where a is the
## index of the file in @outs, and b is the rank of the hit in the .out.
##
## thus, the most significant hit from $file has its deltaCn value
## in $deltaCn{ "$number{$file}:1" }
##

##
## some of the assoc arrays:
## $number{$file} is the number given to the file named "$file". $file is
##                is the name of the file, minus the ".out" suffix.
## $outs[$i]      is the file name for the file number $i, so %number and @outs are inverse
##
## $level_in_file{"$i:$ref"} is the highest ranking, within a .out file, of the
##                reference "$ref" in the file with file number $i.
## $ref_long_form{$ref} is the longest reference whose shortened version is $ref


# the points given to each member of each category:
@scorearr = (10, 8, 6, 4, 2, 1);

# the number of separate scoring categories we keep
# if this is 6, we have categories for 1st, 2nd, 3rd, 4th, and 5th hits, and one for all others
$numscores = $#scorearr + 1;

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
require "fastaidx_lib.pl";

&cgi_receive();

  &MS_pages_header ("Consensi Synopsi", 0 , "heading=" . <<EOM );
<span style="color:#0080C0">Consensi</span> <span style="color:#0000FF">Synopsi</span>
EOM
print "<HR><P>\n";

$directories = $FORM{"directories"};

if (!defined $directories) {
  &output_form();
  exit;
}

# !! temp martin's added code:
$MAX_RANK = $FORM{"max_rank"};
$MAX_RANK = 3 if $MAX_RANK == 0;
$new_algo = "CHECKED";

# max_rank option
print <<EOM;
<FORM method=post action="$ourname">
<INPUT type=hidden name="directories" value="$directories">
<span class="smallheading">Max Rank: </span><INPUT type=text name="max_rank" size=2 maxlength=2 value="$MAX_RANK">
<input type=submit class=button value="Run"></FORM>
EOM

@dirs=split(/, /, $directories);

foreach $directory (@dirs) {
    # reset some very important global variables
    undef %consensus_refs;
    undef %location;
    undef %other_refs;
    undef %consensus_colour_rank;
    undef %consensus_pos;
    undef %level_in_file;
    undef @consensus_groupings;
    undef @ranking;

    chdir "$seqdir/$directory" || &chdir_error("$seqdir/$directory");

    opendir (DIR, ".");
    @outs = grep { (! -z ) && s!\.out$!!i } readdir(DIR);
    closedir DIR;

    @outs = sort {$a cmp $b} @outs; # sort alphabetically
    $numouts = $#outs + 1;

    for ($i=0; $i<$numouts; $i++) {
	$number{$outs[$i]} = $i;
    }

    &process_outfiles();

    &read_profile();

# the following analyzes data but does not print anything; &print_consensi
# does that.
    &group_and_score();

    @orderedouts = &do_sort_outs (@outs);

    $reflen = 10; # the maximum length of the reference field

## calculate reflen so that all references have enough space:
##
    foreach $file (@outs) {
	$i = $number{$file};
	$index = "$i:1";
	$l = length ($ref{$index});
	
	if (defined $ref_more{$index}) {
	    $l += length ($ref_more{$index}) + 1;
	}
	$reflen = $l if ($l > $reflen);
    }
    
    $dbavail = &openidx("$dbdir/$database[0]");

    &print_top();
    
    print "<p>\n";

    &print_data();
    
#    &print_consensi();
    
    &closeidx();    
}

##
## this prints the buttons and info at the top of the page (after the header)
##

sub print_top {
  my ($db, $mtime, $dbdate, $massname, $file_string, $url);
  my ($day, $month, $year, $t, $temp); # $t is a dummy variable
  my ($check, $enzyme); # used to construct regexps so that we don't count
               # multiple databases more than once
  
  ## check for Mono or Avg mass:

  $temp = $masstype[0];
  foreach $val (@masstype) {
    next if ($temp == $val);
    $temp = 2;
    last;
  }
  if ($temp == 2) {
    $massname = "Mixed";
  } else {
    $massname = $temp ? "Mono" : "Avg";
  }

  ## check for databases used

  $db = $database[0];
  $temp = "";
  $check = "\Q$db\E";

  foreach $val (@database) {
    next if ($val =~ m!^($check)$!);
    $temp .= " $val";
    $check .= "|\Q$val\E";
  }

  $mtime = (stat("$dbdir/$db"))[9];
  ($t, $t, $t, $day, $month, $year) = localtime($mtime);

  $url = "$webdbdir/$db";
  # remove ".fasta" from the name:
  $db =~ s!\.FASTA!!i;

  $db = qq(<a href="$url">$db</a>);
  $year %= 100;
  $month++; # it comes in the range 0-11

  $day = &precision ($day, 0, 2);
  $month = &precision ($month, 0, 2);
  $year = &precision ($year, 0, 2);

  $dbdate = "$month/$day/$year";

  $db .= " ($dbdate)";

  if ($temp) {
    $temp =~ s!(\S+)(\.FASTA)!<a href="$webdbdir/$1$2">$1</a>!gi;

    $db .= " and " . $temp;
  }

  ## check for multiple filename prefixes
  ## (this indicates the user combined more than one 
  ## run in the same directory)

  ($file_string) = $outs[0] =~ m!^([^\.]*)!;
  $temp = "";
  $check = "\Q$file_string\E";

  foreach $file (@outs) {
    next if ($file =~ m!^($check)\.!); # quote to protect it
    $file =~ m!^([^\.]*)!;
    $temp .= " $1";
    $check .= "|\Q$1\E";
  }

  $file_string .= $temp if ($temp);

  ## check all enzymes
  ($enzyme) = $mods[0] =~ m!Enzyme:\s*(\S+)!;
  
  $check = "\Q$enzyme\E";
  my $no_enz = 0;

  if ($enzyme eq "") {
    $enzyme = "None";
    $check = "";
    $no_enz = 1;
  }
  $temp = "";

  foreach $mod (@mods) {
    next if ($mod =~ m!Enzyme:\s*($check)!);
    if ($mod =~ m!Enzyme:\s*(\S+)!) {
      $temp .= " $1";
      $check .= "|\Q$1\E";
    } else {
      next if $no_enz;

      $no_enz = 1;
      $temp .= " None";
    }
  }
  $enzyme .= " and" . $temp if ($temp);
  %attribs = &get_dir_attribs($directory);
  $attribs{"Fancyname"} = &get_fancyname($directory,%attribs);
  my($fancyname, $sampleid) = ($attribs{"Fancyname"},$attribs{"SampleID"});
  print "<hr>\n<span class=\"smallheading\">Sample:</span>\
<tt>$fancyname $sampleid</tt>";

  print <<EOM;
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class="smallheading">Dir:</span>
<tt><a href="$webseqdir/$directory">$directory</a></tt>
<br><span class="smallheading">Files:</span>
<span style="color:#0080C0"><tt>
<a href="$inspector?directory=$directory">
$file_string</a> ($date_string)</tt></span>
&nbsp;&nbsp;&nbsp;&nbsp;
<span class="smallheading">Db:</span>
<span style="color:blue"><tt>$db</tt></span>
&nbsp;&nbsp;&nbsp;&nbsp;
<span class="smallheading">Enz:</span>
<span style="color:#8000FF"><tt>$enzyme</tt></span>
EOM
  &make_space (5);

}

# this subroutine finds the deltaCn value for the given value of $index

sub get_delCn {
  my ($index) = $_[0];
  my ($i, $num) = $index =~ m!(\d+):(\d+)!;

  my ($index2, $deltaCn);

  while (1) {
    $num++;
    $index2 = "$i:$num";
    $deltaCn = $deltaCn{$index2};

    if (!defined $deltaCn) {
      $deltaCn = "0";
      last;
    }
    last if ($deltaCn != 0);
  }
  return $deltaCn;
}


##
## this routine opens each .out file and puts the info into
## associative arrays
##

sub process_outfiles {
  my ($i, $line, $num, $index, $ref, $segment);
  my (@a, $k);
  my (%dates_run);
  my $file;
  my ($num, $OLDNUM);

  for ($i=0; $i<$numouts; $i++) {
    $file = $outs[$i];
    open (FILE, "$file.out");

    while (<FILE>) {
	next unless (/SEQUEST v\.?(.+?),/);
      $version = $1;
	last;
    }

    # skip licensing and time info:
    # this line is like
    # mass=1408.4(+2), fragment tol.=0.00, mass tol.=1.00, MONO 			(version C1 format)
    # (M+H)+ mass = 2965.0800 ~ 2.5000 (+3), fragment tol = 0.0, MONO/MONO	(version C2 format)
    while (<FILE>) {
#print "line=$_<br>\n" if ($i++ % 100 == 1);
      next unless m!(\d\d/\d\d/\d{2,4}), \d+:.. .., (.*) on!;
	$datestamp = $1;
	$datestamp =~ s!(../..)/..(..)!$1/$2!;
      $dates_run{$datestamp} = 1; 
      last;
   }

    while (<FILE>) {
	last if (/mass/);
    }
    $line = $_;

    # nightmare regular expression:
    if ($version ne "C1") {
	    ($mass_ion[$i], $charge[$i]) =  $line =~ m!^\.*mass\s*=\s*(\d+\.?\d*).*\((\+\d)\)!;
    } else {
	    ($mass_ion[$i], $charge[$i]) =  $line =~ m!^\s*mass=(\d+\.?\d*)\((\+\d)\)!;
    }

    if ( $line =~ m! MONO! ) {
      $masstype[$i] = "1";
    } elsif ( $line =~ m! AVG! ) {
      $masstype[$i] = "0";
    } else {
      print STDERR ("Summary3html: File is $file.out, directory is $directory; unknown masstype<br>\n");
      $masstype[$i] = "unknown";
    }

    # next line is of the form:
    # # bases = 329462847, # proteins = 894319, # matched peptides = 83862 		(version C1 format)
    # # amino acids = 52069, # proteins = 187, C:/database/contaminants.fasta		(version C2 format)
    #   ^^^^^^^^^^^ bases if nucleotides, amino acids if from protein database
   
    while (<FILE>) {
	last if (/(# bases|# amino acids)/);
    }
    $line = $_;
    $is_nucleo[$i] = ($line =~ m/bases/) ? 1 : 0;
    if ($version ne "C1") {	# in version C2 this line contains the database
	($database[$i]) = $line =~ m!([^\\/]+\.FASTA)!i;
    }

    # get the ion series info:
    # ion series nA nB nY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0	(version C1 format)
    # ion series nABY ABCDVWXYZ: 0 1 1 0.0 1.0 0.0 0.0 0.0 0.0 0.0 1.0 0.0		(version C2 format)
    #
    #  0    1     2  3  4     5      6 7 8  9   10  11  12  13  14  15  16  17
    while (<FILE>) {
	last if (/ion series/);
    }
    $line = $_;
    $line =~ s/.*ABCDVWXYZ:\s*//;
    @a = split (' ', $line);

    # construct the string to pass to displayions; of the form "010000010"
    # these correspond to the a,b,c,d,v,w,x,y, and z ions
    $ionstr[$i] = "";
    for ($k = 3; $k <= 11; $k++) {
      $ionstr[$i] .= ( ($a[$k] == 0 ) ? "0" : "1" );
    }

    # next line contains the database name (unless it's version C2; see above):
    #  rho=0.200, beta=0.075, top 15, /usr/entrez/database/dbEST.weekly.FASTA
    unless ($version ne "C1") {
	$line = <FILE>;

	# grab only the filename, not the directory
	($database[$i]) = $line =~ m!([^\\/]+\.FASTA)!i;
    }

    # grab modifications. Of the form
    # (M# +16.0) C=160.0 Enzyme:Trypsin 			(version C1)
    # (M* +16.000) C=160.009 Enzyme:Trypsin (5) 	(version C2)
    while (<FILE>) {
	last if (/Enzyme:/);
    }
    $mods[$i] = $_;
    while (<FILE>) {
      last if /\S/; # stop on a non-space-filled line
    }
    $dummy = <FILE>; # separator line

    # core of the program:
    # the lines from the .out file have this header:
    # (version C1:)
    #  #   Rank/Sp  (M+H)+    Cn    deltCn  C*10^4    Sp     Ions  Reference        Peptide
    # ---  -------  ------  ------  ------  ------   ----    ----  ---------        -------
    # (version C2:)
    #  #   Rank/Sp    (M+H)+   deltCn   XCorr    Sp     Ions  Reference                             Peptide
    # ---  -------  ---------  ------  ------   ----    ----  ---------                             -------

    $OLDNUM = 0;
    $index = "";
    $empty{$file} = 1; # true if the file has no data

    while ($line = <FILE>) {
      if ($line =~ m!^\s*(\d+)\.!) {
        $num = $1;
         last if ($num <= $OLDNUM);

         $index = "$i:$num";
         $OLDNUM = $num;
         &process_line ($line, $index);
         $empty{$file} = 0;

      } elsif ($line =~ m!^\s*$!) {
         last;
      } else {
         ## pull out additional refs, making them canonical according the indexing subroutines:
         ($segment) = $line =~ m!^\s*(\S+)!;
         &store_long_form ($segment);
         $ref = &parseentryid ($segment);
         $other_refs{$index} .= " " . $ref unless ($index eq "");
         $level_in_file{"$i:$ref"} = $num unless (defined $level_in_file{"$i:$ref"});

         # it is not clear that the following block of code is working or is otherwise significant
         # it should gather some of the inlined reference data in the .out file however
         my($aref, @eol) = split(/\s/, $line, -1);
         $myref = &parseentryid($aref . "|");
         if (!defined($refdata{$myref})) {
           $refdata{$myref}->[0]="@eol";
         }	

         next;
      }
    }

    # collect further reference data
	my $lastref="";
	while ($line=<FILE>) {
      	$line=~s/^\s\s//;
      	my($blank, $aref, @eol) = split(/\s+/, $line, -1);
		if (grep(/^\d+\./, $blank)) {
			$myref=parseentryid($aref . "|");
			if (!defined($refdata{$myref})) {
				$refdata{$myref}->[0]="@eol";
				$lastref=$myref;
			} else {
				# this line fixes a gotcha, i think
				$lastref="";
			}
		} else {
			push(@{$refdata{$lastref}}, $aref . " @eol"); # inaccurate reconstruction?
		}
	}

    close FILE;
  }

  # process dates of .out files
  $date_string = &process_dates(keys %dates_run);
} # end of &process_outfiles

##
## &process_line
##
## this analyzes a single line from a .out file and creates appropriate
## entries for it in the various associative arrays

sub process_line {
  my ($line, $index) = @_;
  my @fields;
  my ($i, $num) = $index =~ m!(\d+):(\d+)!;

  # this separates Rank from Sp and separates the two parts of the Ions field
  $line =~ s!/! !g;
  @fields = split (' ', $line);

  $rank{$index} = $fields[1];
  $rankSp{$index} = $fields[2];

  $MHplus{$index} = $fields[3];

#  $Cn{$index} = $fields[4];	# this one is useless

  $offset = ($version ne "C1") ? 1 : 0;	# there's no Cn in version C2 output, so everything is offset by one field

  $deltaCn{$index} = $fields[5 - $offset];
  $C10000{$index} = $fields[6 - $offset];

  $Sp{$index} = $fields[7 - $offset];
  $ions{$index} = $fields[8 - $offset]  . "/" . $fields[9 - $offset];

  $ref{$index} = $fields[10 - $offset];
  if ( $ref{$index} =~ s!(\+\d+)!! ) {
    $ref_more{$index} = $1;
    $peptide{$index} = $fields[11 - $offset];

  } elsif ( $fields[11 - $offset] =~ m!\+\d+!) {
    $ref_more{$index} = $fields[11 - $offset];
    $peptide{$index} = $fields[12 - $offset];

  } else {
    $peptide{$index} = $fields[11 - $offset];
  }

  # convert C2 format to earlier format for peptide
  if ($version ne "C1") {
	$peptide{$index} =~ s/(\S)\.([^\.]+)\../($1)$2/;
  }

  ## make the reference canonical, according to the rules
  ## of the indexing subroutines:
  &store_long_form ($ref{$index});
  $ref{$index} = &parseentryid ($ref{$index});

  $level_in_file{"$i:$ref{$index}"} = $num unless (defined $level_in_file{"$i:$ref{$index}"});
}

sub store_long_form {
  my ($ref) = @_;
  my ($short) = &parseentryid ($ref);
  my ($current);

  if ($DEBUG) {
    $ref_long_form{$ref} = $ref;
    return;
  }

  $current = $ref_long_form{$short};
  if (!defined $current) {
    $ref_long_form{$short} = $ref;
    return;
  }

  my ($l1, $l2, $l);
  $l1 = length ($current);
  $l2 = length ($ref);

  $l = &min ($l1, $l2);
  if (substr ($ref, 0, $l) ne substr ($current, 0, $l)) {
    $ref_long_form{$short} .= "*" unless $current =~ m!\*!;
  } elsif ($l2 > $l1) {
    $ref_long_form{$short} = $ref;
  }
}


sub read_profile {
  my ($line, $temp, $file, $zbp);
  my (@zbps);

  open (PROFILE, "lcq_profile.txt") || return;
  $line = <PROFILE>; # skip first line
  while (<PROFILE>) {
    ($file, $temp, $temp, $temp, $zbp) = split (' ');
    $file =~ s!\.dta$!!;

    $ZBP{$file} = $zbp;
  }
  close PROFILE;

  # calculate median ZBP
  if (0) {
    # old method - median over all original dta's
    @zbps = sort { $b <=> $a } values %ZBP;
  } else {
    # new method - median over all current dta's
    foreach $file (@outs) {
      push (@zbps, $ZBP{$file});
    }
    @zbps = sort { $b <=> $a } @zbps;
  }

  $Median_ZBP = $zbps[ ($#zbps/2) ];
  $Max_ZBP = $zbps[0];
}

##
## this subroutine takes a list of dates and compresses
## them into one string, of the form MM/DD/YY - MM/DD/YY
## to indicate a span of dates.
##
## we do this by converting each into integer, and grabbing
## the highest and lowest.

sub process_dates {
  my (@dates) = @_;
  my ($begin_int, $end_int, $string, $temp, $m, $d, $y);

  foreach $date (@dates) {
    ($m, $d, $y) = $date =~ m!(..)/(..)/(..)!;

    $y += 100 if ($y < 90); # to account for the years 2000+

    $int = ($m + $y * 13) * 3000 + $d;

    $begin_int = &min ($int, $begin_int);
    $end_int = &max ($int, $end_int);
  }

  $d = ($begin_int % 3000);
  $temp = ($begin_int - $d) / 3000;

  $m = ($temp % 13);
  $y = ($temp - $m) / 13;
  $y -= 100 if ($y > 100);

  $d = &precision ($d, 0, 2);
  $m = &precision ($m, 0, 2);
  $y = &precision ($y, 0, 2);

  $string = "$m/$d/$y-";

  $d = ($end_int % 3000);
  $temp = ($end_int - $d) / 3000;

  $m = ($temp % 13);
  $y = ($temp - $m) / 13;
  $y -= 100 if ($y > 100);

  $d = &precision ($d, 0, 2);
  $m = &precision ($m, 0, 2);
  $y = &precision ($y, 0, 2);

  $string .= "$m/$d/$y";

  return ($string);
}

##
## &group_and_score
##
## Prepares score data information for &print_consensi.
## Some information may be used by &print_data.
## 
sub group_and_score {
  my ($ref, $ref2, $i, $num, $j);
  my (@scorelist, @filenumlist, $list);
  my (@refs, @goodrefs);
  my %top_score;
  my %backloc;
  
  ##
  ## make an inverse assoc array %location such that given a $ref,
  ## we can see which indices contain a reference to it.
  ##
  ## This is made as a space separated list of reference indices.
  ## 
  foreach $index (keys %ref) {
    $ref = $ref{$index};
    $location{$ref} .= " " . $index;

    if (defined $other_refs{$index}) {
      foreach $ref (split (' ', $other_refs{$index})) {
        $location{$ref} .= " " . $index;
      }
    }
  }


  ## look at only those references that hit more than one
  ## index:
  ##
  ## we do this by looking for those with a %location value
  ## containing more than one space (the number of spaces
  ## equals the number of indices).

  @refs = grep { $location{$_} =~ m! .* ! } keys %location;
  @refs = sort { $a cmp $b } @refs; # sort alphabetically

  ## now, put the %location values into some canonical
  ## (here, alphabetical) order, so we can compare them
  ## more easily:

  foreach $ref (@refs) {
    $location{$ref} = join (" ", sort { $a cmp $b } split (" ", $location{$ref}) );
  }


  ## Now we collect all references that have the same %location
  ## value. We do this in order(N) time by constructing an
  ## inverse assoc array for %location. We call this %backloc.
  ##
  ## The values of %backloc are now a "representative set" of
  ## references for display; we call these @goodrefs, and we
  ## calculate score data from them.

  foreach $ref (@refs) {
    $loc = $location{$ref};
    $back = $backloc{$loc};
    
    if (defined $back) {
      $consensus_refs{$back} .= " " . $ref;
    } else {
      $backloc{$loc} = $ref;
    }
  }

  ## analyze each reference for score and two breakdowns of the score;
  ## one breakdown by category and one by file numbers within categories
  ##
  ## for a consensus line:
  ##                       score   categories      breakdown by file numbers within categories
  ##  1. HSU21128            112 (11,0,0,0,0,2) {3 5 9 11 13 16 23 25 27 31 33, x, x, x, x, 10 14}
  ##                      
  ## The score data are stored in %score, %score_breakdown, and %score_showfiles
  ## for &print_consensi.

  my @answers;
  foreach $ref (values %backloc) {
    @answers = &consensus_score($ref);
    if ($answers[0] >= 2) {
      ($score{$ref}, $score_breakdown{$ref}, $score_showfiles{$ref}, $peplist{$ref}) = @answers;
	($top_score{$ref}) = $score_breakdown{$ref} =~ m!^(\d+),!;
      push (@goodrefs, $ref);
    }
  }


  ## we create this global variable which orders the references from
  ## highest to lowest scoring.

  if ($new_algo) {
    # here, we make sure the top score (the number of OUT files for which this is the top hit)
    # counts the most
    @ordered_refs = sort { $top_score{$b} <=> $top_score{$a} || $score{$b} <=> $score{$a} || $a cmp $b } @goodrefs;
  } else {
    @ordered_refs = sort { $score{$b} <=> $score{$a} || $a cmp $b } @goodrefs;
  }
  $#ordered_refs = &min ($MAX_NUM_CONSENSI - 1, $#ordered_refs); # set it to use just the top 15

  ## to each .out file, assign its highest position, for the
  ## best few references. We store this in the array @ranking.
  ##
  ## if a consensus entry has no new files (ie has a strict subset
  ## of the .out files counted in the previous entries), then it
  ## is coloured according to the *lowest* ranking consensus entry
  ## whose files overlap its.
  ##
  ## The "colour ranking" of the consensus entries are stored in
  ## %consensus_colour_rank

  my ($lowest_rank);
  $j = 0; # keeps track of the rank
  my ($c) = 0; # keeps track of position within consensi

  @rank_counts = (); # array of ranks that contain new .outs files,
                     # and that therefore get new colours

OUTER:
  foreach $ref (@ordered_refs) {
    $consensus_pos{$ref} = ++$c;
    if ($j >= $num_ranks_to_colour) {
      $consensus_colour_rank{$ref} = -1;
      next OUTER;
    }

    $lowest_rank = -1;

  INNER:
    foreach $index (split (" ", $location{$ref})) {
      ($i, $num) = split (":", $index);

      if (defined $ranking[$i]) {
        $lowest_rank = &max ($lowest_rank, $ranking[$i]);
        next INNER;
      }

      # the use of the word "rank" in $MAX_RANK here is a bit
      # misleading. This means that we only assign a ranking
      # to the .out file if this hit was above $MAX_RANK in
      # the list of entries in the .out file.

      if ($num <= $MAX_RANK) {
        $ranking[$i] = $j;
        $lowest_rank = $j;
      }
    } # end INNER loop

    $consensus_colour_rank{$ref} = $lowest_rank;

    # advance to next ranking level if we have new .out files
    if ($lowest_rank == $j) {
      $j++;
      push (@consensus_groupings, $ref);
      push (@rank_counts, $c);
    }
  } # end OUTER loop

  # calculate the length of the longest reference
  $cons_reflen = 10;
  foreach $ref (@ordered_refs) {
    $l = length ($ref_long_form{$ref});
    $cons_reflen = $l if ($l > $cons_reflen);
  }
  $cons_reflen++;
} # end &group_and_score

sub print_data {
  my ($rank, $lastrank, $ref, $count, $i, $num);
  my ($noconsensus, $i);

  $count = 1;
  $lastrank = -2; # we need a start sentinel value that is NOT -1!

  $is_cons_sort=1;

  $noconsensus = 0;
  $n = 0;

  foreach $file (@orderedouts) {
    $i = $number{$file};
    # if this is high ranking, make it bold and colourful
    $rank = $ranking[$i];
    $rank = -1 if (!defined $rank);

    ## if this is a consensus grouping, and we have moved on to
    ## the next group, make some space and print a header:
    if (($is_cons_sort) && ($rank != $lastrank)) {
      # if not the first group, make some space:
      if ($lastrank != -2) {
        &make_space (10);
      }
      if ($rank != -1) {
        $ref = $consensus_groupings[ ($count - 1) ];

        &print_one_consensus ($ref, 0);
        $count++;
      } else {
#        print ("<TT><U>&nbsp;-&nbsp;No Consensus</U></TT><BR>\n");
        $noconsensus=1;
      }
    }

    ## we print a reference description for the first 5 OUT
    ## files not belonging to any consensus:
    if ($noconsensus) {
	$n++;
    }

    ## if this is a consensus sort, and we are not in the no
    ## consensus zone, have the called subroutine make the
    ## peptide and reference printed agree with this reference.
    ## otherwise, just print the top reference.
    if ($is_cons_sort && ($rank != -1)) {
      $num = $level_in_file{"$i:$ref"};

#  the following commented by wsl when martin threatened never to buy
#  lean cuisines again. Really, really: wsl is not responsible for any problems
#  caused here by this change. 4/5/98
#      &print_one_dataline("$i:$num", $rank, 0, $ref);
#      &print_one_dataline("$i:1", $rank, 0);
    } else {
      $num = 1;

#      &print_one_dataline("$i:$num", $rank, $noconsensus && ($n <= 5));
    }

    $lastrank = $rank;
  }
}

sub print_one_dataline {
  my ($index, $rank, $printdescrip, $preferred_ref) = @_;

  my ($i, $num, $url, $line, $file, $ref);
  my ($name, $z, $delM, $mass, $Xcorr, $deltaCn, $Sp, $RSp, $Ions, $Ref, $Seq, $zbp);
  my ($dbpepurl, $disppepurl, $blasturl);
  my ($filenumstr);

  # $start, $end bound each piece of data
  # $start_l is a left-aligned version of $start
  # $startline, $endline bound each line
  # $s is our space-separator char
  #
  my ($startline, $divider, $endline, $s);

  $startline = "<TT>";
  $endline = "</TT><BR>\n";
  $divider = "&nbsp;";
  $s = "&nbsp;";
  
  ($i, $num) = $index =~ m!(\d+):(\d+)!;


  $file = $outs[$i];
  
  $filenumstr = &precision ($i+1, 0, 2, $s);

  if ($rank != -1) {
    my $colour = $rank_colour[$rank];
    $filenumstr = qq(<span style="color:$colour"><b>$filenumstr</b></span>);
  }

  $Seq = $peptide{$index};

  ($disppepurl, $dbpepurl, $blasturl) = &URLs_of_seq ($Seq, $file);

  # calculate URL for showing .out file
  $url = "$showout?OutFile=" . "$seqdir/$directory/$file" . ".out";

  ($name, $z) = $file =~ m!\.(\d+\.\d+)\.(\d)$!;

  if ($name =~ m!^(\d+)\.\1$!) {
    # truncate single scans
    $name = qq(<a href="$url">$1</a>) . "&nbsp;" x 5;
  } else {
    $name =~ s!\.!-!; # make dots into dashes
    $name =  qq(<a href="$url">$name</a>);
  }

  # 29.3.98: changed by Martin to make $mass reflect the experimental mass
  # and delta-M to be the deviation between that and the calculated mass of
  # the peptide:
  $delM = &precision ($MHplus{$index} - $mass_ion[$i], 1, 2, $s);

  $mass = &precision ($mass_ion[$i], 1, 4, $s);

  # 29.3.98: changed by Martin to only 2 significant digits:
  $Xcorr = &precision ($C10000{$index}, 2, 1, "0");
  $Xcorr = "<b>$Xcorr</b>" if ($C10000{$index} >= $XCORR_THRESH);

  # 29.3.98: changed by Martin to only 2 significant digits:
  $deltaCn = &precision (get_delCn($index), 2, 1, "0");
  $deltaCn = "<b>$deltaCn</b>" if (get_delCn($index) >= $DELTACN_THRESH);

  # 29.3.98: changed by Martin to NO significant digits:
  $Sp = &precision ($Sp{$index}, 0, 4, $s);
  $Sp = "<b>$Sp</b>" if ($Sp{$index} >= $SP_THRESH);

  $RSp = &precision ($rankSp{$index}, 0, 3, $s);
  $RSp = "<b>$RSp</b>" if ($rankSp{$index} <= $RSP_THRESH);

  # calculate URL for displaying ions:
  $url = "$displayions?$disppepurl";

  $Ions = "$s" x (6 - length($ions{$index})) . qq(<a href="$url">$ions{$index}</a>);

  # if asked, use the reference given us. Otherwise, use the usual value:
  $ref = $preferred_ref || $ref{$index};

  # calculate URL for reference:
  $url = "$retrieve?Ref=$ref";
  $url .= "&amp;" . $dbpepurl;

  $Ref = qq(<a href="$url">$ref</a>);

  if (!defined $ref_more{$index}) {
    $Ref .= "$s" x ($reflen - length($ref));
  } else {
    $Ref .= "$s" x ($reflen - length($ref_more{$index}) - length($ref));
      
    # calculate ref_more URL
    #$url = "$morerefs?$dbpepurl";
	$url = "$morerefs?OutFile=" . &url_encode("$seqdir/$directory/$file.out"). "&Ref=" . $ref . "&Peptide=" . $Seq;
    $Ref .= qq(<a href="$url">$ref_more{$index}</a>);
  }

  if (defined $ZBP{$file}) {
    $zbp = &sci_notation ($ZBP{$file});

    if ($zbp >= $Median_ZBP) {
      $zbp = "<b>$zbp</b>";
    }
  } else {
    $zbp = "-----";
  }

  $Seq = qq(<a href="$blasturl">$Seq</a>);

  # what to do for empty .out files:
  if ($empty{$file}) {
 #   $mass = &precision ($mass_ion[$i], 1, 4, $s);
    $delM = "$s" x 4;
    $Xcorr = "$s" x 6;
    $deltaCn = "$s" x 5;
    $Sp = "$s" x 6;
    $RSp = "$s" x 3;
    $Ions = "$s" x 6;
    $Ref = "no hits";
    $Ref = $s x ($reflen - length ($Ref)) . $Ref;
    $Seq = "";
  }

  ##
  ## if boxtype is hidden, only add it if we are a selected file
  ## otherwise, always show the box, but check it only if selected.
  ##

  print ($startline);

  print join ("$divider", $filenumstr, $zbp, $name, $z, $delM, $mass, $Xcorr, $deltaCn,
	      $Sp, $RSp, $Ions);

  print ($divider);
#  print ("$s<TT>$Ref");
  print ("$s$Ref");
      
  print ($divider);
#  print ("$s<TT>$Seq");
  print ("$s$Seq");

  print ($endline);

  if ($printdescrip) {
    print ("<TT>");
    &printdescrip($ref);
    print ("</TT>");
  }
}



##
## &print_consensi
##
## actually output the consensus, in the form 
##  1. HSU21128            112 (11,0,0,0,0,2) {3 5 9 11 13 16 23 25 27 31 33, x, x, x, x, 10 14}

sub print_consensi {
  foreach $ref (@ordered_refs) {
    &print_one_consensus ($ref, 1);
  }
}


sub print_one_consensus {
  my ($ref, $with_others) = @_;
  my ($count) = $consensus_pos{$ref};

  my ($url, $score, $score_breakdown, $score_showfiles);
  my ($baseurl, $i);
  my (@peps, $col_rank);

  ($i) = $location{$ref} =~ m!(\d+):\d+!;

  $baseurl = "$consensus?Db=$dbdir/" . $database[$i];
  $baseurl .= "&amp;NucDb=1" if ($is_nucleo[$i]);
  $baseurl .= "&amp;MassType=" . $masstype[$i];

  $baseurl .= "&amp;Pep=$peplist{$ref}";

  $url = $baseurl . "&amp;Ref=$ref";

  $score = $score{$ref};
  $score_breakdown = $score_breakdown{$ref};
  $score_showfiles = $score_showfiles{$ref};

  $countstr =  "&nbsp;" . substr ($consensi_letterstr, $count-1, 1);

  $col_rank = $consensus_colour_rank{$ref};
  if (($col_rank != -1) && ($col_rank <= $num_ranks_to_colour)) {
    my $colour = $rank_colour[ $col_rank ];

    $countstr = qq(<span style="color:$colour"><b>$countstr</b></span>);
  }

  print ("<TT>");
  print ("<U>") unless ($with_others);
#  print ("&nbsp;" x 3);
  print ($countstr, "&nbsp;");
  $prettyref = $ref_long_form{$ref};
  print (qq(<a href="$url">$prettyref</a>), "&nbsp;" x ($cons_reflen - length ($prettyref)) );

  print (&precision ($score, 0, 3, "&nbsp;"));
  print ("&nbsp;{$score_breakdown}"); 

  print ("&nbsp;($score_showfiles)");
  print ("</U>") unless ($with_others);
  print ("<br>\n");

  &printdescrip($ref);

  if (($with_others) && ($consensus_refs{$ref})) {
    my @r = ();
    foreach $r (split (" ", $consensus_refs{$ref})) {
      $url =  $baseurl . "&amp;Ref=$r";
      push (@r, qq(<a href="$url">$r</a>));
    }
    print ("&nbsp;" x 8, join (",&nbsp;", @r), "<br>\n");
  }
  print ("</TT>\n");
}

sub printdescrip {
    my($ref) = $_[0];

    $myref = &parseentryid($ref . "|");
    $refline = substr(&lookupdesc($myref), 0, 300);
    ($refstuff, @linedata) = split(/\s/, $refline);
    if ($refline ne "") {
	print "@linedata<br>\n";
    } else {
	@reflines = split(/\n/, $refdata{$myref});
	@reflines = @{$refdata{$myref}};
	if ($reflines[0] ne "") {
	    foreach $i (0..$#reflines) {
		$reflines[$i] =~ s/\s$//;
	    }
	    $refline = substr(join('',@reflines),0,300);
	    print "*$refline<br>\n";
	}
    }

}

##
## this subroutine calculates a score for a quick reference
## for use in grading relative importance of proteins
##
## The global variable $numscores counts how many scoring
## categories we keep. if $numscores is "n", then we have
## 1st, 2nd, ..., (n-1)th, and then, altogether "nth and lower".
##
## Output:
##   First: the total score
##   Second: the list of number of hits per category
##   Third: the list of file numbers, per category
##   Fourth: the list of peptides (separated by "+") to send to consensus
##
sub consensus_score {
  my ($ref) = @_;
  my $score = 0;

  my ($i, $num, $ranknum, $pep);
  my ($breakdown, $filelist, $peplist);
  my (@filenumlist, @scorelist);
  my (@peps);

  ## initialize the scorelist to all zeros
  for ($i=0; $i < $numscores; $i++) {
    $scorelist[$i] = 0;
    $filenumlist[$i] = "";
  }

  ## We make the following modification: to avoid single files
  ## counting multiple times, a single file is allowed only once
  ## EXCEPT if the file matches against more than one peptide of
  ## the reference. In this case, it counts once for each peptide
  ## that matches the reference.

  # a hash for matching already seen peps
  # keys will be "$pep"
  my (%pep_seen);

  # hash for peps to be put in the $peplist
  my (%in_peplist);

  # a hash for matching already seen file-peptide combos
  # keys are "$i:$pep"
  my (%file_pep_seen);

  # a hash for files actuall counting toward a consensus
  my (%file_used);

  ## for each file which references this $ref, we put
  ## the file number ($i) into the array @filenumlist
  ## according the value of $num (its ranking in the
  ## .out file).
  ##

  my @temparr = split (" ", $location{$ref});
  my %n;
  # sort by importance in .out file
  foreach $index (@temparr) {
    ($n{$index}) = $index =~ m!:(\d+)!;
  }
  @temparr = sort { $n{$a} <=> $n{$b} } @temparr;

  foreach $index (@temparr) {
    ($i, $num) = $index =~ m!(\d+):(\d+)!;

    # take off diff mods to avoid problems with differential mods.
    $pep = &cleanpep($peptide{$index});
    $pep =~ s!\(.\)!!; # remove preceding aa

    next if ($file_pep_seen{"$i:$pep"});

    $file_pep_seen{"$i:$pep"} = 1;

    # since @temparr is already sorted by rank in the .out file,
    # in order to count each .out file once, for its highest match,
    # we simply count it just the first time.
    # In addition, for a given peptide, we want to count it only
    # once, at its highest level, but those .out files that match
    # should be mentioned (in $filenumlist) if not counted directly.

    # count all hits below a certain rank at the same, minimal level:
    $realnum = &min ($num, $numscores);

    $filenumlist[$realnum-1] .= " " . ($i + 1);

    if (!$pep_seen{$pep}) {
      $scorelist[$realnum-1]++;

      # if ranked high enough, add to the peplist and the score
      if ($num <= $MAX_RANK) {
        $score += $scorearr[$realnum-1];
        push (@peps, $pep) unless $in_peplist{$pep};
        $in_peplist{$pep} = 1;

        $file_used{$i} = 1;
      }
      $pep_seen{$pep} = 1;
    }
  }

  ## return undefined if only one significant file seen
  return undef if (scalar (keys %file_used) < 2);

  ## return undefined if only one distinct peptide is seen
  return undef if (scalar (@peps) < 2); 

  # create list of peps up to 850 chars long
  my $len;
  $peplist = "";
  while ($pep = shift @peps) {
    $len += length($pep) + 1;
    last if ($len > 850);
    $peplist .= "$pep+"
  }
  $peplist =~ s!\+$!!;

  $breakdown = join (",", @scorelist);

  ## this is the breakdown by file numbers within the categories
  ##
  ## Remember that modification of the stepping variable (in this
  ## case, $list) within a foreach loop alters the value *inside*
  ## the given array.
  ##
  ## we make it "x" if there are no files for this reference in this
  ## score category; otherwise, we order them numerically.
  ##
  foreach $list (@filenumlist) {
    if ($list eq "") {
      $list = "x";
    } else {
      # sort numerically
      $list = join (" ", sort { $a <=> $b } split (" ", $list));
    }
  }
  $filelist = join (", ", @filenumlist);
  return ($score, $breakdown, $filelist, $peplist);
}

## returns the peptide sequence cleaned
## of all non-alphabetic characters.

sub cleanpep {
  my ($pep) = @_;

  $pep =~ tr!#*!!d;

  return $pep;
}


##
## sort subroutines
##

## remember that we are given the *truncated* file name
## (".out" had been dropped) in $a and $b. Thus the
## charge state is the last character in the filename.

sub sort_by_delCn {
  my %i;
  foreach $out (@_) {
    $i{$out} = &get_delCn("$number{$out}:1");
  }
  return sort { $i{$b} <=> $i{$a} ||
		  $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"}
	      } @_;
}

##
## end of sort subroutines
##
    
sub output_form {
  print <<EOM;
<P>
 
<TABLE WIDTH=100% BORDER=0>
<TR>
<TD ALIGN=CENTER VALIGN=TOP>
<b>Available directories:</b>
<FORM ACTION="$ourname" METHOD=GET>
EOM
 
  &get_alldirs; 

  # make dropbox:
  print qq(<span class=dropbox><SELECT size=15 multiple name="directories">\n);
  foreach $dir (@ordered_names) {
    print qq(<OPTION VALUE = "$dir">$fancyname{$dir}\n);
  }
  print ("</SELECT></span>\n");


  print <<EOM;
&nbsp;&nbsp;&nbsp;
<INPUT TYPE="SUBMIT" class=button VALUE="Run">

<p>

<!-- <i><span class="smalltext"><a href="$edit_excludes">Edit known_ions.txt</a></span></i> -->

</td>

<td>
 </FORM>
 
</td>
</tr>
</table>
EOM


}

sub sort_by_rank {
  my (%r);

  foreach $out (@_) {
    $r{$out} = $ranking[$number{$out}];
  }

  return sort {
     defined $r{$b} <=> defined $r{$a} || $r{$a} <=> $r{$b}
     || $C10000{"$number{$b}:1"} <=> $C10000{"$number{$a}:1"}
  } @_;
}


##
## this looks in %FORM to find the sort parameter the user selected

##
## return sorted list of the given @outs
##
## we modify $sort, a global variable

sub do_sort_outs {
  my (@files) = @_;
  my (@orderedouts);
  my (@outs, @empties);
  
  foreach $out (@files) {
    if ($empty{$out}) {
      push (@empties, $out);
    } else {
      push (@outs, $out);
    }
  }

#   @orderedouts = ((&sort_by_delCn (@outs)), @empties);
#   $sort = "dcn";
  @orderedouts = ((&sort_by_rank (@outs)), @empties);  

  return (@orderedouts);
}

sub make_space {
  print qq(<IMG SRC="$transparent_pixel" HEIGHT=$_[0] WIDTH=1 ALIGN=LEFT><BR CLEAR=ALL>\n);
}

sub chdir_error {
  my $dir = $_[0];

  print <<EOM;
<h3>Error: Unable to access $dir</h3>
Please be sure the directory actually exists and access
permissions are sufficient.
EOM
  &closeidx();
  exit;
}

##
## &URLs_of_seq creates a string to be included in an URL to a helper program
## Since this will go to a web page, ampersands are represented with "&"
##
## Return array:
##   the first element is an URL suitable for the displayions family of apps
##   the second is an URL suitable for database helper programs (retrieve, blast)
##   the third is the peptide sequence suitable for sending to BLAST
##
## Arguments:
##   First arg is the raw peptide string from the .out file
##   second is the truncated file name.
##
## The file number is not used right now, but probably will be as this gets more
## sophisticated.

sub URLs_of_seq {
  my ($pep, $file) = @_;
  my ($filenum) = $number{$file};

  my ($cleanpep, $disppepurl, $dbpepurl, $blasturl);
  
  my ($mods) = $mods[$filenum];
  my ($mod1, $mod2, $mod3);

  # remove extraneous characters from the peptide for use in URLs
  # '*' and '#' mark sites of differential modifications -- so does '@'
  $extendedpep = &cleanpep($pep);

  # remove the parentheses of the preceding or following amino acid
  $extendedpep =~ tr!()\-!!d;

  # remove the parens AND the preceding or following aa
  ($shortpep = $pep) =~ s!\(.\)!!;
  $cleanpep = $shortpep;

  ## $diffsite is a string of numbers, each of which corresponds to
  ## one amino acid in the sequence.
  ##
  ## here, we mark $diffsite according to the differential mods
  ## present. "2" is used for the '#' mods, "1" for the '*' mods
  ##
  ## The positions of unmodified amino acids are marked with "0".

  if ($shortpep =~ m!\#|\*|\@!) {
    my ($pos, $diff, $diffsite);
    my ($count);

    my ($mods) = $mods[$filenum];
    my ($mod1, $mod2, $mod3);

    # the modifications are in the form "(M# +16.0)"
    # or "(STY* +80.0)". Possibly negative.
  
    ($mod1) = $mods =~ m!\(.*?\* (.*?)\)!;
    ($mod2) = $mods =~ m!\(.*?\# (.*?)\)!;
	($mod3) = $mods =~ m!\(.*?\@ (.*?)\)!;
  
    # url-escape the "+" and "-" characters:
    $cleanpep = &cleanpep ($cleanpep);

    $count = 0;
    $diffsite = "0" x (length ($cleanpep));

    while ($shortpep =~ m!(\#|\*|\@)!g) {
      # first or second (or third) diff mod?
      $number = ($1 eq "*") ? "1" : ($1 eq "#") ? "2" : "3";
 
	  $pos = pos ($shortpep) - 1 - ($count);
      $count++;

      substr ($diffsite, $pos - 1, 1) = $number;
    }

    $disppepurl = "DSite=$diffsite&";
    $disppepurl .= "DMass1=" . &url_encode($mod1) . "&" if (defined $mod1);
    $disppepurl .= "DMass2=" . &url_encode($mod2) . "&" if (defined $mod2);
    $disppepurl .= "DMass3=" . &url_encode($mod3) . "&" if (defined $mod3);
  }

  $disppepurl .= "Pep=$cleanpep";
  $disppepurl .= "&Dta=" . &url_encode("$seqdir/$directory/$file" . ".dta");
  $disppepurl .= "&MassType=$masstype[$filenum]";
  $disppepurl .= "&NumAxis=1&ISeries=$ionstr[$filenum]";
  $disppepurl .= &URLized_mods($filenum) if ($mods[$filenum]);
 
  $dbpepurl = "Db=" . &url_encode("$dbdir/" . $database[$filenum]);
  $dbpepurl .= "&NucDb=1" if ($is_nucleo[$filenum]);
  $dbpepurl .= "&MassType=" . $masstype[$filenum];
  $dbpepurl .= "&Pep=" . $cleanpep;

 

  my $db = $database[$filenum];
  # remove the .fasta suffix:
  $db =~ s!\.fasta!!;

  # calculate URL for the sequence blast
  # this blast uses the previous or following amino acid, if it exists
  $blasturl = "$remoteblast?$sequence_param=$extendedpep&";

  if (($db eq "est") || ($db =~ m!dbEST!i)) {
    $blasturl .= "$db_prg_aa_nuc_dbest";
  } elsif ($db eq "nt") {
    $blasturl .= "$db_prg_aa_nuc_nr";
  } elsif ($db =~ m!yeast!i) {
    $blasturl .= "$db_prg_aa_aa_yeast";
  } else {
    $blasturl .= "$db_prg_aa_aa_nr";
  }

  ## our default parameters for display and significance:
 
  $blasturl .= "&$expect&$defaultblastoptions";
  
  return ($disppepurl, $dbpepurl, $blasturl);
}
