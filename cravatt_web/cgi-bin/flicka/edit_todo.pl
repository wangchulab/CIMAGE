#!/usr/local/bin/perl

#-------------------------------------
#	To Do List Text Editor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# a simple editor for todolist.txt that simply uses a <TEXTAREA> to hold and
# edit the file

################################################
# find and read in standard include file
{
	$0 =~ m!(.*)[\\\/]([^\\\/]*)$!;
	do ("$1/development.pl");
	my $path = $0;
	$path =~ s!\\!/!g;
	$path =~ s!^(.*)/[^/]+/.*$!$1/etc!;
	unshift (@INC, "$path");
	require "microchem_include.pl";
}
################################################
 
&cgi_receive;

$file = "$incdir/todolist.txt";
$link = "$webincdir/todolist.txt";

$input = $FORM{"input"};


&MS_pages_header ("Todo List Editor", "#9F9F5F");


&output_form if (!defined $input);

# Otherwise, we are receiving the edited page
# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# make sure input ends with a carriage return
chomp $input;
$input .= "\n";

#$command = "cat $file > $file" . ".previous";
#qx{ $command };
# let's use Perl code instead:
copy("$file", "$file.previous");

print "<HR><BR>\n";

open (FILE, ">$file") ||
        (print ("<h3>ERROR: Unable to save.</h3>") && exit);

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
  open (FILE, "$file");
  @input = <FILE>;
  close FILE;

  $input = join ("", @input);

  # clean up for HTML:
  $input =~ s/&/&amp;/g;
  $input =~ s/>/&gt;/g;
  $input =~ s/</&lt;/g;  
  $input =~ s/\"/&quot;/;

  print <<EOF;
<BR>
<div>
EOF
print <<EOF;
<FORM ACTION="$ourname" METHOD=POST>
<tt><TEXTAREA ROWS=28 COLS=100 WRAP=VIRTUAL NAME="input">$input</TEXTAREA></tt>

<br>
<b>Filename: <a href="$link">$file</a></b>

&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">
</FORM>
</div>
EOF

exit;
}
