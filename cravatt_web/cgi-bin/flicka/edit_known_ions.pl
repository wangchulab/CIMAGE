#!/usr/local/bin/perl

#-------------------------------------
#	Known Ions Text Editor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
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

$input = $FORM{"input"};

if (!defined $input) {
  &MS_pages_header ("Known Ions Editor", "#9F9F5F");
  &output_form;
  exit;
}

# Otherwise, we are receiving the edited page


# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# make sure input ends with a carriage return
chomp $input;
$input .= "\n";

#$command = "cat $exclude_file > $exclude_file" . ".previous";
#qx{ $command };
# let's use Perl commands instead to backup the old file
copy("$exclude_file","$exclude_file.previous");

&MS_pages_header ("Known Ions Editor", "#9F9F5F");
print "<P><HR><P>\n";

open (KNOWN_IONS, ">$exclude_file") ||
        (print ("<h3>ERROR: Unable to save.</h3>") && exit);

print KNOWN_IONS $input;
close KNOWN_IONS;

print <<EOM;

<div>

<h5>File has been saved.</h5>

You can <a href="$exclude_link">check the saved file</a> or
<a href="$HOMEPAGE">return home</a>.

<h5>Output was:</h5>
<pre>
EOM

# clean up for HTML:
$input =~ s/&/&amp;/g;
$input =~ s/>/&gt;/g;
$input =~ s/</&lt;/g;  
$input =~ s/\"/&quot;/;

print $input;
print ("</pre>\n");

print "</div></body></html>\n";

exit;

sub output_form {
  my @input, $input;
  open (KNOWN_IONS, "$exclude_file");
  @input = <KNOWN_IONS>;
  close KNOWN_IONS;

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

<br>
<b>Filename: <a href="$exclude_link">$exclude_file</a></b>
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">
</FORM>
</div>
EOF
}
