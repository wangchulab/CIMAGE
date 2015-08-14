#!/usr/local/bin/perl

#-------------------------------------
#	Edit Scratchpad,
#	(C)1997-2000, 1998 Harvard University
#	
#	W. S. Lane/M. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------



# a simple editor for known_ions.txt that simply uses a <TEXTAREA> to hold and
# edit the file

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

$file = "$incdir/scratchpad.txt";
$link = "$webincdir/scratchpad.txt";

$input = $FORM{"input"};

if (!defined $input) {
  &MS_pages_header ("Scratch Pad", "#9F9F5F");
  &output_form();
  exit;
}

# Otherwise, we are receiving the edited page


# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# make sure input ends with a carriage return
chomp $input;
$input .= "\n";

#$command = "cat $file > $file" . ".previous";
#qx{ $command };
# let's use Perl code instead:
copy("$file","$file.previous");

&MS_pages_header ("Scratch Pad", "#9F9F5F");
print "<P><HR><P>\n";

open (KNOWN_IONS, ">$file") ||
        (print ("<h3>ERROR: Unable to save.</h3>") && exit);

print KNOWN_IONS $input;
close KNOWN_IONS;

print <<EOM;
<div>
<h5>File has been saved.</h5>

You can <a href="$link">check the saved file</a> or
<a href="$HOMEPAGE">return home</a>.

<h5>Output was:</h5>
</div>
<pre>
EOM

# clean up for HTML:
$input =~ s/&/&amp;/g;
$input =~ s/>/&gt;/g;
$input =~ s/</&lt;/g;  
$input =~ s/\"/&quot;/;

print $input;
print ("</pre>\n");

exit;

# this is the first page.
# we receive from FuzzyIons the info of the DTA used,
# the "pretty sequence" and the sequence in fuzzy form 

sub output_form {
  my @input, $input;
  open (FILE, "$file") || print ("unable to open $file.\n");;
  @input = <FILE>;
  close FILE;

  my $dta = $FORM{"Dta"} || $FORM{"dtafile"};
  my $prettyseq = $FORM{"PrettySeq"};
  my $pep = $FORM{"Pep"} || $FORM{"pep"};

  # separate by either backslash or forward slash
  my @temp = split (m![/\\]!, $dta);
  $dta = pop @temp;
  my $dir = pop @temp;

  my $fancyname;
  $fancyname = &get_fancyname ($dir);
  
  my $date = &get_regular_date(); 

  $input = join ("", @input);

  # clean up for HTML:
  $input =~ s/&/&amp;/g;
  $input =~ s/>/&gt;/g;
  $input =~ s/</&lt;/g;  
  $input =~ s/\"/&quot;/;

  print <<EOF;
<div>
<FORM ACTION="$ourname" METHOD=POST>
<tt><TEXTAREA ROWS=28 COLS=100 WRAP=VIRTUAL NAME="input">$input</TEXTAREA></tt>
EOF
if ($dir ne "") {
print <<EOF;
<br>
<tt><span style="color:red">$fancyname<br>
 &nbsp;$dta $pep ($date xxx )</span></tt><br>
EOF
}
print <<EOF;

<br>
<b>File:</b> <a href="$link">$file</a>

&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">
</FORM>
</div>
EOF
}
