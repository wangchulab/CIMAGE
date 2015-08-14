#!/usr/local/bin/perl

#-------------------------------------
#	Sequest Params Text Editor,
#	(C)1997-2000 Harvard University
#	
#	W. S. Lane/M. A. Baker
#
#	v3.1a
#	
#	licensed to Finnigan
#-------------------------------------


# a simple editor for sequest.params files that simply uses a <TEXTAREA> to hold and
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

&MS_pages_header ("Sequest Params Editor", "#9F9F5F");

$dir = $FORM{"directory"};
if (!defined $dir) {
  &output_dropbox;
  exit;
}

if ($dir eq "default") {
	$file = $default_seqparams
}
# Take out makedb.params hack later 7-28-00 P.Djeu
elsif ($dir eq "default_makedb.params") {
	$file = $default_makedbparams;
}
else {
	$file = "$seqdir/$dir/sequest.params";
	$link = "$webseqdir/$dir/sequest.params";
}

$input = $FORM{"input"};

if (!defined $input) {
  &output_form;
  exit;
}

# Otherwise, we are receiving the edited page
# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# make sure input ends with a carriage return
chomp $input;
$input .= "\n";

# backup old sequest.params file with extension .previous
# this is a perl rewrite of what used to be a unix system call (cmwendl, 4/6/98)
copy("$file", "$file.previous");

open (FILE, ">$file") ||
        (print ("<h3>ERROR: Unable to save.</h3>") && exit);

print FILE $input;
close FILE;

print "<P><HR><P><div>\n";
print "<h5>File has been saved.</h5>\n\n";

print ($link ? 
	"You can <a href=\"$link\">check the saved file</a> or <a href=\"$HOMEPAGE\">return home</a>." :
	"Click here to <a href=\"$HOMEPAGE\">return home</a>.");


print <<EOM;

<h5>Output was:</h5>


<pre>
EOM

# clean up for HTML:
$input =~ s/&/&amp;/g;
$input =~ s/>/&gt;/g;
$input =~ s/</&lt;/g;  
$input =~ s/\"/&quot;/g;

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
  $input =~ s!\015\012!\012!g; # NT has different end-of-line markers
  $input =~ s/&/&amp;/g;
  $input =~ s/>/&gt;/g;
  $input =~ s/</&lt;/g;  
  $input =~ s/\"/&quot;/;

  print <<EOF1;
<div>
<FORM ACTION="$ourname" METHOD=POST>
<tt><TEXTAREA ROWS=28 COLS=100 WRAP=VIRTUAL NAME="input">$input</TEXTAREA></tt>

<br>
<b>Filename: 
EOF1

print ($link ? "<a href=\"$link\">$file</a></b>\n" : "$file</b>\n");

  print <<EOF2;

&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">
</FORM>
</div>
EOF2
}

sub output_dropbox {
  # output a dropbox for the user to pick a directory in which to
  # edit sequest.params

  # Added quick hack for Default makedb.params, take out later, 7-28-00 P.Djeu
  print <<EOF;

<P><HR><P>
<b>Pick a directory:</b>

<FORM ACTION="$ourname" METHOD=POST>
<span class=dropbox><SELECT NAME="directory">
<OPTION VALUE = "default">Default sequest.params
<OPTION VALUE = "default_makedb.params">Default makedb.params
EOF
  &get_alldirs; # get directory information

  foreach $dir (@ordered_names) {
    print ("<OPTION VALUE = \"$dir\">$fancyname{$dir}\n");
  }
  print <<EOF;
</SELECT></span>
<INPUT TYPE=SUBMIT CLASS=button VALUE="GO!">

</FORM>
EOF

}
  
