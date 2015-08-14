#!/usr/local/bin/perl

#-------------------------------------
#	Simple Fasta Database Editor,
#	(C)1999 Harvard University
#	
#	W. S. Lane/L. Sullivan 10/99
#
#	
#	10/29/01 A. Chang - Added a WhatDoYou Menu on final page, new output format
#	
#-------------------------------------


# This database editor was adapted from the sequest.params editor.  
# It drops a list of database files and then prints out 
# the text of the file in an box where it can be edited.
# It is limited to MAX_FILE_SIZE Kb below


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
# Additional includes here
require "fasta_include.pl";  #needed for new menu options - AARON


&cgi_receive;


$dir = $FORM{"directory"};
$MAX_FILE_SIZE = $DEFS_DATABASE_EDITOR{'MAX FILE SIZE'};
$Netscape_MAX_FILE_SIZE = $DEFS_DATABASE_EDITOR{'Netscape MAX FILE SIZE'};
#Set the maximum file size.  
#Otherwise Netscape will not be able to support the text window

&MS_pages_header ("Database Editor", "#9F9F5F");

if (!defined $dir) {
  &output_dropbox;
  exit;
}


$file = "$dbdir/$dir";
$link = "$webdbdir/$dir";
$size = ((-s $file)/1000);

$input = $FORM{"input"};
if (!defined $input) {
  &output_form;
  exit;
}

# Otherwise, we are receiving the edited page
# convert the ^M^J line separators to Unix style ^J
$input =~ s!\015\012!\012!g;

# remove the spaces, tabs, and new lines in the sequences.
my @fragments = split('>', $input);

foreach $fragment (@fragments) {
	my ($header, $sequence)= split /\n/, $fragment, 2;
    $sequence =~ s/\s//g;
	$sequence =~ s/(\w{80})/$1\n/g;
	$header = join //, ">", $header;
	$fragment = join ("\n", $header, $sequence);
}

shift @fragments;
$input = join("\n\n", @fragments);

# make sure input ends with a carriage return
chomp $input;
$input .= "\n\n";

# backup old database.fasta file with extension .previous
# this is a perl rewrite of what used to be a unix system call (cmwendl, 4/6/98)
copy("$file", "$file.previous");

open (FILE, ">$file") ||
	(print ("<h3>ERROR: Unable to save.</h3>") && exit);

print FILE $input;
close FILE;


# call new output format - AARON

&rename_success;


print <<EOM;

<h5>Content is:</h5>


<pre>
EOM

# clean up for HTML:
$input =~ s/&/&amp;/g;
$input =~ s/>/&gt;/g;
$input =~ s/</&lt;/g;  
$input =~ s/\"/&quot;/g;

print $input;
print ("</pre>\n");

print ("</div></body></html>\n");

exit;


# Recycled and modified function from renameadir.pl for new output format - AARON

sub rename_success {
  @msgs = @_;

  print <<EOM;
<p>
<div class="normaltext">

<image src="/images/circle_1.gif">&nbsp;File has been saved.<br><BR>
</div>
EOM

#<table width="60%" cellspacing=0 cellpadding=4>
#<tr bgcolor="#e2e2e2">
#<td valign=top><image src="/images/circle_2.gif"></td>
#<td valign=top class="smalltext">
#If you also need to rename the DTA files
#in your directory to match a different .RAW filename, go to <a href="$webcgi/searchreplace.pl?directory=$newdir">Search and Replace</a> (and see
#<a href="$webhelpdir/help_searchreplace.pl.html" target=_blank>Help</a> if you need more explanation).
#</td>
#</tr>
#</table>


# Modified WhatDoYouWant Pull Down Menu - AARON

@text = ("Copy This Database with Fasta CopyCat", "Delete This Database with FastaRemova", "Run Sequest", "Index This Database with FastaIdx", "Open Saved Database File");
@links = ("copycat.pl?db=$dir", "copycat.pl?remova=1&db=$dir", "sequest_launcher.pl?Database=$dir", "$fastaidx_web?selected=$dir", $link);
&WhatDoYouWantToDoNow(\@text, \@links);
}




sub output_form {
	# Check to see if size of file to be edited is less than
	# the cutoff file size, if so start the editing page
	if($size < $MAX_FILE_SIZE){
		
		
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
#for files of size > 1KB, round up to the nearest integer 
#and display that integer as the file size in KB.
if($size > 1){
	$adjusted_size = int($size);
# For files of size < 1KB, display that number to the  
# tenths place as the file size
}else{
	$adjusted_size = ($size * 10);
	$adjusted_size = int($adjusted_size);
	$adjusted_size = ($adjusted_size / 10);
}



print ("<b>($adjusted_size KB)</b>");
print <<EOF2;

&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=RESET CLASS=button VALUE="Revert">
&nbsp;&nbsp;&nbsp;&nbsp;

<INPUT TYPE=SUBMIT CLASS=button VALUE="Save">	
<INPUT TYPE=HIDDEN NAME="directory" VALUE="$dir">
</FORM>
</div>
EOF2
	}else{
		# size of file is greater than MAX_FILE_SIZE cutoff.
		# print out the error message.
		&error_form;
	}
}



sub error_form{
	# Error message printed if the file selected from dropbox is 
	# greater than MAX_FILE_SIZE cutoff
	print <<EOF1;
<div>
<FORM ACTION="$ourname" METHOD=POST>
<br>
<br>
<b>Error: This file is greater than $MAX_FILE_SIZE KB.</b>  
</FORM>
</div>
EOF1
}

sub output_dropbox {
  # output a dropbox for the user to pick a directory in which to
  # edit databases
  print <<EOF;
<HR><P>
<b>Pick a database:</b>
<br>
<br>
<FORM ACTION="$ourname" METHOD=POST>
<span class=dropbox><SELECT NAME="directory">
<OPTION VALUE = "">

EOF
  # get each database file using the microchem_include 
  # function: get_dbases
  # and print them in the dropbox	
  @dbases = get_dbases(@dbases);
  foreach $dir (@dbases) {
		print qq(<OPTION VALUE ="$dir");
		print "SELECTED" if ($dir eq $default_item);
		print (">$dir\n");
  }
  
  print <<EOF;
  </SELECT></span>
<INPUT TYPE=SUBMIT CLASS=button VALUE="GO!">

<br>
<br>
<b><div style = "color:#FF0000"> 
Maximum editable filesize is $MAX_FILE_SIZE KB in Internet Explorer; Netscape is limited to $Netscape_MAX_FILE_SIZE KB.
</div></b>
</FORM>
EOF
 
}

