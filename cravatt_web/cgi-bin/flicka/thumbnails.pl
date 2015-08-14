#!/usr/local/bin/perl

#-------------------------------------
#	Thumbnails.pl
#	(C)1998 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


## The scheme:
# 1. thumbnails.pl initial run: user picks a directory, goes to either 2) or 3)
# 2. dta files are chosen for display
# 3. dta files are displayed by thumbnails.exe, some are chosen for deletion or next 16 are to be displayed
# 4. thumbnails.pl deletes selected files and goes to 3), or redirects the browser to thumbnail.exe
#           to display the next 16 DTA files
# 5. Cycle repeats until user goes to a different page.

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
&cgi_receive;

# if no directory chosen, pick one: (step 1)
$dirname = $FORM{"Dir"};
unless ($dirname) {
    &MS_pages_header ("Thumbnails", "#00009C");
	print"<hr>\n";
    &output_first_form;
    exit;
}

@selected = split (", ", $FORM{"DTA"});

if ($dirname =~ m!$seqdir!) {
  $dir = $dirname;
  $dirname =~ s!.*$seqdir[/\\]*!!;

} else {
  $dir = "$seqdir/$dirname";
}
chdir ($dir);

opendir (DIR, "$dir") || &error("Could not open directory $dir. $!");
@alldtas = grep { m!.*\.dta$!i } readdir (DIR);
closedir (DIR);

# if no dtas already chosen, choose some (Step 2):
unless ($FORM{"Dta"} || $FORM{"delete"} || $FORM{"First16"} || $FORM{"Next"} || $FORM{"Prev"}) {
    &MS_pages_header ("Thumbnails", "#00009C");
	print"<hr>\n";
    &output_second_form;
    exit;
}

# Otherwise, process form info and figure out selected DTAs
if ($FORM{"First16"}) {
  @sel_dtas = &get_next_dtas(lastfile => undef, num => 16);
} else {
  @sel_dtas = split (", ", $FORM{"Dta"});
}

$num_to_view = $FORM{"num_to_view"} || 16;
$num_to_view  = 16 if (($num_to_view > 16) || ($num_to_view <= 0));

# if this is a deletion call, delete those DTAs and find the next
# set to display; otherwise simply display the selected ones.
if ($FORM{"delete"}) {
    &delete_files(@sel_dtas);
    &update_selected_dtas($dirname);	# added cmw 10.9.98
    @sel_dtas = &get_next_dtas (lastfile => $FORM{"first_dta"}, num => $num_to_view, inclusive => 1);
}

if ($FORM{"Next"}) {  
  @sel_dtas = &get_next_dtas (lastfile => $FORM{"last_dta"}, num => $num_to_view);
}
if ($FORM{"Prev"}) {  
  @sel_dtas = &get_prev_dtas (firstfile => $FORM{"first_dta"}, num => $num_to_view);
}

$url = "$thumbnails?Dir=$dir";
foreach $dta (@sel_dtas) {
    $url .= "&Dta=$dta";
}

&redirect ($url);
exit;

sub error {
    &MS_pages_header ("Thumbnails", "#00009C");
	print "<hr>\n";

    print ("<h2>Error: @_</h2>");
    exit;
}

sub output_first_form {
    &get_alldirs();

    print <<EOM;
<div>
<FORM ACTION="$ourname" METHOD=POST>

First, pick a directory:
<span class="dropbox"><SELECT NAME="Dir">
EOM

    foreach $dir (@ordered_names) {
	print qq(<OPTION VALUE="$dir">$fancyname{$dir}\n);
    }

    print <<EOM2;
</SELECT></span>

<INPUT TYPE=SUBMIT CLASS=button NAME="First16" VALUE="First 16">
<INPUT TYPE=SUBMIT CLASS=button VALUE="List Directory">
</div>
EOM2
}

sub output_second_form {
    print <<EOM;

Directory: <a href = "$webseqdir/$dirname">$dirname</a>
<p>

<FORM ACTION="$ourname" METHOD=GET>
<INPUT TYPE=HIDDEN NAME="Dir" VALUE="$dirname">

<Table>
<tr VALIGN=TOP>
<td>
Pick DTAs for display:
</td>
<td>
<span class="dropbox"><SELECT NAME="Dta" MULTIPLE SIZE=20>
EOM


    foreach $dta (@alldtas) {
	print qq(<OPTION>$dta\n);
    }

    print <<EOM;
</SELECT></span>
</td>

<td>
<INPUT TYPE=SUBMIT CLASS=button VALUE="Display">
</td>
</tr>
</TABLE>
</FORM>
EOM
}

# this subroutine is called by &get_next_dtas (lastfile => $lastfile, num => $n)
# and then obtains the next $n dtas (alphabetically) after $lastfile.
#
# send "inclusive => 1" if the lastfile is to be included in the list

sub get_next_dtas {
  my (%args) = @_;
  my ($lastfile, $n) = ($args{"lastfile"}, $args{"num"});
  my ($offset) = $args{"inclusive"} ? 0 : 1;

  my (@dtas) = sort { $a cmp $b } @alldtas;
  my (@return);

  my ($i, $l, $num, $count);
  $l = $#dtas + 1;

  $num = 0;
  for ($i = 0; $i < $l; $i++) {
    if ($dtas[$i] eq $lastfile) {
      $num = $i + $offset;
      last;
    }
  }

  ## wrap around to the beginning if all done:
  if ($num >= $l) {
    $num = 0;
  }

  # don't include deleted DTAs:  
  $i = $num;
  while (($i < $l) && (@return < $n)) {
    if (-f $dtas[$i]) {
      push (@return, $dtas[$i]);
    }
    $i++;
  }
  return @return;
}

## this gets the previous few dtas:
## args are $firstfile, the first file displayed previously,
## and $n, the number to find. It will return the $n dtas *before*
## $firstfile.
#
# send "inclusive => 1" if the firstfile is to be included in the list

sub get_prev_dtas {
  my (%args) = @_;
  my ($firstfile, $n) = ($args{"firstfile"}, $args{"num"});
  my ($offset) = $args{"inclusive"} ? 0 : 1;

  my (@dtas) = sort { $a cmp $b } @alldtas;
  my @return;

  my ($i, $l, $num);
  $l = $#dtas + 1;

  ## $num will be the last DTA in the list
  $num = 0;
  for ($i = 0; $i < $l; $i++) {
    if ($dtas[$i] eq $firstfile) {
      $num = $i - $offset;
      last;
    }
  }

  ## wrap around to the end if we are at the beginning:
  if ($num < 0) {
    $num = $l - 1;
  }
  
  # don't include deleted DTAs:
  $i = $num;
  while (($i >= 0) && (@return < $n)) {
    if (-f $dtas[$i]) {
      unshift (@return, $dtas[$i]);
    }
    $i--;
  }
  return @return;
}