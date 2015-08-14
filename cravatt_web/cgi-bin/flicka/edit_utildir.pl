#!/usr/local/bin/perl

#-------------------------------------
#	Utility Directory Text Editor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# a simple editor for utility_dir.txt that simply uses a <TEXTAREA> to hold and
# edit the file

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

$file = "utility_dir.txt";
$link = "/utility_dir.txt";

$input = $FORM{"input"};

if (!defined $input) {
  &MS_pages_header ("Utility Directory Editor", "#802040");
  &output_form;
  exit;
}

# Otherwise, we are receiving the edited page
# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# make sure input ends with a carriage return
chomp $input;
$input .= "\n";

# let's use Perl code instead:
copy("$htdocs/$file", "$htdocs/$file.previous");

&MS_pages_header ("Utility Directory Editor", "#802040");
print "<P><HR><P>\n";


if (!open (FILE, ">$htdocs/$file")) {
	print ("<h3>ERROR: Unable to save.</h3>");
	exit;
}

print FILE $input;
close FILE;


print <<EOM;

<div>

<h5>File has been saved.</h5>

You can <a href="$link">check the saved file</a> or
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
  open (FILE, "$htdocs/$file");
  @input = <FILE>;
  close FILE;

  $input = join ("", @input);

  # clean up for HTML:
  $input =~ s/&/&amp;/g;
  $input =~ s/>/&gt;/g;
  $input =~ s/</&lt;/g;  
  $input =~ s/\"/&quot;/;

  print <<EOF;
<div>
<FORM NAME="form" ACTION="$ourname" METHOD=POST>
<tt><TEXTAREA ROWS=28 COLS=100 WRAP=OFF NAME="input" onKeyDown="if (event.keyCode==9) { alert('<Tab> key does not work (yet).\\n\\nTip of the Day:\\nFor now, copy a tab character to the clipboard and paste it wherever you need it.'); return false; }">$input</TEXTAREA></tt>

<br>
<b>Filename: <a href="$link">$htdocs/$file</a></b>

&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">
</FORM>
<script>
document.form.input.tabIndex = -1;
</script>
</div>
EOF
}
